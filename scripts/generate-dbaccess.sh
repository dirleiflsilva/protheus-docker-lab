#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f ".env" ]]; then
  printf 'Arquivo .env nao encontrado. Copie .env.example para .env antes de gerar o DBAccess.\n' >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  printf 'Docker nao encontrado no PATH.\n' >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
. ./.env
set +a

DBACCESS_IMAGE="${DBACCESS_IMAGE:-totvsengpro/dbaccess-postgres-dev}"
POSTGRES_HOST="${POSTGRES_HOST:-postgres-iniciado}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_DB="${POSTGRES_DB:-protheus}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres}"
DBACCESS_PORT="${DBACCESS_PORT:-7890}"
DBACCESS_ALIAS="${DBACCESS_ALIAS:-$POSTGRES_DB}"
LICENSE_HOST="${LICENSE_HOST:-license}"
LICENSE_PORT="${LICENSE_PORT:-5555}"

mkdir -p config

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

docker run --rm \
  -v "${tmpdir}:/local" \
  --workdir=/local \
  "${DBACCESS_IMAGE}" \
  /opt/totvs/dbaccess/tools/dbaccesscfg \
  -u "${POSTGRES_USER}" \
  -p "${POSTGRES_PASSWORD}" \
  -a "${DBACCESS_ALIAS}" \
  -d postgres \
  -c /usr/lib64/libodbc.so \
  -o "ConnectionMode=2;ConnectionString=DRIVER!{PostgreSQL}@SERVERNAME!${POSTGRES_HOST}@PORT!${POSTGRES_PORT}@DATABASE!${POSTGRES_DB}@USERNAME!${POSTGRES_USER}@PASSWORD!${POSTGRES_PASSWORD}" \
  -g "MAXSTRINGSIZE=100;LicenseServer=${LICENSE_HOST};LicensePort=${LICENSE_PORT};AdjustColName=1;ConsoleLog=1;ConsoleMaxSize=20971520;CountAllConnections=1;ODBC30=1;ODBCConnectionPool=1;Port=${DBACCESS_PORT};ReleaseInactiveConn=30;ShowAllErrors=0;UseLargeRecno=1;AuditLog=0"

sed -e 's/!/=/g' -e 's/@/;/g' "${tmpdir}/dbaccess.ini" > config/dbaccess.ini

cat > config/odbc.ini <<EOF
[${DBACCESS_ALIAS}]
Driver=PostgreSQL
Servername=${POSTGRES_HOST}
Port=${POSTGRES_PORT}
Database=${POSTGRES_DB}
Username=${POSTGRES_USER}
Password=${POSTGRES_PASSWORD}
EOF

cat > config/odbcinst.ini <<'EOF'
[PostgreSQL]
Description=ODBC for PostgreSQL
Driver=/usr/lib/psqlodbcw.so
Setup=/usr/lib/libodbcpsqlS.so
Driver64=/usr/lib64/psqlodbca.so
Setup64=/usr/lib64/libodbcpsqlS.so
FileUsage=1
EOF

printf 'Arquivos gerados:\n'
printf ' - config/dbaccess.ini\n'
printf ' - config/odbc.ini\n'
printf ' - config/odbcinst.ini\n'
