#!/usr/bin/env bash
set -euo pipefail

# Header
cat <<EOF
# GitHub Dashboard

Auto-generated overview of repositories tagged with \`gh-dash\`.
Last updated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

| Repository | Status | CI | PRs | Release |
| :--- | :---: | :---: | :---: | :---: |
EOF

# Fetch repos with topic gh-dash
echo "Searching for repositories with topic 'gh-dash'..." >&2
repos=$(gh repo list --topic gh-dash --json nameWithOwner,url --limit 100)
count=$(echo "$repos" | jq 'length')
echo "Found $count repositories." >&2

echo "$repos" | jq -c '.[]' | while read -r repo; do
  name=$(echo "$repo" | jq -r '.nameWithOwner')
  url=$(echo "$repo" | jq -r '.url')
  
  echo "Processing repository: $name" >&2

  # CI Status
  echo "  Checking CI status..." >&2
  ci_json=$(gh run list --repo "$name" --limit 1 --json conclusion,status 2>/dev/null || echo "[]")
  ci_glyph="—"
  if [ "$ci_json" != "[]" ] && [ -n "$ci_json" ]; then
    status=$(echo "$ci_json" | jq -r '.[0].status // empty')
    conc=$(echo "$ci_json" | jq -r '.[0].conclusion // empty')
    echo "    Latest run: status=$status, conclusion=$conc" >&2
    case "$conc" in
      success) ci_glyph="✅" ;;
      failure) ci_glyph="❌" ;;
      cancelled|timed_out) ci_glyph="⚠️" ;;
      "")
        case "$status" in
          in_progress|queued) ci_glyph="⏳" ;;
          *) ci_glyph="—" ;;
        esac ;;
      *) ci_glyph="—" ;;
    esac
  else
    echo "    No CI runs found." >&2
  fi

  # PR Status
  echo "  Checking Pull Requests..." >&2
  pr_json=$(gh pr list --repo "$name" --state open --json number,isDraft 2>/dev/null || echo "[]")
  pr_count=$(echo "$pr_json" | jq 'length')
  echo "    Found $pr_count open PRs." >&2
  pr_display="—"
  if [ "$pr_count" -gt 0 ]; then
    pr_display="⚓ $pr_count"
  else
    pr_display="✅ 0"
  fi

  # Latest Release
  echo "  Checking latest release..." >&2
  rel_json=$(gh release list --repo "$name" --limit 1 --json tagName 2>/dev/null || echo "[]")
  rel_tag="—"
  if [ "$rel_json" != "[]" ] && [ -n "$rel_json" ]; then
    rel_tag=$(echo "$rel_json" | jq -r '.[0].tagName // "—"')
    echo "    Latest release: $rel_tag" >&2
  else
    echo "    No releases found." >&2
  fi

  # Output Table Row
  echo "| [$name]($url) | 📊 | $ci_glyph | $pr_display | \`$rel_tag\` |"
done
