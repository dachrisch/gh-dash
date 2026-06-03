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
repos=$(gh repo list --topic gh-dash --json nameWithOwner,url --limit 100)

echo "$repos" | jq -c '.[]' | while read -r repo; do
  name=$(echo "$repo" | jq -r '.nameWithOwner')
  url=$(echo "$repo" | jq -r '.url')
  
  # CI Status
  ci_json=$(gh run list --repo "$name" --limit 1 --json conclusion,status 2>/dev/null || echo "[]")
  ci_glyph="—"
  if [ "$ci_json" != "[]" ]; then
    status=$(echo "$ci_json" | jq -r '.[0].status')
    conc=$(echo "$ci_json" | jq -r '.[0].conclusion')
    case "$conc" in
      success) ci_glyph="✅" ;;
      failure) ci_glyph="❌" ;;
      cancelled|timed_out) ci_glyph="⚠️" ;;
      null)
        case "$status" in
          in_progress|queued) ci_glyph="⏳" ;;
          *) ci_glyph="—" ;;
        esac ;;
    esac
  fi

  # PR Status
  pr_json=$(gh pr list --repo "$name" --state open --json number,isDraft 2>/dev/null || echo "[]")
  pr_count=$(echo "$pr_json" | jq 'length')
  pr_display="—"
  if [ "$pr_count" -gt 0 ]; then
    pr_display="⚓ $pr_count"
  else
    pr_display="✅ 0"
  fi

  # Latest Release
  rel_json=$(gh release list --repo "$name" --limit 1 --json tagName 2>/dev/null || echo "[]")
  rel_tag="—"
  if [ "$rel_json" != "[]" ]; then
    rel_tag=$(echo "$rel_json" | jq -r '.[0].tagName')
  fi

  # Output Table Row
  echo "| [$name]($url) | 📊 | $ci_glyph | $pr_display | \`$rel_tag\` |"
done
