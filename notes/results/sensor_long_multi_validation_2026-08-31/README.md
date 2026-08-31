# Bounded long-duration and multi-instance sensor validation — 2026-08-31

## Verdict

**PASS within the tested synthetic scope.**  This result closes two bounded
runtime gaps; it does not convert either sensor family into a physical
calibration result.

## SeaPressure

Seven candidate devices ran simultaneously in Docker.  The run covered up to
about 200 simulated seconds: 100 seconds for the normal 10/20 Hz paths and 200
seconds for the custom 5 Hz path.  All target counts were reached.  The noisy
sensor produced 2,000 unique values with mean `101325.214 Pa`, sample standard
deviation `119.914 Pa` for a `123 Pa` target, and exact published variance
`15129 Pa²`.  Surface, depth, above-surface clamp, saturation, custom-fluid,
and 2 Hz rate checks all passed.

Evidence: [`seapressure/summary.json`](seapressure/summary.json).

## DVL

All eight distinct DAVE DVL descriptors ran simultaneously against a planar
bottom.  Each produced 20 messages (160 total), four beams, bottom lock, a
nonempty unique frame ID, and the period configured by that descriptor
(8, 12, or 7 Hz).

The first analysis incorrectly assumed every descriptor was 8 Hz.  The capture
was complete; the corrected analysis reads the actual rates from the committed
test world.  That correction is preserved in
[`dvl_multi8/ANALYSIS_CORRECTION.md`](dvl_multi8/ANALYSIS_CORRECTION.md).

Evidence: [`dvl_multi8/summary.json`](dvl_multi8/summary.json).

## Limits

- One Docker run per family.
- Synthetic pressure and planar-bottom oracles only.
- Bounded duration and message counts, not mission-duration endurance.
- No real sensor, water-mass, or physical calibration comparison.
- DVL teardown emitted the separately tracked bridge shutdown stack trace
  after the successful capture; it does not change the runtime data verdict.
