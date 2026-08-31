# Evidence compaction

The capture scripts originally retained one compressed NumPy array bundle for every scene and
backend.  The numerical summaries were generated before compaction.  To keep the repository
bounded, only the 4 m dark-plane CPU, distributed-WGPU and correctly relinked exact-N WGPU bundles
remain.  `array_sha256_manifest.txt` records the SHA-256 of every original bundle and whether it was
retained or removed after summary generation.

No launch log, message summary, aggregate JSON/CSV, build-provenance file or failed-candidate record
was rewritten by this compaction.  The scripts and copied worlds remain so the matrix can be rerun.
