<h2>Eloquent</h2>

<table class="border="1" cellpadding="10"">
    <thead>
        <tr>
            <th>Department</th>
            <th>Phone</th>
            <th>Designation</th>
            <th>Joining Date</th>
            <th>Salary</th>
        </tr>
    </thead>
    <tbody>
        @foreach ($employees as $e)
            <tr>
                <td>{{ $e->department }}</td>
                <td>{{ $e->phone }}</td>
                <td>{{ $e->designation }}</td>
                <td>{{ $e->joining_date }}</td>
                <td>{{ $e->salary }}</td>
            </tr>
        @endforeach
    </tbody>
</table>