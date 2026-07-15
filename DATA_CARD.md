# Data Card

## Dataset identity

- **Name:** Turkish Conversation Prompt-Injection Dataset
- **Version:** 1.0.2
- **Language:** Turkish (`tr`)
- **Modality:** Text
- **Task:** Binary text classification with attack-family metadata
- **Author:** Enes Deniz
- **Publisher:** Enes Deniz
- **Affiliation:** AltaySec
- **ORCID:** [`0009-0006-9491-3565`](https://orcid.org/0009-0006-9491-3565)
- **License:** CC BY 4.0

## Motivation

Turkish prompt-injection work needs more than translated attack templates. A
useful detector must also see ordinary Turkish, legitimate technical requests
and examples that use security terminology without attempting to cross a trust
boundary.

This dataset therefore combines three complementary surfaces:

1. ordinary conversational Turkish;
2. legitimate technical and security-sensitive requests;
3. direct, indirect and agent-oriented prompt-injection attempts.

The paired boundary set is the central design choice. Each attack is matched to
a benign request with a similar subject and vocabulary. This reduces the value
of shallow keyword shortcuts and makes false-positive behavior visible.

## Who created the data

The text is synthetic and was produced for this dataset. It was not collected
from AltaySec customers, production systems, social media, support tickets or
private conversations.

The v1 curation process was managed and published by Enes Deniz as part of his
work at AltaySec. AltaySec is listed as his affiliation, not as the dataset
publisher. The release does not claim independent annotators or a measured
inter-annotator agreement score.

## Dataset composition

The release contains 750 rows:

- 410 `benign_daily`
- 40 `benign_technical`
- 150 `benign_boundary`
- 150 `prompt_injection`

There are ten attack families with 15 examples per family. The 150 boundary
examples are linked one-to-one to the attacks through `pair_id`.

## Unit of data

Each row represents one input surface visible to an LLM application. Most rows
are direct user messages. Indirect rows represent text encountered in a web
page, document, email, retrieved knowledge entry, tool output or similar
untrusted source.

The row does not contain a model response. The task is to classify the input,
not to score response safety or attack success.

## Label semantics

### Label 0: benign

The input may be ordinary conversation, technical support, a security question,
a translation request or a request to review suspicious text. It does not ask
the model or agent to violate the assumed trust boundary.

### Label 1: prompt injection / LLM-security attack

The input attempts to override trusted instructions, expose protected context,
bypass verification, trigger an unauthorized tool action, persist unsafe
behavior or make external content act as a higher-priority instruction.

The attack label is contextual. For example, the sentence "send this email" is
not inherently malicious. It becomes an attack when untrusted content instructs
an agent to send private data without user approval.

## Pair construction

Pairs were written to keep the topic close while changing the intent or trust
relationship. A valid pair must satisfy all of the following:

- one benign and one attack row;
- the same `pair_id`;
- the same `source_context`;
- enough shared topic or vocabulary to make keyword-only classification weak;
- a clear reason why one row crosses a boundary and the other does not;
- both rows assigned to the same split.

Pairs are not paraphrases. They are controlled contrasts.

## Split policy

The release uses 530 train, 100 validation and 120 test rows. Base benign rows
are deterministically shuffled. Pairs are grouped by attack family, then split
as units so paired examples cannot leak across train and evaluation sets.

For every attack family:

- 10 pairs are in train;
- 2 pairs are in validation;
- 3 pairs are in test.

## Preprocessing

No lowercasing, ASCII folding, punctuation stripping, typo correction or
translation was applied to the published `text` field. Natural capitalization,
Turkish characters, colloquial spelling, code-switching and deliberate
obfuscation are retained.

Consumers should decide whether normalization belongs in their own detection
pipeline. Normalizing before the split or across paired rows may create leakage.

## Personal and sensitive data

The dataset contains no intentionally real personal data or functioning secret.
Security-sensitive strings are described conceptually or represented with
placeholders. The validator checks for common real-looking e-mail, Turkish IBAN,
telephone and long numeric patterns.

That automated check is a safety net, not a legal guarantee.

## Recommended evaluation

Report at minimum:

- precision, recall and F1 for label 1;
- macro F1;
- balanced accuracy;
- false-positive rate on all benign examples;
- false-positive rate on `benign_boundary` separately;
- recall by `attack_family`;
- recall by `source_context` for indirect and agentic cases.

Do not report raw accuracy alone. A model can benefit from the 4:1 benign-to-
attack ratio without learning the intended boundary.

## Known risks and limitations

1. **Synthetic style:** recurring sentence structures may remain despite
   curation.
2. **Dataset size:** 150 attacks are enough for a compact open set, not for
   exhaustive coverage.
3. **Context compression:** indirect attacks are represented as text snippets
   rather than complete files or multimodal artifacts.
4. **No attack-success measurement:** label 1 means attempted injection, not a
   verified bypass against a named model.
5. **No real prevalence claim:** the 4:1 class ratio is a dataset design choice.
6. **Turkish-first scope:** English phrases appear only inside Turkish
   code-switching examples.
7. **No independent annotation study:** the current release has no external
   adjudication or agreement statistic.

## Maintenance

Future versions should add independently reviewed real-world-style examples,
more indirect delivery formats, dialect variation and model-independent attack
mutations. Existing IDs must remain stable. Corrections should be recorded in
`CHANGELOG.md` rather than silently rewriting released examples.

## Reproducibility

- Authoring sources: `source/`
- Deterministic builder: `scripts/build_dataset.rb`
- Parquet release builder: `scripts/build_parquet.sh`
- Validator: `scripts/validate_dataset.rb`
- Counts: `metadata/stats.json`
- Checksums: `metadata/checksums.sha256`
