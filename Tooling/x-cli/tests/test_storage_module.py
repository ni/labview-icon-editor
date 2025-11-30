from datetime import datetime, UTC

from codex_rules.storage import Storage


DEFAULT_TS = datetime.now(UTC).isoformat()


def make_event(pr_id: int, *, status: str, component: str, test_id: str) -> dict:
    return {
        "run_id": f"run-{pr_id}",
        "pr_id": pr_id,
        "commit_sha": f"sha-{pr_id}",
        "test_id": test_id,
        "suite": "suite",
        "status": status,
        "duration_ms": 42,
        "component": component,
        "file_hint": "file",
        "ts": DEFAULT_TS,
    }


def test_storage_records_and_queries(tmp_path):
    db = tmp_path / "rules.sqlite"
    store = Storage(str(db))

    store.record_pr(
        pr_id=1,
        branch="feature/a",
        base="main",
        labels=["foo"],
        files=[{"path": "src/a", "status": "added", "component": "core"}]
    )
    store.record_pr(
        pr_id=2,
        branch="feature/b",
        base="main",
        labels=[],
        files=[{"path": "src/b", "status": "modified", "component": "core"}, {"path": "ignored", "component": "unknown"}]
    )
    store.record_pr(
        pr_id=3,
        branch="feature/c",
        base="main",
        labels=[],
        files=[{"path": "src/c", "status": "added", "component": "ui"}]
    )

    for event in [
        make_event(1, status="failed", component="core", test_id="suite#test"),
        make_event(2, status="passed", component="core", test_id="suite#test"),
        make_event(3, status="failed", component="ui", test_id="suite#test"),
    ]:
        store.record_test_event(**event)

    pairs = {(component, test_id) for component, test_id in store.distinct_pairs(30)}
    assert ("core", "suite#test") in pairs
    assert ("ui", "suite#test") in pairs

    assert store.get_components_for_pr(1) == ["core"]

    contingency = store.contingency("core", "suite#test", 30)
    assert contingency == (1, 1, 1, 0)

    rule = {
        "rule_id": "core-suite",
        "component": "core",
        "test_id": "suite#test",
        "support_prs": 1,
        "confidence": 0.5,
        "baseline": 0.25,
        "lift": 2.0,
        "p_value": 0.01,
        "template": "template",
        "command": "run core",
    }
    store.upsert_guidance(rule)
    store.upsert_guidance({**rule, "support_prs": 2, "lift": 1.0})

    # Add a rule with no recent failures so prune can deactivate it.
    store.upsert_guidance({**rule, "rule_id": "stale", "component": "stale", "test_id": "other"})

    active = store.get_active_guidance()
    assert {r["rule_id"] for r in active} == {"core-suite", "stale"}

    filtered = store.get_active_guidance_by_component(["core"])
    assert filtered == [{"component": "core", "test_id": "suite#test", "command": "run core"}]

    store.prune_guidance(window_days=30, last_n=10)
    assert store.get_active_guidance() == []

    stats = store.export_stats()
    assert stats == {"events_total": 3, "events_failed": 2, "guidance_active": 0}

    store.conn.close()
