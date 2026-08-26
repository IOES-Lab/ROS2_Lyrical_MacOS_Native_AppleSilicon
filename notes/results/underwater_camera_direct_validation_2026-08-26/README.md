# Underwater Camera direct validation — 2026-08-26

## Verdict

- Wiki Quickstart: **FUNCTIONAL PASS** on Mac and Docker
- Output: 320×240 `bgr8`, 230400 bytes
- No-effect and default attenuation: **PASS**
- Mac/Docker: all three representative frames are byte-identical
- RGB parameter meaning: **PARTIAL — Red and Blue are swapped**
- General underwater optical accuracy: **not established**

## Controlled result

| Condition | Mac BGR | Docker BGR |
|---|---:|---:|
| no effect | `[55, 78, 109]` | `[55, 78, 109]` |
| defaults | `[48, 68, 95]` | `[48, 68, 95]` |
| murky | `[83, 103, 74]` | `[83, 103, 74]` |

Five frames were captured per condition and platform. Each run was
deterministic, and the retained Mac/Docker `.npy` files have identical hashes.

At 3.975 m, the default `1/30` attenuation predicts `[48, 68, 95]`,
matching runtime output exactly.

For the Wiki murky values:

- direct array-to-BGR indexing predicts `[83, 103, 74]`
- semantic RGB mapping predicts `[50, 103, 85]`
- observed output is `[83, 103, 74]`

Therefore runtime behavior is:

```text
attenuationR/backgroundR -> Blue
attenuationG/backgroundG -> Green
attenuationB/backgroundB -> Red
```

## Evidence

Final evidence, cited by the verdict above:

- Mac Wiki Quickstart: 03_quickstart_retry/
- Mac controlled matrix: 05_parameter_matrix/
- Docker Quickstart and matrix: 06_docker_validation/
- Machine-readable verdict: summary.json

Kept but **not** used as evidence for any judgement above:

- `01_wiki_quickstart/` — first Quickstart attempt. Several probes produced no
  output and are retained as empty files (`plugin_evidence.txt`,
  `gz_topic_list.txt`, `simulated_image_info.txt`, `camera_node_info.txt`).
  `03_quickstart_retry/` is the run that succeeded.
- `02_debug_quickstart/` — the debug launch used to work out why the first
  attempt produced nothing.
- `04_murky_capture/` — a bag-based capture route that was abandoned;
  `bag_info.txt`, `raw_image_info.txt` and `depth_image_info.txt` are empty.
  The murky condition was captured through `05_parameter_matrix/` instead.

The empty files are left in place rather than deleted, so the failed route
stays visible. Three files in `03_quickstart_retry/` also remain empty for the
same reason, alongside the ones that did produce output.

This validates output and the implemented transform in one controlled scene.
It does not establish general underwater optical accuracy.
