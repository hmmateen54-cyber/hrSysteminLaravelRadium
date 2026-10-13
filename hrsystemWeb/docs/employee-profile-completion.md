# Employee profile activation

Self-registered employee accounts are created with `account_status = pending` and receive a generated employee ID. HR activates the account after saving a complete employee profile.

The activation rule requires all of these persisted fields:

- Employee ID
- Phone
- Department
- Designation
- Joining date

Salary is optional and does not block activation. Employee ID alone does not count as a complete profile. Incomplete HR edits leave a pending account pending; already-active employee accounts remain active when edited.

The `account_status` column defaults to `active` so accounts that existed before the additive migration retain access. The migration also adds a unique index on `employees.user_id` to enforce the existing one-to-one User/Employee relationship.
