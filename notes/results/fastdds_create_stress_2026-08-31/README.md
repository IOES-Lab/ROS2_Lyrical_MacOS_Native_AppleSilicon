# Fast DDS concurrent create stress — 2026-08-31

## Verdict

**STRESS PASS in the tested fresh-Docker scope.** The valid v3 harness ran
**160** bounded `ros_gz_sim create` processes and recorded **160 successes,
0 nonzero exits, and 0 timeouts**.

| Phase | Shape | Result |
|---|---:|---:|
| Default SHM+UDP, initial state | 5 rounds × 8 concurrent | 40/40 |
| Default after 20 deliberately SIGKILLed create clients | 5 × 8 | 40/40 |
| Default after `fastdds shm clean` | 5 × 8 | 40/40 |
| `FASTDDS_BUILTIN_TRANSPORTS=UDPv4` | 5 × 8 | 40/40 |

The maximum observed client wall time was **5.861 s**.
The 20 injected clients all returned `-9`, confirming that the intended forced
termination occurred before the following 40-process phase.

## Invalid attempts retained

- The host attempt is excluded: Gazebo never started because the Homebrew
  binary requested the removed `libswscale.9.dylib` ABI.
- Docker attempts v1 and v2 are excluded because the evidence harness itself
  was wrong (mixed timeout-output types, then a mismatched `GZ_PARTITION` in
  the readiness probe). Their `INVALID_ATTEMPT.txt` files state the exact
  exclusion reason.

## Scope

This substantially strengthens the current Fast DDS create reliability result,
but it does **not** explain the historical 1/9 host failure and does not prove
all hosts, transports, or long-lived shared-memory states are failure-free.

## Evidence

- [`summary.json`](summary.json)
- [`docker_valid_v3/summary.json`](docker_valid_v3/summary.json)
- [`docker_valid_v3/results.csv`](docker_valid_v3/results.csv)
- [`docker_valid_v3/runner_stdout.txt`](docker_valid_v3/runner_stdout.txt)
- [`INVALID_HOST_ATTEMPT.txt`](INVALID_HOST_ATTEMPT.txt)
