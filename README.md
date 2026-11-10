# umbra-control-plane-build

Public CI for the private `umbra-me/umbra-control-plane` repository.

The only workflow, `ci.yml`, runs on manual dispatch with an exact
40-character source commit. It checks that commit out with a read-only deploy
key and runs the standalone source checks (`scripts/local-ci.py --scope
source`) on a GitHub-hosted runner. Its log shows only check names, pass/fail
counts and timings; all other output is discarded with the runner. It never
runs on pull requests and keeps no artifacts.

Use `scripts/run.sh <40-character commit>` from a clone: it dispatches, waits,
posts the result as the `public-ci/source` commit status on the private
repository, then deletes the run. Run logs are retained for at most one day.
