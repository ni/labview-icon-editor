# Technical debt markers

Stage 1 runs `scripts/check-tech-debt.sh` to ensure no unresolved technical debt
markers remain in the repository.

Markers are comments containing `TECH-DEBT:` followed by a description, for
example:

```text
# TECH-DEBT: manifest enforcement
```

If the check reports any lines, address the underlying issue and remove the
marker. Once all markers are resolved, rerun Stage 1.
