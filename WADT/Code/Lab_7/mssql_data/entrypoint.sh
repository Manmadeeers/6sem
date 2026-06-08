#!/bin/bash
set -euo pipefail

/opt/mssql/bin/sqlservr &
sqlservr_pid=$!

cleanup() {
    if kill -0 "$sqlservr_pid" >/dev/null 2>&1; then
        kill -TERM "$sqlservr_pid"
        wait "$sqlservr_pid"
    fi
}

trap cleanup SIGINT SIGTERM

sqlcmd_bin=""
sqlcmd_args=()

if [ -x /opt/mssql-tools18/bin/sqlcmd ]; then
    sqlcmd_bin=/opt/mssql-tools18/bin/sqlcmd
    sqlcmd_args=(-C)
elif [ -x /opt/mssql-tools/bin/sqlcmd ]; then
    sqlcmd_bin=/opt/mssql-tools/bin/sqlcmd
else
    echo "sqlcmd was not found in the container image" >&2
    exit 1
fi

for _ in $(seq 1 60); do
    if "$sqlcmd_bin" -S localhost -U sa -P "$SA_PASSWORD" "${sqlcmd_args[@]}" -Q "SELECT 1" >/dev/null 2>&1; then
        ready=1
        break
    fi

    sleep 2
done

if [ "${ready:-0}" -ne 1 ]; then
    echo "SQL Server did not become ready in time" >&2
    exit 1
fi

"$sqlcmd_bin" -S localhost -U sa -P "$SA_PASSWORD" "${sqlcmd_args[@]}" -i /var/opt/mssql/db_init.sql

wait "$sqlservr_pid"
