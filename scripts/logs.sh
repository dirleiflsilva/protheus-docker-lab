#!/usr/bin/env bash
set -euo pipefail

SERVICE="${1:-appserver}"
docker compose logs -f "$SERVICE"
