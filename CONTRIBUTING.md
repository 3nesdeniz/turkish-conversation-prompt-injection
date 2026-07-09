# Contributing

Contributions should improve coverage without weakening label precision or
introducing private data.

## Before proposing an example

1. Read `ANNOTATION_GUIDE.md`.
2. Do not use customer logs, private conversations or real credentials.
3. Do not submit an attack without a matched benign boundary example.
4. Use the most specific existing attack family.
5. Keep the attack and benign example in the same `source_context`.
6. Explain why the attack crosses a trust boundary and the benign example does
   not.

## Authoring format

Add proposed pairs to `source/paired_cases.jsonl` using this structure:

```json
{
  "pair_id": "pair_XXXX",
  "family": "direct_instruction_override",
  "source_context": "direct_user",
  "benign": "...",
  "attack": "..."
}
```

Do not edit generated split files by hand. Run:

```bash
ruby scripts/build_dataset.rb
bash scripts/build_parquet.sh
ruby scripts/validate_dataset.rb
ruby scripts/baseline_nb.rb
```

## Review requirements

A contribution is ready only when:

- JSON is valid;
- no normalized duplicate exists;
- the benign side is not merely the attack with all security words removed;
- no real-looking personal or secret value appears;
- split and pair-integrity checks pass;
- documentation and changelog are updated when the schema or taxonomy changes.

Contributed text is accepted under the repository's CC BY 4.0 license.
