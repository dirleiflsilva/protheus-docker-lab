#!/usr/bin/env bash
set -euo pipefail

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

missing=()

for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    missing+=("$file")
  fi
done

if (( ${#missing[@]} > 0 )); then
  printf 'Arquivos obrigatorios ausentes:\n' >&2
  printf ' - %s\n' "${missing[@]}" >&2
  printf '\nExecute a preparacao descrita no README antes de subir o laboratorio.\n' >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  printf 'Docker nao encontrado no PATH.\n' >&2
  exit 1
fi

docker compose config >/dev/null

printf 'Validacao concluida com sucesso.\n'
