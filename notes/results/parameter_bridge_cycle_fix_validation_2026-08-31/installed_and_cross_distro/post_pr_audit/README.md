# Post-submission audit — 2026-08-31

## Verdict

**PASS.** The independent post-PR audit passed **45/45** assertions.

It re-read retained machine evidence rather than trusting prose, fetched the
four signed PR source files from commit
`86910a32efe28624ec489ae5ce5cdcfb5a2ec500` and compared them byte-for-byte
with the actual user workspace, and queried the live PR state.

Verified current state:

- actual user workspace source matches the signed PR 4/4;
- its two pre-existing unrelated CMake edits remain present;
- build PASS, bounded directions 24/24, generated mappings 73/73;
- payload assertions 73/73 each direction, ordered bridge rc 0;
- repeated payload 5/5 and lifecycle 11/11;
- separate component path still records 3/3 topics + 1/1 service before helper
  rc 134 and `bridge_node` rc 139;
- issue #951 and PR #952 are open; signed head matches, DCO passes, GitHub
  reports MERGEABLE and maintainer review is required;
- current GitHub counts are 49 known-issue entries and 112 progress rows;
- six affected Notion pages were refetched and contain PR #952, 73/73,
  actual-workspace and separate-component scope without stale no-PR/adoption
  wording.

Files:

- [`audit_post_pr.json`](audit_post_pr.json) — 45/45 machine assertions
- [`pr_live.json`](pr_live.json) — live PR state captured during the audit
- [`notion_recheck.json`](notion_recheck.json) — authenticated connector recheck
- `final_repo_check.txt`, `audit_evidence.json`, `audit_repo.json` — repository
  and retained-evidence audits added by the final pass

## Boundary

This audit does not convert external scope into local evidence. Maintainer
review/merge, native x86_64 hardware, Windows, hardware GPU and general
scientific accuracy remain outside the available environment. The macOS
component/test-helper teardown failure remains a separate open defect.
