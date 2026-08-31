# Installed-workspace and cross-distribution follow-up — 2026-08-31

## Verdict

The ownership-cycle candidate passes every bounded `parameter_bridge`
build/runtime matrix retained here. After the isolated and cross-distribution
runs, the exact candidate was also applied to the user's ordinary `ros_gz`
workspace while preserving two unrelated pre-existing CMake edits. It built
successfully and passed the expanded actual-workspace conversion and shutdown
oracles. Separate component/test-helper teardown failures are explicitly kept
open rather than folded into this verdict.

| Environment | Build / install | Topics | Services | Teardown |
|---|---:|---:|---:|---:|
| Lyrical Docker, isolated normal install prefix | PASS | 8/8 | 1/1 | active bidirectional 10/10 |
| Humble official ARM64 image | PASS | 8/8 | 1/1 | bridge rc 0, no escalation |
| Jazzy official ARM64 image | PASS | 8/8 | 1/1 | bridge rc 0, no escalation |
| Kilted official ARM64 image | PASS | 8/8 | 1/1 | bridge rc 0, no escalation |
| Jazzy official `linux/amd64` image on Apple-Silicon emulation | PASS | 8/8 | 1/1 | bridge rc 0, no escalation |
| Exact-3.0.9 ordinary-layout isolated clone | PASS | 24/24 directions, 13 unique pairs | 4/4 factories | bridge rc 0, no escalation |
| Actual Lyrical user workspace, current `ros2` candidate | PASS | 24/24 bounded; generated payloads 73/73 each direction | isolated 4/4 retained; Mac rerun ABI-blocked | ordered bridge rc 0; repeat 5/5; lifecycle 11/11 |

The smaller cross-distribution topic matrix covers four conversions in each
direction:

- GZ→ROS: String, Float64, Vector3 and Pose;
- ROS→GZ: String, Float64, Vector3 and Twist.

The expanded exact-3.0.9 matrix covers 24 directions across 13 unique type
pairs. The four service factories are ControlWorld, SpawnEntity,
SetEntityPose and DeleteEntity; every direct request returned `success=True`.
The actual-workspace follow-up then inventories all 73 generated topic mapping
pairs in that checkout, instantiates 146 direction handles, and passes 73/73
generated payload assertions in each direction. That makes topic-factory
coverage exhaustive for this checkout, while still not claiming every
possible runtime QoS, lazy-mode or hardware combination.

## Patch portability

The retained patch was authored against exact `ros_gz` 3.0.9 commit
`2d17974dd4aec749e22824f74baa22149aaf5b4d`. It also passes
`git apply --check` on `gazebosim/ros_gz` `ros2` commit
`2ee8a5c716d1838de0b7ac817638ad5e9304955e`.

The exact patch text does not apply unchanged to Humble, Jazzy or Kilted
because their local context differs. Equivalent branch-local WeakPtr
adaptations were generated and built. Humble uses its Ignition transport
names; Jazzy/Kilted use their release interfaces.

## Ordinary-layout isolation

The exact-3.0.9 candidate was built under
`/home/docker/ros_gz_ws_candidate/src/ros_gz` in a disposable container. The
user workspace was snapshotted before and after. Git state, four target-file
SHA-256 values and mtime inventories are identical, so this validates an
ordinary workspace layout without adopting the candidate into the user's
actual installation.

Evidence: [`ordinary_clone/`](ordinary_clone/) and
[`expanded_matrix/`](expanded_matrix/).

## Actual user-workspace adoption

The candidate was subsequently applied to
`/Users/gwon-yeseol/ros_gz_ws_lyrical/src/ros_gz`. Before applying it, the
workspace already had two unrelated CMake edits. Those edits remain, and only
the four intended bridge-handle files were added to the diff. All four now
match signed PR commit `86910a32efe28624ec489ae5ce5cdcfb5a2ec500`
byte for byte.

`ros_gz_bridge` builds successfully in that workspace. The retained runtime
oracles pass 24/24 bounded directions, all 73/73 generated mapping payloads in
each direction, 5/5 repeated payload runs, and 11/11 lifecycle-only runs. The
ordered 73-pair ROS→GZ bridge exits 0 without escalation.

The package's stock macOS launch harness also exposed separate limitations. An
ordered component run passes 3/3 topic and 1/1 service assertions, but its test
helper aborts with `mutex lock failed` and `bridge_node` exits 139 on SIGINT.
Those failures are not counted as a `parameter_bridge` candidate pass and are
not claimed fixed by PR #952. See
[`user_workspace_install/`](user_workspace_install/).

## Cross-architecture boundary

The Jazzy `linux/amd64` result uses Docker Desktop emulation on Apple M2. It
establishes x86_64 instruction-set build/runtime coverage in that environment;
it is not a native x86_64-hardware result.

Evidence: [`humble_arm64/`](humble_arm64/) and
[`jazzy_amd64_emulated/`](jazzy_amd64_emulated/).

## Invalid attempts excluded

Invalid harness/setup attempts are retained in the external work directory but
are not copied into this verdict set. They include a missing Humble package
name, a transient apt-network failure, a Jazzy DDS-discovery race, and an
incorrect Lyrical `FluidPressure` field name. Each valid result above comes
from a fresh successful rerun with explicit payload and process-exit oracles.

## Upstream readiness

Eight focused issue/PR duplicate searches returned zero results. The issue
was then filed as [gazebosim/ros_gz#951](https://github.com/gazebosim/ros_gz/issues/951).
The external account could not apply the requested labels, so maintainer triage
is still needed. The four-file PR candidate is based on `ros2` commit `2ee8a5c`,
was signed off and force-updated as commit `86910a3`, and is open as
[gazebosim/ros_gz#952](https://github.com/gazebosim/ros_gz/pull/952).
The DCO check passes and GitHub reports the PR as mergeable; maintainer review
is still required. URLs and exact state are retained under
[`upstream_submission/`](upstream_submission/).

## Final audit

The retained pre-adoption repository/evidence audit passed 61/61 prior
assertions and 28/28 follow-up assertions. The post-submission audit then
passed **45/45** independent assertions: actual-workspace files match signed PR
commit `86910a3` 4/4, all recorded generated-mapping and lifecycle oracles are
present, PR #952 is open / DCO-passing / mergeable with review required, and
current GitHub scope/count statements are consistent. Six affected Notion
pages were also refetched and checked for PR #952, 73/73, actual-workspace and
separate-component wording with no stale no-PR/adoption text.

Current audit: [`post_pr_audit/`](post_pr_audit/). The older result remains
under [`final_audit/`](final_audit/) as a dated pre-adoption snapshot.

## Remaining scope

The locally executable `parameter_bridge` topic-factory scope is complete.
Still external are maintainer review/merge, native x86_64 hardware, Windows,
hardware-GPU paths and general sonar/scientific accuracy. Locally reproduced
but still open are the macOS component (`bridge_node`) SIGINT exit 139 and the
test-helper mutex teardown failures. The actual Mac service-world rerun is also
blocked by an unrelated Homebrew Gazebo/FFmpeg ABI mismatch; the isolated 4/4
service-factory result remains valid.
