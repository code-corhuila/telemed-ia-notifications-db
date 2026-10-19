#!/usr/bin/env bash
# =========================================================================
# Reconstruction and schema tests for telemed-ia-notifications-db.
#
# Runs against a disposable PostgreSQL container on a disposable network.
# Nothing persists: no volume is created and every resource is removed on
# exit. Used both locally and by .github/workflows/db-ci.yml.
#
# Steps:
#   1. Declared changesets match changelog/expected-count.txt.
#   2. Bootstrap roles (mimics telemed-ia-infra-postgres 01-instance.sh).
#   3. liquibase update on an empty database.
#   4. Second update applies zero changesets.
#   5. Rollback of every changeset leaves no domain objects (the schema
#      itself belongs to the infrastructure and is kept).
#   6. Rebuild from scratch.
#   7. SQL tests in tests/sql/*.sql, run as notifications_app.
# =========================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_ID="$(date +%s)-$$"
NETWORK="notifications-db-test-net-${RUN_ID}"
DB_CONTAINER="notifications-db-test-${RUN_ID}"
POSTGRES_IMAGE="postgres:16-alpine"
LIQUIBASE_IMAGE="liquibase/liquibase:4.31"
DB_NAME="telemed_ia"
APP_USER="notifications_app"
SCHEMA="notifications"
CHANGELOG_TABLE="databasechangelog_${SCHEMA}"

random_secret() {
  head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n'
}

ADMIN_PASSWORD="$(random_secret)"
APP_PASSWORD="$(random_secret)"

# Git Bash on Windows rewrites POSIX paths; docker needs them untouched.
export MSYS_NO_PATHCONV=1
MOUNT_SOURCE="$REPO_ROOT"
if command -v cygpath >/dev/null 2>&1; then
  MOUNT_SOURCE="$(cygpath -w "$REPO_ROOT")"
fi

cleanup() {
  docker rm -f "$DB_CONTAINER" >/dev/null 2>&1 || true
  docker network rm "$NETWORK" >/dev/null 2>&1 || true
}
trap cleanup EXIT

step() {
  printf '\n==> %s\n' "$1"
}

fail() {
  printf 'FAILED: %s\n' "$1" >&2
  exit 1
}

admin_psql() {
  docker exec -i -e PGPASSWORD="$ADMIN_PASSWORD" "$DB_CONTAINER" \
    psql -X -q -v ON_ERROR_STOP=1 -h 127.0.0.1 -U postgres -d "$DB_NAME" "$@"
}

app_psql() {
  docker exec -i -e PGPASSWORD="$APP_PASSWORD" "$DB_CONTAINER" \
    psql -X -q -v ON_ERROR_STOP=1 -h 127.0.0.1 -U "$APP_USER" -d "$DB_NAME" "$@"
}

liquibase() {
  docker run --rm \
    --network "$NETWORK" \
    --mount "type=bind,source=${MOUNT_SOURCE},target=/workspace,readonly" \
    -e LIQUIBASE_COMMAND_URL="jdbc:postgresql://${DB_CONTAINER}:5432/${DB_NAME}" \
    -e LIQUIBASE_COMMAND_USERNAME="$APP_USER" \
    -e LIQUIBASE_COMMAND_PASSWORD="$APP_PASSWORD" \
    -e LIQUIBASE_COMMAND_CHANGELOG_FILE="changelog/changelog-master.yaml" \
    -e LIQUIBASE_DATABASE_CHANGELOG_TABLE_NAME="$CHANGELOG_TABLE" \
    -e LIQUIBASE_DATABASE_CHANGELOG_LOCK_TABLE_NAME="databasechangeloglock_${SCHEMA}" \
    -e LIQUIBASE_SEARCH_PATH="/workspace" \
    -e LIQUIBASE_SHOW_BANNER=false \
    "$LIQUIBASE_IMAGE" --log-level=WARNING "$@"
}

applied_count() {
  app_psql -tA -c "SELECT COUNT(*) FROM ${SCHEMA}.${CHANGELOG_TABLE};"
}

step "1. Declared changesets match changelog/expected-count.txt"
declared="$({ grep -Rh --include=changelog.yaml -E '^\s*-\s*changeSet:' "$REPO_ROOT" || true; } | wc -l | tr -d ' ')"
expected="$(tr -d '[:space:]' < "$REPO_ROOT/changelog/expected-count.txt")"
echo "declared=${declared} expected=${expected}"
[ "$declared" = "$expected" ] || fail "changelog count mismatch"

step "Start disposable PostgreSQL"
docker network create "$NETWORK" >/dev/null
docker run -d --name "$DB_CONTAINER" --network "$NETWORK" \
  -e POSTGRES_PASSWORD="$ADMIN_PASSWORD" \
  -e POSTGRES_DB="$DB_NAME" \
  "$POSTGRES_IMAGE" >/dev/null
for _ in $(seq 1 60); do
  if docker exec "$DB_CONTAINER" pg_isready -h 127.0.0.1 -U postgres -d "$DB_NAME" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
docker exec "$DB_CONTAINER" pg_isready -h 127.0.0.1 -U postgres -d "$DB_NAME" >/dev/null \
  || fail "PostgreSQL did not become ready"

step "2. Bootstrap roles (mimics telemed-ia-infra-postgres)"
# Minimal replica of postgres/init/01-instance.sh in telemed-ia-infra-postgres.
# If the infrastructure changes how notifications_app, _reader or _writer
# are created, this block must be updated in the same PR. CI cannot check
# out the private infra repo, so this duplication is intentional.
admin_psql -v app_password="$APP_PASSWORD" <<'SQL'
CREATE ROLE notifications_app LOGIN PASSWORD :'app_password';
CREATE ROLE notifications_reader NOLOGIN;
CREATE ROLE notifications_writer NOLOGIN;
GRANT notifications_reader, notifications_writer TO notifications_app WITH ADMIN OPTION;
GRANT CREATE ON DATABASE telemed_ia TO notifications_app;
CREATE SCHEMA notifications AUTHORIZATION notifications_app;
ALTER ROLE notifications_app SET search_path = notifications;
SQL

step "3. Apply all migrations"
liquibase update
first="$(applied_count)"
echo "applied=${first}"
[ "$first" = "$expected" ] || fail "applied ${first} changesets, expected ${expected}"

step "4. Idempotency: second update applies zero changesets"
liquibase update
second="$(applied_count)"
[ "$second" = "$first" ] || fail "second update applied $((second - first)) changesets"

step "5. Rollback every changeset"
if [ "$first" -gt 0 ]; then
  liquibase rollback-count --count="$first"
fi
remaining="$(applied_count)"
[ "$remaining" = "0" ] || fail "${remaining} changesets remain after rollback"
# The schema belongs to the infrastructure and survives the rollback; only
# the Liquibase control tables may remain inside it.
leftover="$(app_psql -tA <<SQL
SELECT (SELECT COUNT(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
         WHERE n.nspname = '${SCHEMA}' AND c.relname NOT LIKE 'databasechangelog%')
     + (SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = '${SCHEMA}');
SQL
)"
[ "$leftover" = "0" ] || fail "${leftover} domain objects remain in schema ${SCHEMA} after rollback"

step "6. Rebuild from scratch"
liquibase update
rebuilt="$(applied_count)"
[ "$rebuilt" = "$expected" ] || fail "rebuild applied ${rebuilt} changesets, expected ${expected}"

step "7. SQL tests"
shopt -s nullglob
for test_file in "$REPO_ROOT"/tests/sql/*.sql; do
  echo "--- $(basename "$test_file")"
  app_psql < "$test_file" || fail "$(basename "$test_file")"
done

printf '\nALL NOTIFICATIONS DB TESTS PASSED\n'
