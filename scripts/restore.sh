#!/usr/bin/env bash
set -euo pipefail
if (( $# != 2 )); then
  printf 'Uso: %s arquivo.dump novo_banco\nRestaura somente em um banco novo; nunca substitui um banco existente.\n' "$0" >&2
  exit 1
fi
# Resolve o arquivo antes de mudar para a raiz do projeto.
archive="$(realpath -- "$1")"
target="$2"
if [[ ! -f "$archive" || ! -s "$archive" || ! -r "$archive" ]]; then
  printf 'Backup ausente, vazio ou ilegível: %s\n' "$archive" >&2
  exit 1
fi
if [[ ! "$target" =~ ^[a-z][a-z0-9_]{0,62}$ ]]; then
  printf 'Use um nome de banco com até 63 caracteres: letras minúsculas, números e sublinhado, começando por letra.\n' >&2
  exit 1
fi
source "$(dirname "${BASH_SOURCE[0]}")/lib/postgres.sh"
if [[ "$target" == "${pg_config[POSTGRES_DB]}" || "$target" == postgres || "$target" == template[01] ]]; then
  printf 'Restauração recusada: escolha um banco novo diferente do banco do laboratório e dos bancos de sistema.\n' >&2
  exit 1
fi
pg_exec pg_restore --list < "$archive" > /dev/null
# createdb falha se o destino já existir, inclusive em caso de criação concorrente.
pg_exec createdb "${pg_connection[@]}" --template=template0 -- "$target"
if ! pg_exec pg_restore "${pg_connection[@]}" --dbname="$target" --single-transaction --no-owner --no-acl < "$archive"; then
  printf 'Restauração falhou. O banco %s foi mantido para diagnóstico; não será removido automaticamente.\n' "$target" >&2
  exit 1
fi
printf 'Restauração concluída no banco %s. O AppServer continua usando o banco original.\n' "$target"
