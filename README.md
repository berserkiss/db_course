# Airline booking database

An Oracle database for an airline booking system: flights, airplanes,
airports, tickets, passengers and airport staff. A course project.

The point of it is not the tables. It is that nobody reaches them directly.
All access goes through stored procedures, the roles are granted `EXECUTE`
on those procedures and nothing else, and personal data is encrypted in the
columns rather than left in the clear.

## How access is arranged

Three roles, none of which holds a single privilege on a table:

| Role | Can | Granted to |
| --- | --- | --- |
| `admin_role` | everything, plus `DBMS_CRYPTO` and `DBMS_REDACT` | `admin`, `PAS` |
| `employee_role` | flights, tickets, airport staff, analytics | `employee_user` |
| `user_role` | register, sign in, search flights, book and cancel a ticket | `app_user` |

Procedures are declared `AUTHID DEFINER`, which is what makes the
arrangement work: the caller runs the procedure with the owner's rights and
still cannot touch the table underneath it.

Password, passport number, first and last name, city and street are
encrypted with AES-256-CBC through `pkg_crypto_utils`, a package wrapping
`DBMS_CRYPTO`. `Users_View` masks email and phone for anyone reading the
view instead of the table.

## Layout

```
db_course/
├── schema/      roles, users, tables, seed rows
├── procedures/  the stored procedures, by audience
├── data/        JSON exports of every table, plus a 100k-row load
├── scenarios/   scripts that call the procedures as each role would
└── docs/        ER diagram and use case diagram (drawio)
```

| File | Contains |
| --- | --- |
| `schema/roles_users_tables.sql` | 3 roles, 4 users, 8 tables, the `GRANT EXECUTE` list, seed rows |
| `procedures/admin.sql` | `pkg_crypto_utils`, two triggers generating flight and ticket numbers, the masking views, 7 admin procedures |
| `procedures/general.sql` | 9 procedures every role uses: register, sign in, search, book, cancel |
| `procedures/employee.sql` | 12 procedures for airport staff: flights, tickets, analytics |
| `procedures/json.sql` | 16 export/import procedures, reading and writing the files in `data/` through `UTL_FILE` |
| `data/insert_100k.sql` | bulk load and two indexes, for testing on a realistic volume |
| `scenarios/*.sql` | example calls, one file per role |

## Running it

Oracle XE. Everything except the scenarios is run as the `admin` user, since
the objects live in that schema.

```
1. schema/roles_users_tables.sql   -- roles, users, tables
2. procedures/admin.sql            -- pkg_crypto_utils first: the rest compile against it
3. procedures/general.sql
4. procedures/employee.sql
5. procedures/json.sql
6. re-run the GRANT EXECUTE block at the top of schema/roles_users_tables.sql
7. data/insert_100k.sql            -- optional, for volume testing
```

Then `scenarios/user.sql` as `app_user`, `scenarios/employee.sql` as
`employee_user`, `scenarios/admin.sql` as `admin`.

`procedures/json.sql` creates a directory object pointing at
`/opt/oracle/oradata/XE/TablesJson`. The files in `data/` have to be in that
directory on the database host for the import procedures to find them.

## Known issues

Written down rather than left to be discovered.

- **`procedures/admin.sql` drops the package it has just created.** There is
  a `DROP PACKAGE pkg_crypto_utils;` at line 90, left over from
  experimenting. Run the file as it stands and every procedure that
  encrypts anything fails to compile. Comment that line out before running.
- **Step 6 exists because of an ordering problem.** The `GRANT EXECUTE`
  statements sit at the top of `schema/roles_users_tables.sql`, and they
  name procedures that do not exist until steps 2 to 5 have run. On the
  first pass they all error. Splitting that file into schema and grants
  would remove the step.
- **The encryption key is in the source.** `pkg_crypto_utils` carries its
  AES key as a literal, so the ciphertext and the key that opens it live in
  the same repository. Acceptable for a course project with invented data;
  not a pattern to reuse.
- **The database users are created with the password `password`.** Change
  them before this touches anything real.
- **`data/airplane_types.json` is 17 MB**, which is almost the whole
  repository. It is a legitimate export, but it makes the clone heavy.
