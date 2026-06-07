#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=cktool-path.sh
source "$SCRIPT_DIR/cktool-path.sh"

echo "CloudKit Management Token을 저장합니다."
echo "토큰 발급: https://icloud.developer.apple.com/dashboard"
echo "  → Settings → Management Tokens → Create Token"
echo ""

if [[ -n "${1:-}" ]]; then
  TOKEN="$1"
else
  read -r -s -p "Management Token 붙여넣기: " TOKEN
  echo ""
fi

"$CKTOOL" save-token "$TOKEN" --type management --force

echo ""
echo "저장 완료. 이제 ./sync-schema.sh 를 실행하세요."
