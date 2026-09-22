#!/usr/bin/env bash

set -euo pipefail


: "${POSTGRES_DB:=education_lab2}"
: "${POSTGRES_USER:=postgres}"


COMPOSE=(docker compose exec -T postgres)


psql_admin() {
    "${COMPOSE[@]}" \
        psql \
        -U "$POSTGRES_USER" \
        -d postgres \
        -v ON_ERROR_STOP=1 \
        "$@"
}


psql_db() {
    local db="$1"
    shift

    "${COMPOSE[@]}" \
        psql \
        -U "$POSTGRES_USER" \
        -d "$db" \
        -v ON_ERROR_STOP=1 \
        "$@"
}


run_sql() {
    local db="$1"
    local file="$2"

    "${COMPOSE[@]}" \
        psql \
        -U "$POSTGRES_USER" \
        -d "$db" \
        -v ON_ERROR_STOP=1 \
        -f - < "$file"
}


cleanup_db() {
    local db="$1"

    psql_admin \
        -c "SELECT pg_terminate_backend(pid)
            FROM pg_stat_activity
            WHERE datname = '$db'
              AND pid <> pg_backend_pid();" \
        >/dev/null

    "${COMPOSE[@]}" \
        dropdb \
        -U "$POSTGRES_USER" \
        --if-exists \
        "$db" \
        >/dev/null
}


create_db() {
    "${COMPOSE[@]}" \
        createdb \
        -U "$POSTGRES_USER" \
        "$1"
}


echo '== Start PostgreSQL =='

docker compose up -d --wait


DB_CLEAN="${POSTGRES_DB}_clean"
DB_UPGRADE="${POSTGRES_DB}_upgrade"


cleanup_db "$DB_CLEAN"
cleanup_db "$DB_UPGRADE"


echo
echo '== Clean install test: 001 -> 002 -> seed -> negative tests =='


create_db "$DB_CLEAN"


echo '-- Migration 001'
run_sql \
    "$DB_CLEAN" \
    migrations/001_initial_schema.sql


echo '-- Migration 002'
run_sql \
    "$DB_CLEAN" \
    migrations/002_course_prerequisites.sql


echo '-- Seed'
run_sql \
    "$DB_CLEAN" \
    data/seed.sql


echo '-- Negative tests'
run_sql \
    "$DB_CLEAN" \
    tests/negative_constraints.sql


echo '-- Table count'

psql_db \
    "$DB_CLEAN" \
    -c "SELECT count(*) AS table_count
        FROM information_schema.tables
        WHERE table_schema = 'public';"


echo '-- Prerequisite relations'

psql_db \
    "$DB_CLEAN" \
    -c "SELECT
            c.title,
            cp.prerequisite_course_id
        FROM courses c
        JOIN course_prerequisites cp
            ON cp.course_id = c.id;"


echo
echo '== Upgrade test: install 001, keep old data, then apply 002 =='


create_db "$DB_UPGRADE"


echo '-- Migration 001'
run_sql \
    "$DB_UPGRADE" \
    migrations/001_initial_schema.sql


echo '-- Create old-version test data'

"${COMPOSE[@]}" \
    psql \
    -U "$POSTGRES_USER" \
    -d "$DB_UPGRADE" \
    -v ON_ERROR_STOP=1 <<'SQL'

INSERT INTO users(
    email,
    full_name,
    password_hash
)
VALUES (
    'upgrade@example.com',
    'Upgrade Test',
    '$2b$12$upgrade_hash'
);

-- Пользователь получает роль преподавателя.
INSERT INTO user_roles(user_id, role_id)
SELECT u.id, r.id
FROM users u
JOIN roles r ON r.code = 'teacher'
WHERE u.email = 'upgrade@example.com';

-- Два курса существуют уже на версии 001.
INSERT INTO courses(
    teacher_id,
    title,
    description,
    status
)
SELECT
    u.id,
    'Upgrade Course A',
    'Course created on version 001.',
    'draft'
FROM users u
WHERE u.email = 'upgrade@example.com';

INSERT INTO courses(
    teacher_id,
    title,
    description,
    status
)
SELECT
    u.id,
    'Upgrade Course B',
    'Prerequisite course.',
    'draft'
FROM users u
WHERE u.email = 'upgrade@example.com';

SELECT
    1 AS old_version_data_present
FROM users
WHERE email = 'upgrade@example.com';

SELECT
    count(*) AS old_version_courses
FROM courses c
JOIN users u ON u.id = c.teacher_id
WHERE u.email = 'upgrade@example.com';

SQL


echo '-- Migration 002'

run_sql \
    "$DB_UPGRADE" \
    migrations/002_course_prerequisites.sql


echo '-- Check new table'

psql_db \
    "$DB_UPGRADE" \
    -c "SELECT
            to_regclass('public.course_prerequisites')
            AS prerequisite_table;"


echo '-- Check old data'

psql_db \
    "$DB_UPGRADE" \
    -c "SELECT
            count(*) AS preserved_users
        FROM users
        WHERE email = 'upgrade@example.com';"


echo '-- Smoke test of new feature'

psql_db "$DB_UPGRADE" <<'SQL'

INSERT INTO course_prerequisites(
    course_id,
    prerequisite_course_id
)
SELECT
    target.id,
    prerequisite.id
FROM courses target
JOIN courses prerequisite
    ON prerequisite.title = 'Upgrade Course B'
WHERE target.title = 'Upgrade Course A';

SELECT
    c.title AS course,
    p.title AS prerequisite
FROM course_prerequisites cp
JOIN courses c
    ON c.id = cp.course_id
JOIN courses p
    ON p.id = cp.prerequisite_course_id;

SQL


echo
echo 'ALL MIGRATION TESTS PASSED'