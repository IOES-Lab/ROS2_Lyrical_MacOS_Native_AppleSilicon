# USBL multi-transceiver namespace validation — 2026-08-31

## Verdict

**PASS within the bounded static Docker control.**

Two transceivers and four transponders ran simultaneously in namespaces
`USBL_A` and `USBL_B`.  Both namespaces intentionally reused transceiver ID
168 and transponder IDs 1/2.  The graph exposed one location publisher and two
common-ping subscribers per namespace.

- Pinging only `USBL_A` produced 20 A messages and zero B messages.
- Pinging only `USBL_B` produced 20 B messages and zero A messages.
- Concurrent pings produced 20 messages in each namespace.
- Every active phase contained IDs 1 and 2 and matched the expected relative
  Cartesian geometry within floating-point roundoff (`5.56e-17 m`).

This directly closes the prior bounded multi-transceiver / namespace-isolation
gap.  It does not establish mission-duration endurance, moving multi-array
behavior, or physical acoustic accuracy.

## Evidence

- [`summary.json`](summary.json)
- [`runtime/summary.json`](runtime/summary.json)
- [`test_assets/usbl_multi_namespace.world`](test_assets/usbl_multi_namespace.world)
- [`capture_matrix.py`](capture_matrix.py)
- [`invalid_plugin_placement_attempt/INVALID_ATTEMPT.txt`](invalid_plugin_placement_attempt/INVALID_ATTEMPT.txt)
