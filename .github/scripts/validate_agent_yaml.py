#!/usr/bin/env python3
"""
Validate the repository-root agent.yaml against required keys and basic shapes.
Exits non-zero with a helpful message on validation failure.
"""

from __future__ import annotations

import argparse
import datetime
import sys
import re
from pathlib import Path

import yaml


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    sys.exit(1)


def expect_dict(obj, path: str) -> dict:
    if not isinstance(obj, dict):
        fail(f"{path} must be a mapping")
    return obj


def expect_list(obj, path: str) -> list:
    if not isinstance(obj, list):
        fail(f"{path} must be a list")
    return obj


def expect_str(obj, path: str) -> str:
    if isinstance(obj, (datetime.date, datetime.datetime)):
        return obj.isoformat()
    if not isinstance(obj, str) or not obj.strip():
        fail(f"{path} must be a non-empty string")
    return obj


def expect_bool(obj, path: str) -> bool:
    if not isinstance(obj, bool):
        fail(f"{path} must be a boolean")
    return obj


def expect_number(obj, path: str) -> float:
    if not isinstance(obj, (int, float)):
        fail(f"{path} must be a number")
    return float(obj)


def require_keys(mapping: dict, keys: list[str], path: str) -> None:
    for key in keys:
        if key not in mapping:
            fail(f"Missing required key: {path}.{key}")


def validate_metadata(data: dict) -> None:
    metadata = expect_dict(data.get("metadata"), "metadata")
    require_keys(metadata, ["name", "version", "owners"], "metadata")
    expect_str(metadata["name"], "metadata.name")
    expect_str(metadata["version"], "metadata.version")
    owners = expect_list(metadata["owners"], "metadata.owners")
    if not owners:
        fail("metadata.owners must not be empty")
    for idx, owner in enumerate(owners):
        expect_str(owner, f"metadata.owners[{idx}]")


def validate_description(data: dict) -> None:
    expect_str(data.get("description"), "description")


def validate_goals(data: dict) -> None:
    goals = expect_list(data.get("goals"), "goals")
    if not goals:
        fail("goals must not be empty")
    for idx, goal in enumerate(goals):
        expect_str(goal, f"goals[{idx}]")


def validate_model(data: dict) -> None:
    model = expect_dict(data.get("model"), "model")
    require_keys(model, ["provider", "name", "temperature", "max_tokens"], "model")
    expect_str(model["provider"], "model.provider")
    expect_str(model["name"], "model.name")
    expect_number(model["temperature"], "model.temperature")
    expect_number(model["max_tokens"], "model.max_tokens")


def validate_capabilities(data: dict) -> None:
    capabilities = expect_list(data.get("capabilities"), "capabilities")
    if not capabilities:
        fail("capabilities must not be empty")
    for idx, entry in enumerate(capabilities):
        entry_path = f"capabilities[{idx}]"
        mapping = expect_dict(entry, entry_path)
        require_keys(mapping, ["id", "enabled"], entry_path)
        expect_str(mapping["id"], f"{entry_path}.id")
        expect_bool(mapping["enabled"], f"{entry_path}.enabled")
        if "limits" in mapping:
            limits = expect_dict(mapping["limits"], f"{entry_path}.limits")
            for key in ["max_changed_lines", "max_files"]:
                if key in limits:
                    expect_number(limits[key], f"{entry_path}.limits.{key}")


def validate_tools(data: dict) -> None:
    tools = expect_list(data.get("tools"), "tools")
    if not tools:
        fail("tools must not be empty")
    for idx, entry in enumerate(tools):
        entry_path = f"tools[{idx}]"
        mapping = expect_dict(entry, entry_path)
        require_keys(mapping, ["id"], entry_path)
        expect_str(mapping["id"], f"{entry_path}.id")
        for list_key in ["allow", "deny"]:
            if list_key in mapping:
                allow_list = expect_list(mapping[list_key], f"{entry_path}.{list_key}")
                for tool_idx, item in enumerate(allow_list):
                    expect_str(item, f"{entry_path}.{list_key}[{tool_idx}]")


def validate_safety(data: dict) -> None:
    safety = expect_dict(data.get("safety"), "safety")
    require_keys(
        safety,
        ["external_network_policy", "pii_redaction", "approval_required_for", "io_limits", "observability", "audit_trail"],
        "safety",
    )
    expect_str(safety["external_network_policy"], "safety.external_network_policy")
    expect_bool(safety["pii_redaction"], "safety.pii_redaction")

    approval_required_for = expect_list(safety["approval_required_for"], "safety.approval_required_for")
    if not approval_required_for:
        fail("safety.approval_required_for must not be empty")
    for idx, item in enumerate(approval_required_for):
        expect_str(item, f"safety.approval_required_for[{idx}]")

    io_limits = expect_dict(safety["io_limits"], "safety.io_limits")
    for key in ["max_changed_lines_auto_apply", "max_comment_length", "max_files_touched"]:
        require_keys(io_limits, [key], "safety.io_limits")
        expect_number(io_limits[key], f"safety.io_limits.{key}")

    observability = expect_dict(safety["observability"], "safety.observability")
    for key in ["structured_logging", "redact_secrets"]:
        require_keys(observability, [key], "safety.observability")
        expect_bool(observability[key], f"safety.observability.{key}")

    audit_trail = expect_dict(safety["audit_trail"], "safety.audit_trail")
    for key in ["persist_actions", "retention_days"]:
        require_keys(audit_trail, [key], "safety.audit_trail")
        if key == "retention_days":
            expect_number(audit_trail[key], "safety.audit_trail.retention_days")
        else:
            expect_bool(audit_trail[key], "safety.audit_trail.persist_actions")


def validate_revision(data: dict) -> None:
    revision = expect_dict(data.get("revision"), "revision")
    require_keys(revision, ["last_modified", "authors"], "revision")
    last_modified = expect_str(revision["last_modified"], "revision.last_modified")
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", last_modified):
        fail("revision.last_modified must be an ISO-8601 date (YYYY-MM-DD)")
    authors = expect_list(revision["authors"], "revision.authors")
    if not authors:
        fail("revision.authors must not be empty")
    for idx, author in enumerate(authors):
        expect_str(author, f"revision.authors[{idx}]")


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate agent.yaml required keys and shapes.")
    parser.add_argument("path", nargs="?", default="agent.yaml", help="Path to agent.yaml")
    args = parser.parse_args()

    yaml_path = Path(args.path)
    if not yaml_path.is_file():
        fail(f"agent.yaml not found at {yaml_path}")

    try:
        payload = yaml.safe_load(yaml_path.read_text()) or {}
    except yaml.YAMLError as exc:
        fail(f"agent.yaml is not valid YAML: {exc}")

    data = expect_dict(payload, "root")
    validate_metadata(data)
    validate_description(data)
    validate_goals(data)
    validate_model(data)
    validate_capabilities(data)
    validate_tools(data)
    validate_safety(data)
    validate_revision(data)

    print("agent.yaml validation: OK")


if __name__ == "__main__":
    main()
