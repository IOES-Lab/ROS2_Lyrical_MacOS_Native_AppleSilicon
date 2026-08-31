# Underwater Camera channel-isolation validation — 2026-08-31

## Verdict

**PASS for the implemented six-tag mapping in this controlled Docker scene.**

Eight camera instances ran simultaneously against the same planar target.  The
control frame was used as the unmodified input oracle.  Each of
`attenuationR/G/B` and `backgroundR/G/B` was then changed independently.  In
BGR image memory, each semantic tag changed only its intended channel:

- `attenuationR` / `backgroundR` -> Red (BGR index 2)
- `attenuationG` / `backgroundG` -> Green (BGR index 1)
- `attenuationB` / `backgroundB` -> Blue (BGR index 0)

All seven non-control center pixels matched
`exp(-range * attenuation) * input + (1-exp(...)) * background` exactly after
8-bit truncation (zero-LSB error at the 3.975 m target surface).

## Direct results

| Variant | Observed center BGR | Analytic center BGR |
|---|---:|---:|
| `ucam_control` | `[31, 61, 122]` | `control oracle` |
| `ucam_atten_base` | `[4, 8, 16]` | `[4, 8, 16]` |
| `ucam_atten_r_only` | `[31, 61, 16]` | `[31, 61, 16]` |
| `ucam_atten_g_only` | `[31, 8, 122]` | `[31, 8, 122]` |
| `ucam_atten_b_only` | `[4, 61, 122]` | `[4, 61, 122]` |
| `ucam_bg_r_only` | `[4, 8, 189]` | `[4, 8, 189]` |
| `ucam_bg_g_only` | `[4, 180, 16]` | `[4, 180, 16]` |
| `ucam_bg_b_only` | `[176, 8, 16]` | `[176, 8, 16]` |

Each topic produced at least ten frames before capture.  The eight recorded
arrays also had eight distinct SHA-256 hashes.

## Scope

This closes the remaining *individual tag mapping* gap for the isolated
candidate build.  It does **not** establish general underwater optical
accuracy, real-camera agreement, wavelength-dependent calibration quality, or
mission-duration stability.  The valid run used Docker llvmpipe with the
container's authorised X display.  A first no-X attempt is retained and marked
invalid because OGRE could not open a display.

## Evidence

- [`summary.json`](summary.json)
- [`runtime/summary.json`](runtime/summary.json)
- [`test_assets/`](test_assets/)
- [`capture_matrix.py`](capture_matrix.py)
- [`invalid_no_x_attempt/INVALID_ATTEMPT.txt`](invalid_no_x_attempt/INVALID_ATTEMPT.txt)
