#!/usr/bin/env bash
# Run the standalone source checks for one exact private commit on a
# GitHub-hosted runner, post the result as the commit status
# `public-ci/source` on the private repository, then delete the run so its
# log is not left public.
# Usage: scripts/run.sh <40-character commit>
set -euo pipefail
sha=${1:-}
repo=notzenco/umbra-control-plane-build
source_repo=umbra-me/umbra-control-plane
context=public-ci/source
[[ $sha =~ ^[0-9a-f]{40}$ ]] || { echo "usage: $0 <40-character commit>" >&2; exit 2; }

status_post() { gh api -X POST "repos/$source_repo/statuses/$sha" -f state="$1" -f context="$context" -f description="$2" >/dev/null; }
latest() { gh run list -R "$repo" --workflow ci.yml --limit 1 --json databaseId -q '.[0].databaseId // 0'; }

before=$(latest)
gh workflow run ci.yml -R "$repo" -f source_sha="$sha" >/dev/null
status_post pending "running on a GitHub-hosted runner"
id=$before
for _ in $(seq 1 45); do
  id=$(latest)
  [[ $id != "$before" ]] && break
  sleep 2
done
[[ $id != "$before" ]] || { status_post error "the dispatched run never appeared"; exit 1; }

rc=0
gh run watch "$id" -R "$repo" --exit-status --interval 20 >/dev/null 2>&1 || rc=$?
conclusion=$(gh run view "$id" -R "$repo" --json conclusion -q .conclusion)
log=$(gh run view "$id" -R "$repo" --log 2>/dev/null || true)
elapsed=$(grep -oE 'elapsed_seconds=[0-9]+' <<<"$log" | head -1 | cut -d= -f2)
passed=$(grep -oE 'pass_checks=[0-9]+' <<<"$log" | head -1 | cut -d= -f2)
failed=$(grep -oE 'fail_checks=[0-9]+' <<<"$log" | head -1 | cut -d= -f2)
summary="${passed:-?} checks passed, ${failed:-?} failed in $(( ${elapsed:-0} / 60 ))m$(( ${elapsed:-0} % 60 ))s"
echo "${sha:0:12}: $conclusion ($summary)"
if [[ $conclusion == success ]]; then
  status_post success "$summary"
else
  grep -E 'FAIL ' <<<"$log" | grep -v 'grep' | sed 's/^.*Z //' | head -20 || true
  status_post failure "$conclusion: $summary"
fi
gh run delete "$id" -R "$repo" >/dev/null
exit "$rc"
