#!/usr/bin/env bash
# Configuração compartilhada pelos comandos de manutenção do PostgreSQL.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"
declare -A pg_config=()
environment_output="$(docker compose config --environment)"
while IFS='=' read -r key value; do
  case "$key" in
    POSTGRES_DB|POSTGRES_USER|POSTGRES_PORT) pg_config["$key"]="$value" ;;
  esac
done <<< "$environment_output"
unset environment_output
for key in POSTGRES_DB POSTGRES_USER POSTGRES_PORT; do
  if [[ -z "${pg_config[$key]-}" ]]; then
    printf 'Variável obrigatória ausente: %s\n' "$key" >&2
    exit 1
  fi
done
# Usa o socket local e o cliente da própria imagem, sem expor senha no comando.
pg_exec() {
  docker compose exec -T postgres-iniciado "$@"
}
pg_connection=(-U "${pg_config[POSTGRES_USER]}" -p "${pg_config[POSTGRES_PORT]}" --no-password)
