#!/usr/bin/env bash
set -euo pipefail

# Helper to abbreviate "45 minutes ago" -> "45m"
abbreviate() {
  echo "$1" | sed -E 's/ seconds? ago/s/; s/ minutes? ago/m/; s/ hours? ago/h/; s/ days? ago/d/; s/ weeks? ago/w/; s/ months? ago/mo/; s/ years? ago/y/'
}

# Header
cat <<EOF
# GitHub Dashboard

Auto-generated overview of repositories tagged with \`gh-dash\`.
Last updated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

<table border="0" width="100%">
EOF

# Fetch repos with topic gh-dash from user and their orgs
echo "Searching for repositories with topic 'gh-dash'..." >&2

# Identify targets: current owner + user's organizations
owner="${GITHUB_REPOSITORY_OWNER:-}"
if [ -z "$owner" ]; then
  owner=$(gh api user --jq '.login' 2>/dev/null || echo "dachrisch")
fi

orgs=$(gh api user/orgs --jq '.[].login' 2>/dev/null || echo "")
targets=$(echo -e "$owner\n$orgs\nbumbleflies" | sort -u | grep -v '^$')

repos="[]"
for target in $targets; do
  echo "  - Checking $target..." >&2
  target_repos=$(gh repo list "$target" --topic gh-dash --json nameWithOwner,url,defaultBranchRef --limit 100 2>/dev/null || echo "[]")
  repos=$(echo "$repos $target_repos" | jq -s 'add')
done

count=$(echo "$repos" | jq 'length')
echo "Found $count repositories." >&2

if [ "$count" -eq 0 ]; then
  echo "WARNING: No repositories found with topic 'gh-dash'." >&2
  echo "Check if your token has access to the repositories and if they have the 'gh-dash' topic." >&2
fi

i=0
echo "$repos" | jq -c '.[]' | while read -r repo; do
  name=$(echo "$repo" | jq -r '.nameWithOwner')
  url=$(echo "$repo" | jq -r '.url')
  branch=$(echo "$repo" | jq -r '.defaultBranchRef.name // "main"')
  
  echo "Processing repository: $name (branch: $branch)" >&2

  # 1. Fetch CI Status
  ci_json=$(gh api repos/$name/commits/$branch/status 2>/dev/null || echo "{}")
  ci_state=$(echo "$ci_json" | jq -r '.state // "unknown"')
  
  check_runs_json=$(gh api repos/$name/commits/$branch/check-runs 2>/dev/null || echo "{}")
  # Only count failure and timed_out as failures, ignore cancelled
  check_runs_failing=$(echo "$check_runs_json" | jq -r '[.check_runs[]? | select(.conclusion == "failure" or .conclusion == "timed_out")] | length')
  check_runs_pending=$(echo "$check_runs_json" | jq -r '[.check_runs[]? | select(.status != "completed")] | length')

  # detailed CI analysis - ignore cancelled statuses in Status API
  failed_ctx=$(echo "$ci_json" | jq -r '.statuses[]? | select(.state == "failure") | .context' | head -n 1)
  failed_url=$(echo "$ci_json" | jq -r '.statuses[]? | select(.state == "failure") | .target_url' | head -n 1)
  
  if [ "$check_runs_failing" -gt 0 ]; then
    failed_ctx=$(echo "$check_runs_json" | jq -r '.check_runs[]? | select(.conclusion == "failure") | .name' | head -n 1)
    failed_url="$url/actions"
    ci_state="failure"
  fi

  hold_ctx=$(echo "$ci_json" | jq -r '.statuses[]? | select(.state == "pending" and (.context | contains("hold"))) | .context' | head -n 1)
  hold_url=$(echo "$ci_json" | jq -r '.statuses[]? | select(.state == "pending" and (.context | contains("hold"))) | .target_url' | head -n 1)

  if [ "$check_runs_pending" -gt 0 ]; then
    ci_state="pending"
  fi

  # 2. Fetch PRs and check for conflicts/age
  pr_count=$(gh pr list --repo "$name" --state open --json number --limit 100 2>/dev/null | jq 'length')
  pr_age_human=$(gh pr list --repo "$name" --state all --limit 1 --json createdAt --template '{{range .}}{{timeago .createdAt}}{{end}}' 2>/dev/null || echo "")
  pr_age_short=$(abbreviate "$pr_age_human")
  conflicts_url=$(gh pr list --repo "$name" --state open --json url,mergeable 2>/dev/null | jq -r '.[] | select(.mergeable == "CONFLICTING") | .url' | head -n 1)

  # 3. Fetch Release info
  rel_json=$(gh release list --repo "$name" --limit 1 --json tagName,createdAt 2>/dev/null || echo "[]")
  rel_tag=$(echo "$rel_json" | jq -r '.[0].tagName // empty')
  
  if [ -n "$rel_tag" ]; then
    rel_age_human=$(gh release list --repo "$name" --limit 1 --json createdAt --template '{{range .}}{{timeago .createdAt}}{{end}}' 2>/dev/null || echo "")
    rel_age_short=$(abbreviate "$rel_age_human")
    rel_badge="https://img.shields.io/badge/release-${rel_tag//-/--}-blue?style=flat-square"
    rel_age_badge="https://img.shields.io/badge/${rel_age_short// /%20}-gray?style=flat-square"
  else
    rel_tag="none"
    rel_age_short=""
    rel_badge="https://img.shields.io/badge/release-none-gray?style=flat-square"
    rel_age_badge=""
  fi

  # 4. Fetch Commit age
  commit_age_human=$(gh repo view "$name" --json pushedAt --template '{{timeago .pushedAt}}' 2>/dev/null || echo "")
  commit_age_short=$(abbreviate "$commit_age_human")

  # 5. Fetch Security Alerts
  dependabot_count=$(gh api "repos/$name/dependabot/alerts" -f state=open 2>/dev/null | jq 'if type=="array" then length else 0 end' 2>/dev/null | head -n 1 | tr -dc '0-9' || echo "0")
  code_scanning_count=$(gh api "repos/$name/code-scanning/alerts" -f state=open 2>/dev/null | jq 'if type=="array" then length else 0 end' 2>/dev/null | head -n 1 | tr -dc '0-9' || echo "0")
  secret_scanning_count=$(gh api "repos/$name/secret-scanning/alerts" 2>/dev/null | jq 'if type=="array" then length else 0 end' 2>/dev/null | head -n 1 | tr -dc '0-9' || echo "0")
  total_security_alerts=$(( ${dependabot_count:-0} + ${code_scanning_count:-0} + ${secret_scanning_count:-0} ))

  # 6. Compute Action Link
  action_label=""
  action_url=""
  action_color="orange"

  if [ "$total_security_alerts" -gt 0 ]; then
    action_label="FIX SECURITY ($total_security_alerts)"
    action_url="$url/security"
    action_color="red"
  elif [ "$ci_state" == "failure" ] || [ -n "$failed_ctx" ]; then
    short_ctx=$(echo "${failed_ctx:-CI}" | sed 's#ci/circleci: ##; s#build_test_deploy/##')
    action_label="FIX $short_ctx"
    action_url="${failed_url:-$url/actions}"
    action_color="red"
  elif [ -n "$conflicts_url" ]; then
    action_label="RESOLVE CONFLICTS"
    action_url="$conflicts_url"
    action_color="red"
  elif [ -n "$hold_ctx" ]; then
    short_ctx=$(echo "$hold_ctx" | sed 's#ci/circleci: ##; s#build_test_deploy/##')
    action_label="APPROVE $short_ctx"
    action_url="${hold_url:-https://app.circleci.com/pipelines/github/$name}"
    action_color="blueviolet"
  elif [ "$ci_state" == "pending" ] && ([ "$check_runs_pending" -gt 0 ] || [ "$ci_json" != "{}" -a "$(echo "$ci_json" | jq -r '.statuses | length')" -gt 0 ]); then
    action_label="CI RUNNING"
    action_url="$url/actions"
    action_color="yellow"
  elif [ "$pr_count" -gt 0 ]; then
    action_label="REVIEW PRS"
    action_url="$url/pulls"
    action_color="blue"
  else
    action_label="ALL DONE"
    action_url="$url"
    action_color="green"
  fi

  # Start new row every 2 items
  if [ $((i % 2)) -eq 0 ]; then
    [ $i -gt 0 ] && echo "  </tr>"
    echo "  <tr>"
  fi

  # Badges
  pr_badge="https://img.shields.io/github/issues-pr/$name?label=prs&style=flat-square"
  commit_age_badge="https://img.shields.io/badge/commit-${commit_age_short// /%20}-green?style=flat-square"
  pr_age_badge="https://img.shields.io/badge/${pr_age_short// /%20}-gray?style=flat-square"
  security_badge="https://img.shields.io/badge/security-none-green?style=flat-square"
  if [ "$total_security_alerts" -gt 0 ]; then
    security_badge="https://img.shields.io/badge/security-${total_security_alerts}-red?style=flat-square"
  fi

  # Output Card
  cat <<CARD
    <td width="50%" align="left" valign="top" style="border: 1px solid #30363d; border-radius: 6px; padding: 12px;">
      <a href="$url"><b>$name</b></a><br>
      <hr style="border: 0; border-top: 1px solid #30363d; margin: 8px 0;">
      <p style="margin: 12px 0;">
        <a href="$action_url">
          <img src="https://img.shields.io/badge/ACTION-$action_label-$action_color?style=for-the-badge" alt="action">
        </a>
      </p>
      <div style="margin-top: 10px;">
        <a href="$url/commits/$branch"><img src="$commit_age_badge" alt="commit"></a> ˙ <a href="$url/pulls"><img src="$pr_badge" alt="prs"></a>$([ -n "$pr_age_short" ] && echo " <img src=\"$pr_age_badge\" alt=\"pr-age\">")<br>
        <a href="$url/releases"><img src="$rel_badge" alt="release"></a>$([ -n "$rel_age_short" ] && echo " <img src=\"$rel_age_badge\" alt=\"release-age\">") ˙ <a href="$url/security"><img src="$security_badge" alt="security"></a>
      </div>
    </td>
CARD

  i=$((i + 1))
done

# Fill remaining cells
while [ $((i % 2)) -ne 0 ]; do
  echo "    <td width=\"50%\"></td>"
  i=$((i + 1))
done

echo "  </tr>"
echo "</table>"
