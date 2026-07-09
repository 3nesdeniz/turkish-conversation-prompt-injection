#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v duckdb >/dev/null 2>&1; then
  echo "duckdb is required. Install it with: brew install duckdb" >&2
  exit 1
fi

for split in train validation test; do
  input="data/${split}.jsonl"
  output="data/${split}.parquet"
  rm -f "$output"

  duckdb -c "COPY (
    SELECT *
    FROM read_json_auto('${input}', format = 'newline_delimited')
  ) TO '${output}' (FORMAT PARQUET, COMPRESSION ZSTD);"
done

expected_train=530
expected_validation=100
expected_test=120

for split in train validation test; do
  expected_var="expected_${split}"
  expected="${!expected_var}"
  actual="$(duckdb -csv -noheader -c "SELECT count(*) FROM read_parquet('data/${split}.parquet');")"
  if [[ "$actual" != "$expected" ]]; then
    echo "${split}.parquet: expected ${expected} rows, found ${actual}" >&2
    exit 1
  fi
  echo "${split}.parquet: ${actual} rows"
done

{
  for split in train validation test; do
    shasum -a 256 "data/${split}.jsonl"
  done
  for split in train validation test; do
    shasum -a 256 "data/${split}.parquet"
  done
} > metadata/checksums.sha256

echo "Parquet release artifacts built and checksummed."
