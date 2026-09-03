#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORCE=false

if (( $# > 1 )) || { (( $# == 1 )) && [[ "$1" != "--force" ]]; }; then
  printf 'Uso: %s [--force]\n' "${0##*/}" >&2
  exit 2
fi

if (( $# == 1 )); then
  FORCE=true
fi

cd "$ROOT_DIR"

if ! command -v docker >/dev/null 2>&1; then
  printf 'Docker nao encontrado no PATH.\n' >&2
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  printf 'Docker Compose nao esta disponivel pelo comando docker compose.\n' >&2
  exit 1
fi

atomic_copy() (
  local source_file="$1"
  local target_file="$2"
  local temporary_file

  temporary_file="$(mktemp "${target_file}.tmp.XXXXXX")"
  trap 'rm -f -- "$temporary_file"' EXIT
  cp -- "$source_file" "$temporary_file"
  chmod --reference="$source_file" "$temporary_file"
  mv -f -- "$temporary_file" "$target_file"
)

copy_if_missing() {
  local source_file="$1"
  local target_file="$2"

  if [[ ! -f "$target_file" ]]; then
    atomic_copy "$source_file" "$target_file"
    printf 'Criado: %s\n' "$target_file"
  fi
}

copy_artifact_if_available() {
  local source_file="$1"
  local target_file="$2"

  if [[ -f "$source_file" && ( "$FORCE" == true || ! -f "$target_file" ) ]]; then
    atomic_copy "$source_file" "$target_file"
    printf 'Copiado: %s\n' "$target_file"
  fi
}

copy_if_missing .env.example .env
chmod 600 .env
copy_if_missing config/appserver.ini.example config/appserver.ini

mkdir -p volumes/apo volumes/systemload volumes/logs

copy_artifact_if_available files/tttm120.rpo volumes/apo/tttm120.rpo
copy_artifact_if_available files/sx2.unq volumes/systemload/sx2.unq
copy_artifact_if_available files/sxsbra.txt volumes/systemload/sxsbra.txt

required_artifacts=(
  volumes/apo/tttm120.rpo
  volumes/systemload/sx2.unq
  volumes/systemload/sxsbra.txt
)
missing_artifacts=()

for artifact in "${required_artifacts[@]}"; do
  if [[ ! -s "$artifact" ]]; then
    missing_artifacts+=("$artifact")
  fi
done

if (( ${#missing_artifacts[@]} > 0 )); then
  printf 'Artefatos Protheus ausentes ou vazios:\n' >&2
  printf ' - %s\n' "${missing_artifacts[@]}" >&2
  printf '\nColoque os arquivos em files/ e execute novamente.\n' >&2
  exit 1
fi

derived_files=(config/dbaccess.ini config/odbc.ini config/odbcinst.ini)
derived_count=0

for derived_file in "${derived_files[@]}"; do
  [[ -s "$derived_file" ]] && derived_count=$((derived_count + 1))
done

if [[ "$FORCE" == true || "$derived_count" -eq 0 ]]; then
  "$ROOT_DIR/scripts/generate-dbaccess.sh"
elif [[ "$derived_count" -ne "${#derived_files[@]}" ]]; then
  printf 'A configuracao derivada do DBAccess esta incompleta.\n' >&2
  printf 'Use --force para regenerar os tres arquivos.\n' >&2
  exit 1
fi

"$ROOT_DIR/scripts/check.sh"

printf 'Preparacao concluida. Use ./scripts/up.sh para iniciar o laboratorio.\n'
