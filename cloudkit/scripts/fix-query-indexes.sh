#!/usr/bin/env bash
# CloudKit "Field 'recordName' is not marked queryable" 오류 수정
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=cktool-path.sh
source "$SCRIPT_DIR/cktool-path.sh"

INDEXES_URL="https://icloud.developer.apple.com/dashboard/teams/${TEAM_ID}/containers/${CONTAINER_ID}/schema/indexes"

RECORD_TYPES=(
  "CD_TodoItem"
  "CD_AnniversaryItem"
  "CD_Reminder"
  "CD_TodoAttachment"
)

SORT_FIELDS=(
  "CD_TodoItem:CD_createdAt"
  "CD_AnniversaryItem:CD_targetDate"
  "CD_Reminder:CD_fireDate"
  "CD_TodoAttachment:CD_createdAt"
)

echo "=== recordName QUERYABLE 인덱스 추가 ==="
echo ""
echo "CloudKit Console Indexes 페이지를 엽니다..."
open "$INDEXES_URL" 2>/dev/null || true
echo ""
echo "각 Record Type마다 아래 인덱스를 추가하세요."
echo "(드롭다운에 recordName이 없으면 recordID / ___recordID 를 선택하세요)"
echo ""

for record_type in "${RECORD_TYPES[@]}"; do
  echo "▸ $record_type"
  echo "  1) + Add Index"
  echo "  2) Record Type: $record_type"
  echo "  3) Field: recordName (또는 recordID)"
  echo "  4) Type: QUERYABLE"
  echo "  5) Save Changes"
  echo ""
done

echo "--- 정렬(sortBy) 오류 방지용 SORTABLE 인덱스 ---"
echo ""
for entry in "${SORT_FIELDS[@]}"; do
  record_type="${entry%%:*}"
  field="${entry##*:}"
  echo "▸ $record_type → $field"
  echo "  Field: $field / Type: SORTABLE"
  echo ""
done

echo "Development 환경에서 저장 후, CloudKit JS 쿼리를 다시 시도하세요."
echo "TestFlight/App Store 데이터는 Schema → Deploy to Production 후 production에서도 동일하게 설정해야 합니다."
echo ""

if [[ -n "${CLOUDKIT_MANAGEMENT_TOKEN:-}" ]] && [[ -f "$SCRIPT_DIR/../schema/exported.ckdb" ]]; then
  echo "export된 스키마가 있어 자동 패치를 시도합니다..."
  node "$SCRIPT_DIR/patch-query-indexes.mjs" \
    "$SCRIPT_DIR/../schema/exported.ckdb" \
    "$SCRIPT_DIR/../schema/query-indexes.ckdb"
  "$SCRIPT_DIR/import-schema.sh" "$SCRIPT_DIR/../schema/query-indexes.ckdb" development
  echo "자동 import 완료."
elif [[ -n "${CLOUDKIT_MANAGEMENT_TOKEN:-}" ]]; then
  echo "자동 적용을 원하면:"
  echo "  ./export-schema.sh development"
  echo "  node patch-query-indexes.mjs ../schema/exported.ckdb ../schema/query-indexes.ckdb"
  echo "  ./import-schema.sh ../schema/query-indexes.ckdb development"
fi
