#!/usr/bin/env bash
set -euo pipefail
if (( $# != 0 )); then
  printf 'Uso: %s\n' "$0" >&2
  exit 1
fi
source "$(dirname "${BASH_SOURCE[0]}")/lib/postgres.sh"
umask 077
mkdir -p backups
backup_dir="$(mktemp -d "$ROOT_DIR/backups/postgres-$(date -u +%Y%m%dT%H%M%SZ)-XXXXXX")"
partial="$backup_dir/database.dump.partial"
if ! pg_exec pg_dump "${pg_connection[@]}" -d "${pg_config[POSTGRES_DB]}" --format=custom > "$partial"; then
  printf 'Backup falhou. Arquivo incompleto preservado em %s\n' "$partial" >&2
  exit 1
fi
pg_exec pg_restore --list < "$partial" > "$backup_dir/conteudo.txt"
mv "$partial" "$backup_dir/database.dump"
printf 'Backup concluído: %s/database.dump\n' "$backup_dir"
