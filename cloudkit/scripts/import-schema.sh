#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=cktool-path.sh
source "$SCRIPT_DIR/cktool-path.sh"

SCHEMA_FILE="${1:-$SCRIPT_DIR/../schema/query-indexes.ckdb}"
ENVIRONMENT="${2:-development}"

if [[ ! -f "$SCHEMA_FILE" ]]; then
  echo "오류: 스키마 파일이 없습니다: $SCHEMA_FILE"
  exit 1
fi

if [[ -z "${CLOUDKIT_MANAGEMENT_TOKEN:-}" ]]; then
  echo "오류: CLOUDKIT_MANAGEMENT_TOKEN 환경 변수가 필요합니다."
  exit 1
fi

echo "CloudKit 스키마 import 중... ($SCHEMA_FILE → $ENVIRONMENT)"
"$CKTOOL" import-schema \
  --team-id "$TEAM_ID" \
  --container-id "$CONTAINER_ID" \
  --environment "$ENVIRONMENT" \
  --validate \
  --file "$SCHEMA_FILE"

echo "완료. CloudKit Console에서 Schema → Deploy to Production 으로 프로덕션 배포하세요."
