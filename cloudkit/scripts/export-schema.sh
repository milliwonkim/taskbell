#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=cktool-path.sh
source "$SCRIPT_DIR/cktool-path.sh"

ENVIRONMENT="${1:-development}"
OUTPUT_FILE="${2:-$SCRIPT_DIR/../schema/exported.ckdb}"

if [[ -z "${CLOUDKIT_MANAGEMENT_TOKEN:-}" ]]; then
  echo "오류: CLOUDKIT_MANAGEMENT_TOKEN 환경 변수가 필요합니다."
  echo ""
  echo "토큰 발급:"
  echo "  1. https://icloud.developer.apple.com/dashboard 접속"
  echo "  2. Settings → Management Tokens → Create Token"
  echo "  3. export CLOUDKIT_MANAGEMENT_TOKEN='<토큰>'"
  echo ""
  echo "또는 키체인에 저장:"
  echo "  $CKTOOL save-token --token '<토큰>'"
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"

echo "CloudKit 스키마 export 중... ($ENVIRONMENT → $OUTPUT_FILE)"
"$CKTOOL" export-schema \
  --team-id "$TEAM_ID" \
  --container-id "$CONTAINER_ID" \
  --environment "$ENVIRONMENT" \
  --output-file "$OUTPUT_FILE"

echo "완료: $OUTPUT_FILE"
