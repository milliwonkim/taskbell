#!/usr/bin/env bash
# SwiftData 스키마를 CloudKit JS에서 쿼리 가능하도록 업데이트하는 전체 워크플로우
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_DIR="$SCRIPT_DIR/../schema"

SKIP_APP_PROMPT="${SKIP_APP_PROMPT:-}"

echo "=== TaskBell CloudKit 스키마 동기화 ==="
echo ""

if [[ -z "${CLOUDKIT_MANAGEMENT_TOKEN:-}" ]]; then
  echo "오류: CLOUDKIT_MANAGEMENT_TOKEN이 설정되지 않았습니다."
  echo ""
  echo "CloudKit Console → Settings → Management Tokens 에서 토큰을 발급한 뒤:"
  echo "  export CLOUDKIT_MANAGEMENT_TOKEN='<토큰>'"
  echo "  ./sync-schema.sh"
  exit 1
fi

if [[ -z "$SKIP_APP_PROMPT" ]]; then
  echo "1단계: iOS 앱을 실행해 SwiftData가 최신 스키마를 Development에 푸시합니다."
  echo "   - Xcode에서 TaskBell.xcworkspace 열기 → Run (iCloud 로그인 필요)"
  echo ""
  read -r -p "앱을 실행했으면 Enter를 누르세요..."
else
  echo "1단계: SKIP_APP_PROMPT=1 — 앱 실행 확인을 건너뜁니다."
fi

echo ""
echo "2단계: Development 스키마 export..."
"$SCRIPT_DIR/export-schema.sh" development "$SCHEMA_DIR/exported.ckdb"

echo ""
echo "3단계: CloudKit JS 쿼리용 인덱스 패치..."
node "$SCRIPT_DIR/patch-query-indexes.mjs" \
  "$SCHEMA_DIR/exported.ckdb" \
  "$SCHEMA_DIR/query-indexes.ckdb"

echo ""
echo "4단계: 패치된 스키마 import..."
"$SCRIPT_DIR/import-schema.sh" "$SCHEMA_DIR/query-indexes.ckdb" development

echo ""
echo "=== 완료 ==="
echo "CloudKit Console → Schema → Deploy Schema Changes to Production"
echo "으로 프로덕션 배포 후 cloudkit-js의 APPLE_CK_ENVIRONMENT=production 으로 전환하세요."
