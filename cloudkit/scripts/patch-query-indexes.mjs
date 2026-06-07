#!/usr/bin/env node
/**
 * SwiftData가 생성한 exported.ckdb에 CloudKit JS 쿼리용 인덱스를 추가합니다.
 *
 * 사용법:
 *   node patch-query-indexes.mjs ../schema/exported.ckdb > ../schema/query-indexes.ckdb
 */

import { readFileSync, writeFileSync } from "node:fs";

const inputPath = process.argv[2];
if (!inputPath) {
  console.error("사용법: node patch-query-indexes.mjs <exported.ckdb> [output.ckdb]");
  process.exit(1);
}

const outputPath = process.argv[3];
const schema = readFileSync(inputPath, "utf8");

const CD_RECORD_TYPES = [
  "CD_TodoItem",
  "CD_AnniversaryItem",
  "CD_Reminder",
  "CD_TodoAttachment",
];

/** 필드 타입 뒤에 QUERYABLE / SORTABLE 플래그를 추가 */
const INDEX_RULES = [
  // recordName 쿼리 필수 (스키마: ___recordID, 콘솔: recordName)
  { pattern: /("___recordID"\s+REFERENCE)(?!\s+QUERYABLE)/g, replacement: "$1 QUERYABLE" },
  { pattern: /("___recordName"\s+STRING)(?!\s+QUERYABLE)/g, replacement: "$1 QUERYABLE" },
  { pattern: /(recordName\s+STRING)(?!\s+QUERYABLE)/g, replacement: "$1 QUERYABLE" },

  // TodoItem
  { pattern: /(CD_createdAt\s+TIMESTAMP)(?!\s+(QUERYABLE|SORTABLE))/g, replacement: "$1 QUERYABLE SORTABLE" },
  { pattern: /(CD_title\s+STRING)(?!\s+QUERYABLE)/g, replacement: "$1 QUERYABLE" },
  { pattern: /(CD_isCompleted\s+INT64)(?!\s+QUERYABLE)/g, replacement: "$1 QUERYABLE" },
  { pattern: /(CD_timelineSortOrder\s+DOUBLE)(?!\s+SORTABLE)/g, replacement: "$1 SORTABLE" },

  // AnniversaryItem
  { pattern: /(CD_targetDate\s+TIMESTAMP)(?!\s+(QUERYABLE|SORTABLE))/g, replacement: "$1 QUERYABLE SORTABLE" },

  // Reminder
  { pattern: /(CD_fireDate\s+TIMESTAMP)(?!\s+(QUERYABLE|SORTABLE))/g, replacement: "$1 QUERYABLE SORTABLE" },
  { pattern: /(CD_isEnabled\s+INT64)(?!\s+QUERYABLE)/g, replacement: "$1 QUERYABLE" },
];

let patched = schema;
for (const { pattern, replacement } of INDEX_RULES) {
  patched = patched.replace(pattern, replacement);
}

// exported.ckdb에 ___recordID가 없는 레코드 타입에 시스템 필드 보강
for (const recordType of CD_RECORD_TYPES) {
  const blockPattern = new RegExp(
    `(RECORD TYPE ${recordType}\\s*\\([^)]*)(?!"___recordID")`,
    "s",
  );
  patched = patched.replace(
    blockPattern,
    '$1\n        "___recordID"   REFERENCE QUERYABLE,',
  );
}

if (outputPath) {
  writeFileSync(outputPath, patched, "utf8");
  console.error(`패치 완료: ${outputPath}`);
} else {
  process.stdout.write(patched);
}
