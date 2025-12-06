import math
from typing import Dict, Iterable, List, Tuple

import pytest

from codex_rules import correlate


class FakeStorage:
    def __init__(self, tables: Dict[Tuple[str, str], Tuple[int, int, int, int]]):
        self._tables = tables
        self.window_days_calls: List[int] = []

    def distinct_pairs(self, window_days: int) -> Iterable[Tuple[str, str]]:
        self.window_days_calls.append(window_days)
        return list(self._tables.keys())

    def contingency(self, component: str, test_id: str, window_days: int) -> Tuple[int, int, int, int]:
        assert window_days == self.window_days_calls[-1]
        return self._tables[(component, test_id)]


def test_compute_candidates_filters_and_yields_expected():
    tables = {
        ("compA", "testA"): (4, 1, 2, 30),   # strong signal
        ("compB", "testB"): (1, 5, 1, 40),   # below min_occurrences
        ("flaky", "testF"): (5, 5, 40, 50),  # high fail rate, low lift
    }
    storage = FakeStorage(tables)
    thresholds = {
        "window_days": 21,
        "min_occurrences": 2,
        "min_confidence": 0.3,
        "min_lift": 2.0,
        "alpha": 0.05,
        "flaky_threshold": 0.2,
        "min_lift_for_flaky": 5.0,
    }

    results = correlate.compute_candidates(storage, thresholds)

    assert storage.window_days_calls == [21]
    assert len(results) == 1
    candidate = results[0]
    assert candidate["component"] == "compA"
    assert candidate["test_id"] == "testA"
    assert pytest.approx(candidate["confidence"], rel=1e-6) == 0.8
    assert pytest.approx(candidate["baseline"], rel=1e-6) == 2 / 32
    assert candidate["lift"] > 3
    assert candidate["p_value"] < thresholds["alpha"]


@pytest.mark.parametrize(
    "table, expected",
    [
        ((1, 0, 0, 1), 0.5),
        ((4, 1, 2, 30), 0.001080530492295198),
        ((3, 0, 10, 50), 0.007202034700712649),
    ],
)
def test_fisher_exact_right_tail_matches_manual_values(table, expected):
    a, b, c, d = table
    calculated = correlate.fisher_exact_right_tail(a, b, c, d)
    assert pytest.approx(calculated, rel=1e-9) == expected
    assert 0.0 <= calculated <= 1.0

