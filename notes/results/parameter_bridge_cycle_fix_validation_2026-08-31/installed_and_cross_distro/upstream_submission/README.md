# Upstream submission state — 2026-08-31

## Current state

- Issue: [`gazebosim/ros_gz#951`](https://github.com/gazebosim/ros_gz/issues/951)
- Signed fix: [`gazebosim/ros_gz#952`](https://github.com/gazebosim/ros_gz/pull/952)
- Signed commit: `86910a32efe28624ec489ae5ce5cdcfb5a2ec500`
- DCO: PASS
- GitHub mergeability: MERGEABLE
- Remaining upstream action: maintainer review and merge

The first signed push used an email that did not satisfy DCO and is retained as
an invalid attempt. The commit was amended with the contributor's GitHub
no-reply address and force-updated; the current DCO result is the valid one.

`pr_branch_summary.txt` and several similarly named files are chronological
pre-PR snapshots. They are retained as history, not as the current verdict.
`submission_summary.txt` now gives the compact current state;
`pr_status_after_dco_fix.json` retains the machine-readable check state, and
the exact public URLs are in `issue_url.txt` and `pr_url.txt`.

The PR body deliberately scopes the fix to the reproduced `parameter_bridge`
owner cycle. The separately reproduced macOS `bridge_node` SIGINT exit 139 and
test-helper mutex abort are not claimed fixed by PR #952.
