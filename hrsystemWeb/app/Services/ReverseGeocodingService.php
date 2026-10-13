<?php

namespace App\Services;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Throwable;

class ReverseGeocodingService
{
    private const CACHE_DAYS = 30;

    private const NEGATIVE_CACHE_HOURS = 6;

    /**
     * @return array{status: 'resolved'|'unavailable'|'pending', address: ?string}
     */
    public function reverse(float $latitude, float $longitude): array
    {
        $cacheKey = $this->cacheKey($latitude, $longitude);

        try {
            $cached = Cache::get($cacheKey);
            if (is_array($cached) && isset($cached['status'])) {
                return $cached;
            }
        } catch (Throwable) {
            // A cache outage must not prevent an attendance event from saving.
        }

        try {
            $result = Cache::lock('nominatim:reverse:request-lock', 10)->block(5, function () use ($latitude, $longitude) {
                // Check again after acquiring the lock; another request may have
                // populated the rounded-coordinate cache while this one waited.
                $cacheKey = $this->cacheKey($latitude, $longitude);
                $cached = Cache::get($cacheKey);
                if (is_array($cached) && isset($cached['status'])) {
                    return $cached;
                }

                $lastRequestAt = (float) Cache::get('nominatim:reverse:last-request-at', 0);
                $waitMicros = (int) ceil(max(0, 1 - (microtime(true) - $lastRequestAt)) * 1_000_000);
                if ($waitMicros > 0) {
                    usleep($waitMicros);
                }
                Cache::put('nominatim:reverse:last-request-at', microtime(true), now()->addSeconds(10));

                $baseUrl = rtrim((string) config('services.nominatim.base_url'), '/');
                $response = Http::withHeaders([
                    'User-Agent' => $this->userAgent(),
                    'Accept-Language' => (string) config('app.locale', 'en'),
                ])->timeout(4)->get($baseUrl.'/reverse', [
                    'format' => 'jsonv2',
                    'lat' => $latitude,
                    'lon' => $longitude,
                    'addressdetails' => 1,
                    'zoom' => 18,
                    'layer' => 'address',
                ]);

                if (in_array($response->status(), [400, 404], true)) {
                    $unavailable = ['status' => 'unavailable', 'address' => null];
                    Cache::put($cacheKey, $unavailable, now()->addHours(self::NEGATIVE_CACHE_HOURS));

                    return $unavailable;
                }

                if (! $response->successful()) {
                    return $this->pending();
                }

                $payload = $response->json();
                if (! is_array($payload)) {
                    return $this->pending();
                }

                $address = $this->formatAddress($payload);
                $result = $address === null
                    ? ['status' => 'unavailable', 'address' => null]
                    : ['status' => 'resolved', 'address' => $address];

                Cache::put(
                    $cacheKey,
                    $result,
                    $result['status'] === 'resolved'
                        ? now()->addDays(self::CACHE_DAYS)
                        : now()->addHours(self::NEGATIVE_CACHE_HOURS),
                );

                return $result;
            });

            return is_array($result) ? $result : $this->pending();
        } catch (Throwable) {
            // Network, throttling, lock, provider, or cache failures all leave
            // the stored GPS event intact and eligible for a later retry.
            return $this->pending();
        }
    }

    private function formatAddress(array $payload): ?string
    {
        $address = is_array($payload['address'] ?? null) ? $payload['address'] : [];
        $road = $this->first($address, ['road', 'pedestrian', 'footway', 'path', 'residential']);
        $locality = $this->first($address, ['city', 'town', 'village', 'municipality', 'hamlet', 'locality']);

        $parts = [
            $address['house_number'] ?? null,
            $address['building'] ?? null,
            $road,
            $this->first($address, ['neighbourhood', 'quarter']),
            $this->first($address, ['suburb', 'city_district', 'borough']),
            $locality,
            $this->first($address, ['county', 'state_district']),
            $this->first($address, ['state', 'province', 'region']),
            $address['country'] ?? null,
        ];

        $formatted = $this->uniqueParts($parts);
        if ($formatted !== []) {
            return implode(', ', $formatted);
        }

        // Some valid reverse results provide only display_name. Keep its real
        // returned components and remove repeated/empty parts without guessing.
        $displayName = $payload['display_name'] ?? null;
        if (! is_string($displayName) || trim($displayName) === '') {
            return null;
        }

        return implode(', ', $this->uniqueParts(explode(',', $displayName))) ?: null;
    }

    private function first(array $address, array $keys): ?string
    {
        foreach ($keys as $key) {
            $value = $address[$key] ?? null;
            if (is_string($value) && trim($value) !== '') {
                return trim($value);
            }
        }

        return null;
    }

    private function uniqueParts(array $parts): array
    {
        $formatted = [];
        $seen = [];
        foreach ($parts as $part) {
            if (! is_string($part) || trim($part) === '') {
                continue;
            }
            $value = preg_replace('/\s+/u', ' ', trim($part));
            $key = mb_strtolower($value);
            if ($value === '' || isset($seen[$key])) {
                continue;
            }
            $seen[$key] = true;
            $formatted[] = $value;
        }

        return $formatted;
    }

    private function userAgent(): string
    {
        $configured = trim((string) config('services.nominatim.user_agent', ''));
        if ($configured !== '') {
            return $configured;
        }

        $name = preg_replace('/[^A-Za-z0-9._-]+/', '', (string) config('app.name', 'HRSystem')) ?: 'HRSystem';
        $url = trim((string) config('app.url', ''));
        $contact = trim((string) config('services.nominatim.contact_email', ''));
        $identity = $url !== '' ? '+'.$url : 'attendance location lookup';
        if ($contact !== '') {
            $identity .= '; contact: '.$contact;
        }

        return $name.'/1.0 ('.$identity.')';
    }

    private function cacheKey(float $latitude, float $longitude): string
    {
        $rounded = number_format(round($latitude, 5), 5, '.', '').','.number_format(round($longitude, 5), 5, '.', '');

        return 'nominatim:reverse:'.hash('sha256', $rounded);
    }

    private function pending(): array
    {
        return ['status' => 'pending', 'address' => null];
    }
}
