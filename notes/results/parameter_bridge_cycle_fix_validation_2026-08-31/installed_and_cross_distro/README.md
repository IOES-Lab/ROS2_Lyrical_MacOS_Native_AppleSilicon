# Installed-workspace and cross-distribution follow-up — 2026-08-31

## Verdict

The ownership-cycle candidate now passes a **normal source/install overlay**
workflow on ROS 2 Lyrical and equivalent branch-local builds on ARM64 ROS 2
Jazzy and Kilted.

| Environment | Build / install | Topics | Service | Teardown |
|---|---:|---:|---:|---:|
| Lyrical Docker, normal install prefix | PASS | 8/8 | 1/1 | active bidirectional 10/10 |
| Jazzy official ARM64 ROS image | PASS | 8/8 | 1/1 | bridge rc 0, no escalation |
| Kilted official ARM64 ROS image | PASS | 8/8 | 1/1 | bridge rc 0, no escalation |

The topic matrix covers four conversions in each direction:

- GZ→ROS: String, Float64, Vector3 and Pose;
- ROS→GZ: String, Float64, Vector3 and Twist.

The service matrix directly calls ControlWorld pause and unpause and receives
success=True for both.

## Patch portability

The retained patch was authored against exact ros_gz 3.0.9 commit
2d17974dd4aec749e22824f74baa22149aaf5b4d. It also passes
git apply --check on current gazebosim/ros_gz origin/ros2 commit
2ee8a5c716d1838de0b7ac817638ad5e9304955e.

The exact patch text does **not** apply unchanged to the Humble, Jazzy or Kilted
release branches because their local context differs. Equivalent branch-local
WeakPtr adaptations were generated and pass git diff --check. Jazzy and
Kilted were then built and run; Humble has static adaptation evidence only and
has **not** been built or run here.

## Invalid attempts

Four failed harness attempts are retained and clearly excluded:

- Lyrical initially enabled shell nounset before sourcing ROS setup;
- a repeat run used a ROS domain ID outside the valid DDS range;
- Jazzy initially mixed a source bridge with older binary interfaces, then
  reused a stale CMake cache;
- the first Jazzy runtime signalled the ros2-run wrapper PID, and its first
  service attempt lacked the gz-sim package.

The final Jazzy and Kilted verdicts use fresh builds and invoke the installed
parameter_bridge executable directly.

## Upstream readiness review

A read-only review of `gazebosim/ros_gz` found **0 matches across eight focused
issue/PR duplicate searches**. The default branch is `ros2`; no project issue
form or pull-request template was found, and `CONTRIBUTING.md` contains the
Apache-2.0 contribution-license notice. No issue or pull request was created.
The prepared local draft is ready for maintainer review, while submission,
acceptance, CI and merge remain external work.

Evidence: [`upstream_review/`](upstream_review/).

## Remaining scope

This closes the earlier normal-install, Jazzy/Kilted ARM64 build/runtime and
small message/service-matrix gaps. It does **not** establish exhaustive
conversion coverage, Humble runtime, x86_64 coverage, upstream acceptance or
installation into the user's ordinary DAVE/Homebrew workspaces.
