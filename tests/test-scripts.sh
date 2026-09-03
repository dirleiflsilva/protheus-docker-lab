#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

fail() {
  printf 'FALHOU: %s\n' "$1" >&2
  exit 1
}

prepare_case() {
  local case_dir="$1"

  mkdir -p "$case_dir/config" "$case_dir/files" "$case_dir/scripts" "$case_dir/mock-bin"
  cp "$ROOT_DIR/.env.example" "$case_dir/.env.example"
  cp "$ROOT_DIR/docker-compose.yml" "$case_dir/docker-compose.yml"
  cp "$ROOT_DIR/config/appserver.ini.example" "$case_dir/config/appserver.ini.example"
  cp "$ROOT_DIR/scripts/check.sh" "$case_dir/scripts/check.sh"
  cp "$ROOT_DIR/scripts/generate-dbaccess.sh" "$case_dir/scripts/generate-dbaccess.sh"
  cp "$ROOT_DIR/scripts/setup.sh" "$case_dir/scripts/setup.sh"
  chmod +x "$case_dir/scripts/"*.sh

  printf 'RPO de teste\n' > "$case_dir/files/tttm120.rpo"
  printf 'SX2 de teste\n' > "$case_dir/files/sx2.unq"
  printf 'SXS de teste\n' > "$case_dir/files/sxsbra.txt"

  cat > "$case_dir/mock-bin/docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "compose" && "${2:-}" == "version" ]]; then
  exit 0
fi

if [[ "${1:-}" == "compose" && "${2:-}" == "config" && "${3:-}" == "--environment" ]]; then
  sed -n '/^[A-Za-z_][A-Za-z0-9_]*=/p' .env
  exit 0
fi

if [[ "${1:-}" == "compose" && "${2:-}" == "config" && "${3:-}" == "--quiet" ]]; then
  exit 0
fi

if [[ "${1:-}" == "run" ]]; then
  [[ "${MOCK_GENERATOR_FAIL:-0}" != "1" ]] || exit 42
  while (( $# > 0 )); do
    if [[ "$1" == "-v" ]]; then
      output_dir="${2%%:*}"
      alias="$(sed -n 's/^DBACCESS_ALIAS=//p' .env)"
      dbaccess_port="$(sed -n 's/^DBACCESS_PORT=//p' .env)"
      license_host="$(sed -n 's/^LICENSE_HOST=//p' .env)"
      license_port="$(sed -n 's/^LICENSE_PORT=//p' .env)"
      {
        printf '[GENERAL]\n'
        printf 'LicenseServer=%s\n' "$license_host"
        printf 'LicensePort=%s\n' "$license_port"
        printf 'Port=%s\n' "$dbaccess_port"
        printf '\n[POSTGRES/%s]\n' "$alias"
      } > "$output_dir/dbaccess.ini"
      exit 0
    fi
    shift
  done
fi

exit 1
EOF
  chmod +x "$case_dir/mock-bin/docker"
}

run_script() {
  local case_dir="$1"
  local script="$2"
  shift 2

  PATH="$case_dir/mock-bin:$PATH" "$case_dir/scripts/$script" "$@"
}

test_setup_prepares_environment() {
  local case_dir="$TEST_ROOT/setup"

  prepare_case "$case_dir"
  (cd "$TEST_ROOT" && run_script "$case_dir" setup.sh)

  [[ -s "$case_dir/.env" ]] || fail '.env nao foi criado'
  [[ "$(stat -c '%a' "$case_dir/.env")" == "600" ]] || fail '.env nao ficou com permissao 600'
  [[ -s "$case_dir/config/appserver.ini" ]] || fail 'appserver.ini nao foi criado'
  [[ -s "$case_dir/config/dbaccess.ini" ]] || fail 'dbaccess.ini nao foi gerado'
  [[ -s "$case_dir/config/odbc.ini" ]] || fail 'odbc.ini nao foi gerado'
  [[ -s "$case_dir/config/odbcinst.ini" ]] || fail 'odbcinst.ini nao foi gerado'
  [[ -s "$case_dir/volumes/apo/tttm120.rpo" ]] || fail 'RPO nao foi copiado'
  [[ -s "$case_dir/volumes/systemload/sx2.unq" ]] || fail 'sx2.unq nao foi copiado'
  [[ -s "$case_dir/volumes/systemload/sxsbra.txt" ]] || fail 'sxsbra.txt nao foi copiado'
  [[ -d "$case_dir/volumes/logs" ]] || fail 'diretorio de logs nao foi criado'
}

test_setup_preserves_local_files() {
  local case_dir="$TEST_ROOT/preserve"

  prepare_case "$case_dir"
  (cd "$TEST_ROOT" && run_script "$case_dir" setup.sh)
  printf '\n; configuracao local\n' >> "$case_dir/config/appserver.ini"
  printf 'RPO local\n' > "$case_dir/volumes/apo/tttm120.rpo"
  printf '\n; DBAccess local\n' >> "$case_dir/config/dbaccess.ini"

  (cd "$TEST_ROOT" && run_script "$case_dir" setup.sh)

  grep -Fqx '; configuracao local' "$case_dir/config/appserver.ini" || fail 'appserver.ini foi sobrescrito'
  [[ "$(<"$case_dir/volumes/apo/tttm120.rpo")" == 'RPO local' ]] || fail 'RPO foi sobrescrito'
  grep -Fqx '; DBAccess local' "$case_dir/config/dbaccess.ini" || fail 'DBAccess foi regenerado'
}

test_force_updates_work_files() {
  local case_dir="$TEST_ROOT/force"

  prepare_case "$case_dir"
  (cd "$TEST_ROOT" && run_script "$case_dir" setup.sh)
  printf 'RPO atualizado\n' > "$case_dir/files/tttm120.rpo"
  printf 'DBAccess local\n' > "$case_dir/config/dbaccess.ini"

  (cd "$TEST_ROOT" && run_script "$case_dir" setup.sh --force)

  [[ "$(<"$case_dir/volumes/apo/tttm120.rpo")" == 'RPO atualizado' ]] || fail '--force nao atualizou o RPO'
  [[ "$(<"$case_dir/config/dbaccess.ini")" != 'DBAccess local' ]] || fail '--force nao regenerou o DBAccess'
}

test_setup_rejects_missing_artifact() {
  local case_dir="$TEST_ROOT/missing-artifact"
  local output_file="$case_dir/setup.out"

  prepare_case "$case_dir"
  rm "$case_dir/files/sx2.unq"

  if (cd "$TEST_ROOT" && run_script "$case_dir" setup.sh) > "$output_file" 2>&1; then
    fail 'setup aceitou artefato ausente'
  fi

  grep -Fq 'volumes/systemload/sx2.unq' "$output_file" || fail 'setup nao identificou o artefato ausente'
  [[ ! -e "$case_dir/config/dbaccess.ini" ]] || fail 'setup chamou o gerador com artefato ausente'
}

test_setup_rejects_partial_dbaccess_configuration() {
  local case_dir="$TEST_ROOT/partial-dbaccess"

  prepare_case "$case_dir"
  (cd "$TEST_ROOT" && run_script "$case_dir" setup.sh)
  rm "$case_dir/config/odbc.ini"

  if (cd "$TEST_ROOT" && run_script "$case_dir" setup.sh) >/dev/null 2>&1; then
    fail 'setup aceitou configuracao parcial do DBAccess'
  fi

  [[ -s "$case_dir/config/dbaccess.ini" ]] || fail 'setup removeu configuracao existente'
}

test_setup_rejects_missing_docker() {
  local case_dir="$TEST_ROOT/no-docker"
  local path_dir="$case_dir/path"

  prepare_case "$case_dir"
  mkdir -p "$path_dir"
  ln -s /usr/bin/dirname "$path_dir/dirname"

  if (cd "$TEST_ROOT" && PATH="$path_dir" /bin/bash "$case_dir/scripts/setup.sh") >/dev/null 2>&1; then
    fail 'setup aceitou ambiente sem Docker'
  fi

  [[ ! -e "$case_dir/.env" ]] || fail 'setup alterou o ambiente antes de validar Docker'
}

test_check_rejects_empty_file() {
  local case_dir="$TEST_ROOT/check"

  prepare_case "$case_dir"
  (cd "$TEST_ROOT" && run_script "$case_dir" setup.sh)
  : > "$case_dir/volumes/systemload/sx2.unq"

  if (cd "$TEST_ROOT" && run_script "$case_dir" check.sh) >/dev/null 2>&1; then
    fail 'check aceitou arquivo obrigatorio vazio'
  fi
}

test_check_rejects_incomplete_env() {
  local case_dir="$TEST_ROOT/incomplete-env"

  prepare_case "$case_dir"
  (cd "$TEST_ROOT" && run_script "$case_dir" setup.sh)
  sed -i '/^POSTGRES_USER=/d' "$case_dir/.env"

  if (cd "$TEST_ROOT" && POSTGRES_USER=valor_herdado run_script "$case_dir" check.sh) >/dev/null 2>&1; then
    fail 'check aceitou .env incompleto usando variavel herdada'
  fi
}

test_check_rejects_invalid_port() {
  local case_dir="$TEST_ROOT/invalid-port"

  prepare_case "$case_dir"
  (cd "$TEST_ROOT" && run_script "$case_dir" setup.sh)
  sed -i 's/^WEBAPP_PORT=.*/WEBAPP_PORT=70000/' "$case_dir/.env"

  if (cd "$TEST_ROOT" && run_script "$case_dir" check.sh) >/dev/null 2>&1; then
    fail 'check aceitou porta invalida'
  fi
}

test_check_rejects_configuration_mismatch() {
  local case_dir="$TEST_ROOT/mismatch"

  prepare_case "$case_dir"
  (cd "$TEST_ROOT" && run_script "$case_dir" setup.sh)
  sed -i 's/^DBACCESS_ALIAS=.*/DBACCESS_ALIAS=outro_alias/' "$case_dir/.env"

  if (cd "$TEST_ROOT" && run_script "$case_dir" check.sh) >/dev/null 2>&1; then
    fail 'check aceitou inconsistencia entre .env e arquivos INI'
  fi
}

test_env_is_not_executed() {
  local case_dir="$TEST_ROOT/env"
  local marker="$case_dir/executado"

  prepare_case "$case_dir"
  cp "$case_dir/.env.example" "$case_dir/.env"
  sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=\$(touch $marker)|" "$case_dir/.env"

  (cd "$TEST_ROOT" && run_script "$case_dir" generate-dbaccess.sh) >/dev/null

  [[ ! -e "$marker" ]] || fail 'generate-dbaccess.sh executou conteudo do .env'
}

test_generator_failure_preserves_files() {
  local case_dir="$TEST_ROOT/generator-failure"
  local output_file="$case_dir/generator.out"
  local test_password="senha-que-nao-deve-aparecer"

  prepare_case "$case_dir"
  cp "$case_dir/.env.example" "$case_dir/.env"
  sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$test_password/" "$case_dir/.env"
  printf 'DBAccess existente\n' > "$case_dir/config/dbaccess.ini"
  printf 'ODBC existente\n' > "$case_dir/config/odbc.ini"
  printf 'ODBCInst existente\n' > "$case_dir/config/odbcinst.ini"

  if (cd "$TEST_ROOT" && MOCK_GENERATOR_FAIL=1 run_script "$case_dir" generate-dbaccess.sh) > "$output_file" 2>&1; then
    fail 'gerador ignorou a falha do container'
  fi

  [[ "$(<"$case_dir/config/dbaccess.ini")" == 'DBAccess existente' ]] || fail 'gerador alterou arquivo apos falha'
  [[ "$(<"$case_dir/config/odbc.ini")" == 'ODBC existente' ]] || fail 'gerador alterou ODBC apos falha'
  [[ "$(<"$case_dir/config/odbcinst.ini")" == 'ODBCInst existente' ]] || fail 'gerador alterou ODBCInst apos falha'
  if grep -Fq "$test_password" "$output_file"; then
    fail 'gerador exibiu a senha no log'
  fi
}

test_setup_prepares_environment
test_setup_preserves_local_files
test_force_updates_work_files
test_setup_rejects_missing_artifact
test_setup_rejects_partial_dbaccess_configuration
test_setup_rejects_missing_docker
test_check_rejects_empty_file
test_check_rejects_incomplete_env
test_check_rejects_invalid_port
test_check_rejects_configuration_mismatch
test_env_is_not_executed
test_generator_failure_preserves_files

printf 'Todos os testes de scripts passaram.\n'
