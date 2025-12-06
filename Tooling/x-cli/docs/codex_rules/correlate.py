"""Association analysis between components and test failures.

This module computes candidate guidance rules by building contingency tables
for each (component, test) pair and evaluating statistical metrics such as
confidence, baseline, lift and Fisher’s exact p‑value.  Thresholds defined in
the configuration filter out weak or flaky associations.
"""
from __future__ import annotations

import math
from typing import Dict, Iterable, List

from .storage import StorageProtocol


def compute_candidates(storage: StorageProtocol, thresh: Dict) -> List[Dict]:
    """Return a list of candidate guidance rules that meet the thresholds.

    Each candidate is a dictionary with keys:
      - component
      - test_id
      - support_prs
      - confidence
      - baseline
      - lift
      - p_value
    """
    window_days = thresh.get("window_days", 30)
    min_occ = thresh.get("min_occurrences", 3)
    min_conf = thresh.get("min_confidence", 0.25)
    min_lift = thresh.get("min_lift", 3.0)
    alpha = thresh.get("alpha", 0.01)
    flaky_threshold = thresh.get("flaky_threshold", 0.04)
    min_lift_flaky = thresh.get("min_lift_for_flaky", 3.0)

    results: List[Dict] = []
    for component, test_id in storage.distinct_pairs(window_days):
        A, B, C, D = storage.contingency(component, test_id, window_days)
        total_prs = A + B + C + D
        if total_prs == 0:
            continue
        support = A  # count of PRs with both component touched and test failed
        if support < min_occ:
            continue
        confidence = A / max(A + B, 1)
        baseline = C / max(C + D, 1)
        if confidence < min_conf:
            continue
        # Avoid division by zero
        lift = confidence / max(baseline, 1e-6)
        # Flaky filter: if test fails often regardless of component, require higher lift
        global_fail_rate = (A + C) / max(total_prs, 1)
        if global_fail_rate > flaky_threshold and lift < min_lift_flaky:
            continue
        if lift < min_lift:
            continue
        p_value = fisher_exact_right_tail(A, B, C, D)
        if p_value > alpha:
            continue
        results.append(
            {
                "component": component,
                "test_id": test_id,
                "support_prs": support,
                "confidence": confidence,
                "baseline": baseline,
                "lift": lift,
                "p_value": p_value,
            }
        )
    return results


def fisher_exact_right_tail(a: int, b: int, c: int, d: int) -> float:
    """Compute the one‑sided Fisher exact test p‑value for a 2x2 table.

    The table is:
        | a  b |
        | c  d |
    This returns the right‑tail probability P(X ≥ a) given fixed marginals.
    """
    # Compute marginal totals
    row1 = a + b
    row2 = c + d
    col1 = a + c
    col2 = b + d
    n = row1 + row2

    def hypergeom(x: int) -> float:
        return (
            math.comb(row1, x)
            * math.comb(row2, col1 - x)
            / math.comb(n, col1)
        )

    # Enumerate all possible values ≥ a that satisfy the marginals
    min_x = max(0, col1 - row2)
    max_x = min(row1, col1)
    p = 0.0
    for x in range(a, max_x + 1):
        p += hypergeom(x)
    return min(1.0, p)
