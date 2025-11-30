# Model and Dataset Version Control

Effective control of models and datasets keeps experiments reproducible and auditable.
This document defines mandatory requirements for managing machine-learning assets.
SRS: [FGC-REQ-DEV-007](srs/FGC-REQ-DEV-007.md)

### Definitions
- **Small metadata** — text or configuration files with an uncompressed size of ≤1 MiB (1,048,576 bytes), such as metrics JSON or YAML descriptors.
- **Large artifacts** — binary assets exceeding 100 MiB (104,857,600 bytes), such as model weights or raw datasets.
- **Intermediate assets** — files between 1 MiB and 100 MiB may reside in Git but Git LFS is recommended to prevent repository bloat.

Size measurements use mebibytes (MiB; 1 MiB = 1,048,576 bytes).

## Requirements
- **RQ1:** The repository shall track training scripts, configuration files, and metadata files ≤1 MiB directly in Git.
  - **AC1:** Each model update commit includes the relevant scripts, configuration, and sub‑ 1 MiB metadata.
- **RQ2:** The repository shall store artifacts exceeding 100 MiB, such as model weights or raw datasets, in Git LFS or an external registry, committing only pointers or checksums.
  - **AC2:** Each artifact exceeding 100 MiB uses a pointer or checksum instead of embedding the artifact in Git.
- **RQ3:** Commit messages shall summarize the training run, dataset revision,
  and key hyperparameters such as learning rate and batch size.
  - **AC3:** Commit history shows these details for every training run.
- **RQ4:** After a training run is validated, an annotated Git tag shall
  capture the model version.
  - **AC4:** Tag names follow the pattern `model-v<major.minor>` and point to
    immutable commits.
- **RQ5:** Performance metrics shall be recorded in a repository file such as
  `models/<model>/metrics.md`.
  - **AC5:** Metrics files list accuracy, loss, dataset identifier, and
    evaluation date.
- **RQ6:** Release notes or commit messages shall reference the corresponding
  metrics file for traceability.
  - **AC6:** Each tag or release references the metrics file.

## Quality Attributes
- **Performance** — metrics files quantify accuracy and loss so releases can be compared objectively.
- **Reliability** — verified tags and recorded checksums allow any published model to be reconstructed.
- **Maintainability** — standardized commit summaries and structured metrics files keep model history understandable.

## Example: Baseline Model Versioning
1. Train a baseline model and commit `train.py`, `config.yaml`, and `models/baseline/metrics.md`.
2. Store the weights `baseline.pt` in Git LFS, commit its pointer, and verify with `git lfs ls-files baseline.pt`. Record the dataset snapshot in an external registry and commit `data/dataset-v5.sha256` containing its checksum.
3. Track a 50 MiB tokenizer model with Git LFS:

   ```bash
   git lfs track tokenizer.model
   git add tokenizer.model .gitattributes
   git commit -m "Track tokenizer via LFS"
   ```
4. Tag the validated commit:

   ```bash
   git tag -a model-v1.0 -m "Baseline model v1.0"
   git push origin model-v1.0
   ```
5. Reference `models/baseline/metrics.md` in release notes.

## Validating Compliance
- Run `git ls-files` to confirm scripts, configs, and metadata files ≤1 MiB are tracked (AC1).
  Example:
  ```
  train.py
  config.yaml
  ```
- Run `git lfs ls-files` to ensure artifacts over 100 MiB use pointers (AC2).
  Example:
  ```
  3fb2c1f... baseline.pt (LFS: 123456789abcdef)
  ```
- Inspect `git log --oneline` to verify commit messages record runs (AC3).
  Example:
  ```
  a1b2c3d Model v1: dataset v5, lr=0.01, bs=32
  ```
- Use `git tag -l "model-v*"` to confirm immutable tags (AC4).
  Example:
  ```
  model-v1.0
  model-v1.1
  ```
- Review `models/<model>/metrics.md` for required fields (AC5).
  Example excerpt:
  ```
  Accuracy: 0.95
  Loss: 0.12
  Dataset: dataset-v5
  ```
## Common Pitfalls
- Committing artifacts over 100 MiB directly to Git instead of LFS or a registry (violates RQ2).
- Omitting dataset identifiers in metrics files (violates RQ5).
- Using mutable tags that point to different commits (violates RQ4).
- Neglecting to update metrics after retraining.
