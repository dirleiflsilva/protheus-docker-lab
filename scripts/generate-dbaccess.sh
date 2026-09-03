#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

if [[ ! -s ".env" ]]; then
  printf 'Arquivo .env nao encontrado. Copie .env.example para .env antes de gerar o DBAccess.\n' >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  printf 'Docker nao encontrado no PATH.\n' >&2
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  printf 'Docker Compose nao esta disponivel pelo comando docker compose.\n' >&2
  exit 1
fi

required_variables=(
  DBACCESS_IMAGE
  POSTGRES_HOST
  POSTGRES_PORT
  POSTGRES_DB
  POSTGRES_USER
  POSTGRES_PASSWORD
  DBACCESS_ALIAS
  DBACCESS_PORT
  LICENSE_HOST
  LICENSE_PORT
)
port_variables=(POSTGRES_PORT DBACCESS_PORT LICENSE_PORT)

declare -A compose_environment=()
if ! environment_output="$(
  for variable_name in "${required_variables[@]}"; do
    unset "$variable_name"
  done
  docker compose config --environment
)"; then
  printf 'Nao foi possivel interpretar o arquivo .env com Docker Compose.\n' >&2
  exit 1
fi

while IFS='=' read -r variable_name variable_value; do
  [[ -n "$variable_name" ]] || continue
  compose_environment["$variable_name"]="$variable_value"
done <<< "$environment_output"

for variable_name in "${required_variables[@]}"; do
  if [[ -z "${compose_environment[$variable_name]-}" ]]; then
    printf 'Variavel obrigatoria ausente ou vazia no .env: %s\n' "$variable_name" >&2
    exit 1
  fi
  printf -v "$variable_name" '%s' "${compose_environment[$variable_name]}"
done

for variable_name in "${port_variables[@]}"; do
  variable_value="${compose_environment[$variable_name]}"
  if [[ ! "$variable_value" =~ ^[0-9]+$ ]] || [[ ${#variable_value} -gt 5 ]] || \
    (( 10#$variable_value < 1 || 10#$variable_value > 65535 )); then
    printf 'Porta invalida em %s: informe um inteiro entre 1 e 65535.\n' "$variable_name" >&2
    exit 1
  fi
done

for variable_name in POSTGRES_HOST POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD DBACCESS_ALIAS; do
  variable_value="${compose_environment[$variable_name]}"
  if [[ "$variable_value" == *"!"* || "$variable_value" == *"@"* || "$variable_value" == *";"* ]]; then
    printf 'A variavel %s contem um caractere reservado pelo gerador: !, @ ou ;.\n' "$variable_name" >&2
    exit 1
  fi
done

mkdir -p config

temporary_dir="$(mktemp -d "$ROOT_DIR/config/.dbaccess.XXXXXX")"
trap 'rm -rf -- "$temporary_dir"' EXIT

if ! docker run --rm \
  -v "${temporary_dir}:/local" \
  --workdir=/local \
  "${DBACCESS_IMAGE}" \
  /opt/totvs/dbaccess/tools/dbaccesscfg \
  -u "${POSTGRES_USER}" \
  -p "${POSTGRES_PASSWORD}" \
  -a "${DBACCESS_ALIAS}" \
  -d postgres \
  -c /usr/lib64/libodbc.so \
  -o "ConnectionMode=2;ConnectionString=DRIVER!{PostgreSQL}@SERVERNAME!${POSTGRES_HOST}@PORT!${POSTGRES_PORT}@DATABASE!${POSTGRES_DB}@USERNAME!${POSTGRES_USER}@PASSWORD!${POSTGRES_PASSWORD}" \
  -g "MAXSTRINGSIZE=100;LicenseServer=${LICENSE_HOST};LicensePort=${LICENSE_PORT};AdjustColName=1;ConsoleLog=1;ConsoleMaxSize=20971520;CountAllConnections=1;ODBC30=1;ODBCConnectionPool=1;Port=${DBACCESS_PORT};ReleaseInactiveConn=30;ShowAllErrors=0;UseLargeRecno=1;AuditLog=0" \
  > "$temporary_dir/dbaccesscfg.log" 2>&1; then
  printf 'Falha ao gerar o dbaccess.ini no container. Os arquivos atuais foram preservados.\n' >&2
  exit 1
fi

if [[ ! -s "$temporary_dir/dbaccess.ini" ]]; then
  printf 'O dbaccesscfg nao gerou um arquivo dbaccess.ini valido.\n' >&2
  exit 1
fi

sed -e 's/!/=/g' -e 's/@/;/g' \
  "$temporary_dir/dbaccess.ini" > "$temporary_dir/dbaccess.processed.ini"

cat > "$temporary_dir/odbc.ini" <<EOF
[${DBACCESS_ALIAS}]
Driver=PostgreSQL
Servername=${POSTGRES_HOST}
Port=${POSTGRES_PORT}
Database=${POSTGRES_DB}
Username=${POSTGRES_USER}
Password=${POSTGRES_PASSWORD}
EOF

cat > "$temporary_dir/odbcinst.ini" <<'EOF'
[PostgreSQL]
Description=ODBC for PostgreSQL
Driver=/usr/lib/psqlodbcw.so
Setup=/usr/lib/libodbcpsqlS.so
Driver64=/usr/lib64/psqlodbca.so
Setup64=/usr/lib64/libodbcpsqlS.so
FileUsage=1
EOF

chmod 600 "$temporary_dir/dbaccess.processed.ini" "$temporary_dir/odbc.ini" "$temporary_dir/odbcinst.ini"
mv -f -- "$temporary_dir/dbaccess.processed.ini" config/dbaccess.ini
mv -f -- "$temporary_dir/odbc.ini" config/odbc.ini
mv -f -- "$temporary_dir/odbcinst.ini" config/odbcinst.ini

printf 'Arquivos gerados:\n'
printf ' - config/dbaccess.ini\n'
printf ' - config/odbc.ini\n'
printf ' - config/odbcinst.ini\n'
