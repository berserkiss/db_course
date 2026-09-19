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
├── schema/      roles, users, tables, indexes, seed rows, the key loader
├── procedures/  the stored procedures, by audience
├── data/        JSON exports of every table, plus a 100k-row load
├── scenarios/   scripts that call the procedures as each role would
└── docs/        ER diagram and use case diagram (drawio)
```

| File | Contains |
| --- | --- |
| `schema/roles_users_tables.sql` | 3 roles, 4 users, 9 tables, the `GRANT EXECUTE` list, seed rows |
| `procedures/admin.sql` | `pkg_crypto_utils`, two triggers generating flight and ticket numbers, the masking views, 7 admin procedures |
| `procedures/general.sql` | 9 procedures every role uses: register, sign in, search, book, cancel |
| `procedures/employee.sql` | 12 procedures for airport staff: flights, tickets, analytics |
| `procedures/json.sql` | 16 export/import procedures, reading and writing the files in `data/` through `UTL_FILE` |
| `data/insert_100k.sql` | bulk load and two indexes, for testing on a realistic volume |
| `scenarios/*.sql` | example calls, one file per role |
| `schema/crypto_key.example.sql` | template for the gitignored file holding the encryption key |
| `schema/indexes.sql` | an index per foreign key, plus one on `Flights.departure_time` |

## Running it

Oracle XE. Everything except the scenarios is run as the `admin` user, since
the objects live in that schema.

```
1. schema/roles_users_tables.sql   -- roles, users, tables
2. schema/crypto_key.sql           -- the encryption key, see below
3. schema/indexes.sql              -- foreign key indexes, see below
4. procedures/admin.sql            -- pkg_crypto_utils first: the rest compile against it
5. procedures/general.sql
6. procedures/employee.sql
7. procedures/json.sql
8. re-run the GRANT EXECUTE block at the top of schema/roles_users_tables.sql
9. data/insert_100k.sql            -- optional, for volume testing
```

Step 2 needs a file that is not in the repository. Copy
`schema/crypto_key.example.sql` to `schema/crypto_key.sql` and put a key in
it (`openssl rand -base64 32`). Without it the package raises ORA-20100 the
first time anything is encrypted, rather than failing somewhere confusing.

Then `scenarios/user.sql` as `app_user`, `scenarios/employee.sql` as
`employee_user`, `scenarios/admin.sql` as `admin`.

`procedures/json.sql` creates a directory object pointing at
`/opt/oracle/oradata/XE/TablesJson`. The files in `data/` have to be in that
directory on the database host for the import procedures to find them.

## Indexes

Oracle indexes a primary key and a unique constraint by itself. It does not
index a foreign key, and in this schema there are eleven of them.

That omission is not only about join speed. Deleting or updating a parent
key takes a share lock on the entire child table while Oracle looks for
orphaned rows, and holds it for the length of the statement. Remove one
airport with no index on `Flights.departure_airport_id` and every flight row
is locked for the duration.

`schema/indexes.sql` adds one index per foreign key, and one on
`Flights.departure_time`, which appears in the predicate of every flight
search.

## Known issues

Written down rather than left to be discovered.

- **Step 7 exists because of an ordering problem.** The `GRANT EXECUTE`
  statements sit at the top of `schema/roles_users_tables.sql`, and they
  name procedures that do not exist until steps 4 to 7 have run. On the
  first pass they all error. Splitting that file into schema and grants
  would remove the step.
- **The encryption key was in the source, and is still in the history.**
  `pkg_crypto_utils` used to carry its AES key as a literal; it reads it
  from `crypto_config` now, and the file holding the value is gitignored.
  That does not undo anything: the old commits still contain the key, and
  `data/users.json` holds ciphertext made with it, so both are public
  together. The real remedy is to generate a new key and re-export, which
  needs a database to run against. The data is invented, so this is noted
  rather than urgent.
- **The database users are created with the password `password`.** Change
  them before this touches anything real.
- **Keeping the key in a table is hygiene, not security.** It stops the key
  travelling in version control, but it now sits in the database it
  protects, readable by anyone who can read that table. A wallet or an
  external key store is what this would need to be more than tidy.
- **`data/airplane_types.json` is 17 MB**, which is almost the whole
  repository. It is a legitimate export, but it makes the clone heavy.
