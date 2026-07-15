# Changelog

All notable dataset changes are recorded here. Released example IDs remain
stable across versions.

## 1.0.2 - 2026-07-15

- Prepared a permanent archival release with aligned GitHub, Hugging Face,
  citation, ORCID, license and checksum metadata.
- Corrected the citation metadata so the GitHub source repository and the
  Hugging Face dataset distribution have distinct canonical URLs.
- Removed the obsolete diagnostic-baseline material from the archival package.
- No dataset rows, labels, splits or data-file checksums changed in this
  release.

## 1.0.1 - 2026-07-10

- Corrected the attribution metadata: Enes Deniz is the dataset author and
  publisher; AltaySec is his professional affiliation.
- No dataset rows, labels, splits or evaluation results changed in this release.

## 1.0.0 - 2026-07-09

- Rebuilt the dataset around a precise prompt-injection label definition.
- Expanded the release from 493 to 750 unique rows.
- Replaced the original 43 broad attack rows with 150 curated attacks across ten
  balanced families.
- Added 150 matched benign hard negatives with stable `pair_id` values.
- Preserved 450 natural Turkish benign examples after line-level review.
- Added disjoint train, validation and test splits.
- Ensured every matched pair remains in a single split.
- Added source-context, attack-family and provenance fields.
- Added Parquet release artifacts for full Hugging Face viewer support while
  retaining equivalent JSONL files.
- Added a deterministic build script, validator, checksums and release stats.
- Added a full data card and annotation guide.
- Changed the dataset license from Apache-2.0 metadata to CC BY 4.0 for explicit
  dataset attribution.

## Archived seed

The pre-1.0 combined and attack files remain under `archive/seed-v0/` for
provenance. They are not part of the Hugging Face configuration.
