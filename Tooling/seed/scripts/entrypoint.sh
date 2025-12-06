#!/bin/bash
# Relax -u so local runs without GH Action env vars don't fail on unset inputs.
set -eo pipefail

# If invoked with an explicit subcommand (CLI passthrough), dispatch directly to the wrapper
if [[ $# -gt 0 ]]; then
  case "$1" in
    vipb2json|json2vipb|lvproj2json|json2lvproj|buildspec2json|json2buildspec)
      cmd="$1"; shift
      exec "/usr/local/bin/${cmd}" "$@"
      ;;
    *)
      echo "::error ::Unknown subcommand '$1'." >&2
      exit 1
      ;;
  esac
fi

# Read inputs provided to the action (default to help-friendly values for local use)
MODE="${INPUT_MODE:-help}"
INPUT_PATH="${INPUT_INPUT:-}"
OUTPUT_PATH="${INPUT_OUTPUT:-}"
PATCH_FILE="${INPUT_PATCH_FILE:-}"
PATCH_YAML="${INPUT_PATCH_YAML:-}"
ALWAYS_PATCH="${INPUT_ALWAYS_PATCH:-false}"
BRANCH_NAME="${INPUT_BRANCH_NAME:-}"
AUTO_PR="${INPUT_AUTO_PR:-false}"
UPLOAD_FILES="${INPUT_UPLOAD_FILES:-true}"

# SD manifest inputs (lean bundle is the default)
SD_BUNDLE_PATH="${INPUT_BUNDLE_PATH:-}"
SD_OUTPUT_DIR="${INPUT_OUTPUT_DIR:-}"
SD_TEMP_ROOT="${INPUT_TEMP_ROOT:-}"
SD_KEEP_EXTRACT="${INPUT_KEEP_EXTRACT:-false}"

# Seeding inputs
SEED_LVPROJ="${INPUT_SEED_LVPROJ:-false}"
SEED_VIPB="${INPUT_SEED_VIPB:-false}"
TAG="${INPUT_TAG:-}"

# Local help mode: just show usage for convenience when MODE is unset/help
if [[ "$MODE" == "help" || -z "$MODE" ]]; then
  echo "Seed action entrypoint (local mode):"
  echo "  Set INPUT_MODE to one of: vipb2json, json2vipb, lvproj2json, json2lvproj, buildspec2json, json2buildspec, sd-manifest"
  echo "  Set INPUT_INPUT and INPUT_OUTPUT to the desired paths (use /workspace/... in Docker)"
  echo "  For sd-manifest: set INPUT_BUNDLE_PATH (defaults to /github/workspace/builds/artifacts/sd-bundle.zip)"
  echo "  Optional: INPUT_PATCH_FILE, INPUT_PATCH_YAML, INPUT_BRANCH_NAME, INPUT_AUTO_PR, INPUT_UPLOAD_FILES"
  exit 0
fi

# If seeding is requested, handle seeding of .lvproj/.vipb templates and exit
if [[ "$SEED_LVPROJ" == "true" || "$SEED_VIPB" == "true" ]]; then
  if [[ -z "$TAG" ]]; then
    echo "::error ::Missing required 'tag' input for seeding." >&2
    exit 1
  fi
  # Configure Git identity for commit
  git config --global user.email "github-actions[bot]@users.noreply.github.com"
  git config --global user.name "github-actions[bot]"

  # Create and switch to a new branch based on the tag
  BRANCH="seed-$TAG"
  git checkout -b "$BRANCH"
  seeded=false

  # Seed .lvproj if requested and not present
  if [[ "$SEED_LVPROJ" == "true" ]]; then
    if [[ ! -f "seed.lvproj" ]]; then
      cp "tests/Samples/seed.lvproj" "seed.lvproj"
      git add "seed.lvproj"
      seeded=true
    else
      echo "seed.lvproj exists, skipping."
    fi
  fi

  # Seed .vipb if requested and not present
  if [[ "$SEED_VIPB" == "true" ]]; then
    if [[ ! -f "build/buildspec.vipb" ]]; then
      mkdir -p build
      template_vipb="Tooling/deployment/seed.vipb"
      if [[ ! -f "$template_vipb" ]]; then
        echo "::error ::VIPB template not found at $template_vipb" >&2
        exit 1
      fi
      cp "$template_vipb" "build/buildspec.vipb"
      git add "build/buildspec.vipb"
      seeded=true
    else
      echo "buildspec.vipb exists, skipping."
    fi
  fi

  # Commit and push the seeded files if any were added
  if $seeded; then
    git commit -m "Seed project files for tag $TAG"
    if git push origin "$BRANCH"; then
      echo "Branch $BRANCH pushed successfully."
    else
      echo "::error ::Failed to push branch $BRANCH. It might already exist or be protected." >&2
      exit 1
    fi
    echo "Seeded files committed to branch $BRANCH"
  else
    echo "No files seeded (already present)."
  fi
  exit 0
fi

# Validate that the input file exists before proceeding (skip for modes that don't need it)
if [[ "$MODE" != "sd-manifest" ]]; then
  if [[ -z "$INPUT_PATH" ]]; then
    echo "::error ::INPUT_INPUT not provided for mode '$MODE'." >&2
    exit 1
  fi
  if [[ ! -f "$INPUT_PATH" ]]; then
    echo "::error ::Input file '$INPUT_PATH' not found." >&2
    exit 1
  fi
fi

# Invoke the appropriate conversion based on mode
case "$MODE" in
  vipb2json)
    /usr/local/bin/vipb2json --input "$INPUT_PATH" --output "$OUTPUT_PATH"
    ;;
  json2vipb)
    /usr/local/bin/json2vipb --input "$INPUT_PATH" --output "$OUTPUT_PATH"
    ;;
  lvproj2json)
    /usr/local/bin/lvproj2json --input "$INPUT_PATH" --output "$OUTPUT_PATH"
    ;;
  json2lvproj)
    /usr/local/bin/json2lvproj --input "$INPUT_PATH" --output "$OUTPUT_PATH"
    ;;
  buildspec2json)
    /usr/local/bin/buildspec2json --input "$INPUT_PATH" --output "$OUTPUT_PATH"
    ;;
  json2buildspec)
    /usr/local/bin/json2buildspec --input "$INPUT_PATH" --output "$OUTPUT_PATH"
    ;;
  sd-manifest)
    bundle_path="$SD_BUNDLE_PATH"
    output_dir="$SD_OUTPUT_DIR"
    temp_root="$SD_TEMP_ROOT"
    keep_extract="$SD_KEEP_EXTRACT"
    if [[ -z "$bundle_path" ]]; then
      bundle_path="/github/workspace/builds/artifacts/sd-bundle-lean.zip"
    fi
    if [[ -z "$output_dir" ]]; then
      output_dir="/github/workspace/builds/reports/source-distribution-verify"
    fi
    args=("-BundlePath" "$bundle_path" "-OutputRoot" "$output_dir")
    if [[ -n "$temp_root" ]]; then
      args+=("-TempRoot" "$temp_root")
    fi
    if [[ "$keep_extract" == "true" ]]; then
      args+=("-KeepExtract")
    fi
    pwsh -NoProfile -File /usr/local/bin/Generate-SD-Manifest.ps1 "${args[@]}"
    ;;
  *)
    echo "::error ::Unsupported mode '$MODE'" >&2
    exit 1
    ;;
 esac

# Normalize vipb2json output by removing embedded VIPC payloads; avoids tests failing when
# a configuration file is present in the advanced section.
if [[ "$MODE" == "vipb2json" && -n "$OUTPUT_PATH" && -f "$OUTPUT_PATH" ]]; then
  yq eval 'del(.VI_Package_Builder_Settings.Advanced_Settings.VI_Package_Configuration_File)' -o=json -i "$OUTPUT_PATH" || { echo "::error ::Failed to strip VI_Package_Configuration_File" >&2; exit 1; }
fi

# Apply a plaintext patch file if provided
if [[ -n "$PATCH_FILE" ]]; then
  patch "$OUTPUT_PATH" "$PATCH_FILE" || { echo "::error ::Failed to apply patch file." >&2; exit 1; }
fi

# Apply a YAML patch (merge) if provided
if [[ -n "$PATCH_YAML" ]]; then
  yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' "$OUTPUT_PATH" "$PATCH_YAML" -i || { echo "::error ::Failed to apply YAML patch." >&2; exit 1; }
fi

# If a branch name is specified, commit the output file (and create PR if enabled)
if [[ -n "$BRANCH_NAME" ]]; then
  git checkout -b "$BRANCH_NAME"
  git add "$OUTPUT_PATH"
  git commit -m "Update files generated by $MODE"
  if [[ "$AUTO_PR" == "true" ]]; then
    git push origin "$BRANCH_NAME"
    gh pr create --title "Automatic update via LabVIEW CI/CD Seed" --body "This PR was auto-generated by the LabVIEW CI/CD Seed action." || { echo "::error ::Failed to create PR." >&2; exit 1; }
  else
    git push origin "$BRANCH_NAME"
  fi
fi

# Upload the output file as an artifact (if enabled)
if [[ "$UPLOAD_FILES" == "true" ]]; then
  echo "Uploading artifact: $OUTPUT_PATH"
  mkdir -p /github/workspace/ && cp "$OUTPUT_PATH" /github/workspace/
fi
