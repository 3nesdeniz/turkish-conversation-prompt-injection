# Diagnostic Baseline

This is a deliberately simple, dependency-free reference baseline. It is not a
claim about production performance and should not be used to rank security
products.

## Method

- Multinomial Naive Bayes
- lowercased Turkish word unigrams and bigrams
- binary feature presence per document
- Laplace smoothing with `alpha = 1.0`
- trained only on `data/train.jsonl`
- no hyperparameter search

Run it with:

```bash
ruby scripts/baseline_nb.rb
```

## Version 1.0.0 results

| Split | Precision | Recall | F1 | Balanced accuracy |
|---|---:|---:|---:|---:|
| Validation | 0.351 | 1.000 | 0.519 | 0.769 |
| Test | 0.405 | 1.000 | 0.577 | 0.756 |

Test confusion matrix:

- TP: 30
- FP: 44
- TN: 46
- FN: 0

The baseline finds all 30 test attacks but over-classifies benign inputs. It
misclassifies 26 of the 30 `benign_boundary` rows. That failure is useful: the
paired hard negatives prevent a basic bag-of-words model from succeeding merely
because a sentence contains words such as `system`, `API`, `admin`, `log` or
`password`.

These values are a reproducibility check, not a target. A stronger experiment
should report confidence intervals, per-family recall and the false-positive
rate on `benign_boundary` separately.
