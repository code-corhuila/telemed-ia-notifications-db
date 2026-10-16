# telemed-ia-notifications-db

> Notifications bounded context: database (schema, migrations, grants).

Part of **TeleMed IA** — Sistemas Distribuidos 2026-B, Grupo 2.
Governance and documentation live in `code-corhuila/telemed-ia-docs`.

## What this repository owns

- The `notifications` schema in the single PostgreSQL instance
  (`telemed-ia-infra-postgres`, Anexo J).
- Liquibase changesets, each with its rollback.
- Grants for the `notifications_reader` and `notifications_writer` roles.

It does **not** define a PostgreSQL container, a volume or database users: the instance and the
`notifications_app`, `notifications_reader` and `notifications_writer` roles are created by
`telemed-ia-infra-postgres` (`postgres/init/01-instance.sh`). `telemed-ia-notifications-api` never
runs migrations.

## Layout

```text
changelog/changelog-master.yaml   entry point (includes every folder below, in order)
changelog/expected-count.txt      number of declared changesets (checked by CI)
01_ddl/                           extensions, schemas, types, tables, alter, views, functions, triggers, indexes
02_dml/                           inserts, updates, deletes, upserts, patches
03_dcl/                           roles, grants, policies
04_tcl/                           transaction blocks, manual recoveries, release tags
05_rollbacks/                     one rollback script per changeset, mirroring the folders above
deploy/compose.yml                migration executor (profile tooling, network platform)
tests/run-db-tests.sh             reconstruction and schema tests in disposable containers
tests/sql/                        SQL tests run as notifications_app
```

Liquibase control tables: `databasechangelog_notifications` and `databasechangeloglock_notifications`.

## Running the migrations

From `telemed-ia-infra-postgres`, which `include:`s `deploy/compose.yml`:

```bash
docker compose --env-file env/dev.env --profile tooling run --rm notifications-db-migrate
```

Required variables are documented in `.env.example`; real values live only in the infra env files.

## Testing

Requires Docker and Bash (Git Bash works on Windows):

```bash
bash tests/run-db-tests.sh
```

The script starts a disposable PostgreSQL 16, bootstraps the roles as the infra does, applies every
changeset, re-applies (expects zero), rolls everything back, rebuilds and runs `tests/sql/*.sql`.
It removes every container and network it creates. CI (`.github/workflows/db-ci.yml`) runs the same
script.

## Branching

Three permanent branches. **None of them accepts a direct commit** — you enter through a child
branch and leave through a Pull Request.

```text
develop  <--PR--  feat/... fix/... chore/...
qa       <--PR--  qa/...
main     <--PR--  release/...  hotfix/...
```

Promotion happens **by re-application** (`git cherry-pick -x`), never by merging one permanent
branch into another. `main` requires the approval of `ariel5253`.
