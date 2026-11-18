#!/usr/bin/env bash
set -e

# ==============================================================================
# ShortsSplitter Documentation Integrity & Link Verifier
# ==============================================================================

ERRORS=0
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "=================================================="
echo "📚 ShortsSplitter: Documentation Integrity Check"
echo "=================================================="
echo ""

# 1. Required Documents Check
REQUIRED_DOCS=(
  "docs/README.md"
  "README.md"
  "docs/SETUP.md"
  "docs/COMMANDS.md"
  "docs/ARCHITECTURE.md"
  "docs/FEATURES.md"
  "docs/UI_GUIDE.md"
  "docs/STORAGE_AND_PERMISSIONS.md"
  "docs/ANDROID_COMPAT.md"
  "docs/FFMPEG.md"
  "docs/BUILD_AND_RELEASE.md"
  "docs/TESTING.md"
  "docs/TEST_CASES.md"
  "docs/TROUBLESHOOTING.md"
  "docs/AGENT_SETUP.md"
  "docs/CONTRIBUTING.md"
  "docs/DECISIONS.md"
  "docs/PRIVACY.md"
  "CHANGELOG.md"
)

echo "1. Checking required documentation files exist..."
for doc in "${REQUIRED_DOCS[@]}"; do
  if [ ! -f "$doc" ]; then
    echo "  ❌ Missing required document: $doc"
    ERRORS=$((ERRORS + 1))
  else
    echo "  ✅ Found: $doc"
  fi
done

# 2. Check for Placeholder Words (TODO, TBD, lorem)
echo ""
echo "2. Scanning for forbidden placeholder text (TODO, TBD, lorem)..."
ALL_DOC_FILES=("${REQUIRED_DOCS[@]}")
for doc in "${ALL_DOC_FILES[@]}"; do
  if [ -f "$doc" ]; then
    # Case-insensitive grep for placeholders; ignore commented explanations if any
    MATCHES=$(grep -Eni "(\bTODO\b|\bTBD\b|\blorem\b)" "$doc" || true)
    if [ -n "$MATCHES" ]; then
      echo "  ❌ Forbidden placeholder text in $doc:"
      echo "$MATCHES" | while read -r line; do
        echo "     $line"
      done
      ERRORS=$((ERRORS + 1))
    fi
  fi
done
if [ $ERRORS -eq 0 ]; then
  echo "  ✅ Zero forbidden placeholders found across all documentation."
fi

# 3. Check every scripts/* file is mentioned in docs/COMMANDS.md
echo ""
echo "3. Verifying all scripts are documented in docs/COMMANDS.md..."
if [ -f "docs/COMMANDS.md" ]; then
  for script_file in scripts/*; do
    script_name=$(basename "$script_file")
    if ! grep -q "$script_name" "docs/COMMANDS.md"; then
      echo "  ❌ Script '$script_name' is not documented in docs/COMMANDS.md"
      ERRORS=$((ERRORS + 1))
    else
      echo "  ✅ Script documented: $script_name"
    fi
  done
else
  echo "  ❌ Cannot check scripts: docs/COMMANDS.md does not exist."
  ERRORS=$((ERRORS + 1))
fi

# 4. Check every .agents/workflows/* is mentioned in docs/COMMANDS.md and docs/AGENT_SETUP.md
echo ""
echo "4. Verifying all agent workflows are documented..."
if [ -d ".agents/workflows" ]; then
  for wf_file in .agents/workflows/*.md; do
    wf_name=$(basename "$wf_file")
    wf_base="${wf_name%.md}"

    if [ -f "docs/COMMANDS.md" ]; then
      if ! grep -q "$wf_base" "docs/COMMANDS.md" && ! grep -q "$wf_name" "docs/COMMANDS.md"; then
        echo "  ❌ Workflow '$wf_name' is not mentioned in docs/COMMANDS.md"
        ERRORS=$((ERRORS + 1))
      fi
    fi

    if [ -f "docs/AGENT_SETUP.md" ]; then
      if ! grep -q "$wf_base" "docs/AGENT_SETUP.md" && ! grep -q "$wf_name" "docs/AGENT_SETUP.md"; then
        echo "  ❌ Workflow '$wf_name' is not mentioned in docs/AGENT_SETUP.md"
        ERRORS=$((ERRORS + 1))
      fi
    fi
  done
  echo "  ✅ Agent workflows verification completed."
fi

# 5. Check relative markdown links resolve
echo ""
echo "5. Verifying relative markdown links..."
for doc in "${ALL_DOC_FILES[@]}"; do
  if [ -f "$doc" ]; then
    doc_dir=$(dirname "$doc")
    # Extract relative links: [text](target) where target doesn't start with http, mailto, or #
    LINKS=$(grep -oE '\[[^]]+\]\(([^)]+)\)' "$doc" | sed -E 's/\[[^]]+\]\(([^)]+)\)/\1/' || true)
    while IFS= read -r link; do
      [ -z "$link" ] && continue
      # Skip web URLs, mailto, anchor-only links
      if [[ "$link" =~ ^https?:// ]] || [[ "$link" =~ ^mailto: ]] || [[ "$link" =~ ^# ]]; then
        continue
      fi
      # Strip anchor if present
      clean_link="${link%%#*}"
      [ -z "$clean_link" ] && continue

      target_path="$doc_dir/$clean_link"
      if [ ! -e "$target_path" ]; then
        echo "  ❌ Broken relative link in $doc: '$link' -> '$target_path' does not exist"
        ERRORS=$((ERRORS + 1))
      fi
    done <<< "$LINKS"
  fi
done

echo ""
echo "=================================================="
if [ $ERRORS -gt 0 ]; then
  echo "❌ Documentation check FAILED with $ERRORS error(s)!"
  exit 1
else
  echo "🎉 Documentation check PASSED! All docs, links, and cross-references valid."
  exit 0
fi

