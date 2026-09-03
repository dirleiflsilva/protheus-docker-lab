#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

required_files=(
  ".env"
  "config/appserver.ini"
  "config/dbaccess.ini"
  "config/odbc.ini"
  "config/odbcinst.ini"
  "volumes/apo/tttm120.rpo"
  "volumes/systemload/sx2.unq"
  "volumes/systemload/sxsbra.txt"
)
required_variables=(
  COMPOSE_PROJECT_NAME
  LICENSE_IMAGE
  POSTGRES_IMAGE
  DBACCESS_IMAGE
  APPSERVER_IMAGE
  POSTGRES_HOST
  POSTGRES_PORT
  POSTGRES_DB
  POSTGRES_USER
  POSTGRES_PASSWORD
  DBACCESS_ALIAS
  DBACCESS_PORT
  APPSERVER_PORT
  WEBAPP_PORT
  LICENSE_HOST
  LICENSE_PORT
)
port_variables=(POSTGRES_PORT DBACCESS_PORT APPSERVER_PORT WEBAPP_PORT LICENSE_PORT)
problems=()

cd "$ROOT_DIR"

for file in "${required_files[@]}"; do
  if [[ ! -e "$file" ]]; then
    problems+=("Arquivo obrigatorio ausente: $file")
  elif [[ ! -f "$file" ]]; then
    problems+=("Caminho obrigatorio nao e um arquivo regular: $file")
  elif [[ ! -s "$file" ]]; then
    problems+=("Arquivo obrigatorio vazio: $file")
  elif [[ ! -r "$file" ]]; then
    problems+=("Arquivo obrigatorio sem permissao de leitura: $file")
  fi
done

docker_available=true
if ! command -v docker >/dev/null 2>&1; then
  problems+=("Docker nao encontrado no PATH")
  docker_available=false
elif ! docker compose version >/dev/null 2>&1; then
  problems+=("Docker Compose nao esta disponivel pelo comando docker compose")
  docker_available=false
fi

declare -A compose_environment=()
if [[ "$docker_available" == true ]]; then
  if environment_output="$(
    for variable_name in "${required_variables[@]}"; do
      unset "$variable_name"
    done
    docker compose config --environment 2>/dev/null
  )"; then
    while IFS='=' read -r variable_name variable_value; do
      [[ -n "$variable_name" ]] || continue
      compose_environment["$variable_name"]="$variable_value"
    done <<< "$environment_output"

    for variable_name in "${required_variables[@]}"; do
      if [[ -z "${compose_environment[$variable_name]-}" ]]; then
        problems+=("Variavel obrigatoria ausente ou vazia: $variable_name")
      fi
    done

    for variable_name in "${port_variables[@]}"; do
      variable_value="${compose_environment[$variable_name]-}"
      if [[ -n "$variable_value" ]] && \
        { [[ ! "$variable_value" =~ ^[0-9]+$ ]] || [[ ${#variable_value} -gt 5 ]] || \
          (( 10#$variable_value < 1 || 10#$variable_value > 65535 )); }; then
        problems+=("Porta invalida em $variable_name: informe um inteiro entre 1 e 65535")
      fi
    done
  else
    problems+=("Nao foi possivel interpretar o arquivo .env com Docker Compose")
  fi

  if ! docker compose config --quiet >/dev/null 2>&1; then
    problems+=("A configuracao do Docker Compose e invalida")
  fi
fi

expect_line() {
  local file="$1"
  local expected_line="$2"
  local description="$3"

  if [[ -r "$file" ]] && ! grep -aFqx -- "$expected_line" "$file"; then
    problems+=("Inconsistencia entre .env e $description")
  fi
}

if [[ -n "${compose_environment[DBACCESS_ALIAS]-}" ]]; then
  expect_line config/appserver.ini "Alias=${compose_environment[DBACCESS_ALIAS]-}" "config/appserver.ini (DBAccess Alias)"
  expect_line config/odbc.ini "[${compose_environment[DBACCESS_ALIAS]-}]" "config/odbc.ini (alias)"
  expect_line config/dbaccess.ini "[POSTGRES/${compose_environment[DBACCESS_ALIAS]-}]" "config/dbaccess.ini (alias)"
fi
if [[ -n "${compose_environment[DBACCESS_PORT]-}" ]]; then
  expect_line config/appserver.ini "Port=${compose_environment[DBACCESS_PORT]-}" "config/appserver.ini (DBAccess Port)"
  expect_line config/dbaccess.ini "Port=${compose_environment[DBACCESS_PORT]-}" "config/dbaccess.ini (DBAccess Port)"
fi
if [[ -n "${compose_environment[LICENSE_HOST]-}" ]]; then
  expect_line config/appserver.ini "server=${compose_environment[LICENSE_HOST]-}" "config/appserver.ini (License Server)"
  expect_line config/dbaccess.ini "LicenseServer=${compose_environment[LICENSE_HOST]-}" "config/dbaccess.ini (License Server)"
fi
if [[ -n "${compose_environment[LICENSE_PORT]-}" ]]; then
  expect_line config/appserver.ini "port=${compose_environment[LICENSE_PORT]-}" "config/appserver.ini (License Port)"
  expect_line config/dbaccess.ini "LicensePort=${compose_environment[LICENSE_PORT]-}" "config/dbaccess.ini (License Port)"
fi
if [[ -n "${compose_environment[POSTGRES_HOST]-}" ]]; then
  expect_line config/odbc.ini "Servername=${compose_environment[POSTGRES_HOST]-}" "config/odbc.ini (host)"
fi
if [[ -n "${compose_environment[POSTGRES_PORT]-}" ]]; then
  expect_line config/odbc.ini "Port=${compose_environment[POSTGRES_PORT]-}" "config/odbc.ini (porta)"
fi
if [[ -n "${compose_environment[POSTGRES_DB]-}" ]]; then
  expect_line config/odbc.ini "Database=${compose_environment[POSTGRES_DB]-}" "config/odbc.ini (banco)"
fi
if [[ -n "${compose_environment[POSTGRES_USER]-}" ]]; then
  expect_line config/odbc.ini "Username=${compose_environment[POSTGRES_USER]-}" "config/odbc.ini (usuario)"
fi

if (( ${#problems[@]} > 0 )); then
  printf 'Foram encontrados problemas na configuracao do laboratorio:\n' >&2
  printf ' - %s\n' "${problems[@]}" >&2
  printf '\nCorrija os itens acima antes de subir o laboratorio.\n' >&2
  exit 1
fi

printf 'Validacao concluida com sucesso.\n'
