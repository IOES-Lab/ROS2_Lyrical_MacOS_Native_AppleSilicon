# macOS stock DVL `forceUpdate` initialization candidate — 2026-08-30

## Verdict

**The isolated candidate passes; the distributed stock installation remains PARTIAL.**

The unmodified official `ros_gz_sim_demos/worlds/dvl.sdf` was used throughout.
No hidden camera was added. The candidate was built from exact tag
`gz-sim10_10.4.0` (`cdf3f3c9700fc32938622302e08da1a598e0597e`) and was not installed into
Homebrew or submitted upstream.

## Reproduced baseline

With the stock Sensors system plugin, the official DVL world exits 139 in
`SensorsPrivate::WaitForInit()`. This is the same null-scene path retained in the earlier LLDB
evidence.

On macOS, `Sensors::Update()` initializes `RenderUtil` on the main thread only when its predicate
recognizes a rendering sensor. DVL requests rendering through `events::ForceRender()`, represented
by `forceUpdate`, but the Apple predicate did not include that flag.

## Why the first candidate was rejected

Candidate v1 only added `forceUpdate` to the Apple predicate. It appeared to work once, but a
10-run test passed only **9/10**; trial 6 crashed in the same `WaitForInit()` path.

The remaining race was between systems' parallel `PostUpdate` callbacks. DVL could emit
`ForceRender`, then Sensors' `PostUpdate` could wake the render thread before the next main-thread
`Sensors::Update()` initialized `RenderUtil`.

This failed candidate is preserved because a one-run or even several-run smoke test would have
incorrectly called it fixed.

## Candidate v2

[`candidate_v2.diff`](candidate_v2.diff) makes three scoped changes:

1. include `forceUpdate` in the Apple main-thread initialization predicate;
2. record that `RenderUtil::Init()` has completed on the main thread; and
3. prevent `Sensors::PostUpdate()` from handing initialization to the render thread before that
   completion.

The same mutex protects the flag's initialization handoff.

## Runtime results

| Control | Result |
|---|---|
| Stock Sensors plugin, official DVL world | exit 139, `WaitForInit()` crash |
| Rejected candidate v1 | 9/10 pass; one same-path crash |
| Candidate v2, official DVL world | **20/20 pass**, four beams locked, clean shutdown |
| Candidate v2, official standard camera world | **3/3 pass**, image captured |
| Candidate v2, Sensors system without a rendering sensor | **3/3 pass**, zero render initialization |
| Candidate v2 through official ROS bridge | `/dvl/velocity` published populated `marine_acoustic_msgs/msg/Dvl` |

The retained ROS message has:

```text
frame_id: tethys/base_link/teledyne_pathfinder_dvl
num_good_beams: 4
beam_ranges_valid: true
beam_velocities_valid: true
ranges: 22.772867–22.772871 m
```

`ros2 topic echo` itself hit a Python conversion error for this message type, so a one-shot C++
`rclcpp` subscriber captured the fields. Topic introspection independently reported one
`ros_gz_bridge` publisher.

## Test-harness boundary

The installed Homebrew Gazebo dependency set had stale reverse-library references after local
FFmpeg/x265 upgrades. The exact-tag build was therefore run with work-local compatibility
libraries. A stock-plugin control under the **same isolated executable and compatibility
environment still reproduced the crash**, so the candidate/baseline distinction does not come
from that harness.

No compatibility binary or build tree is committed here. The tested candidate Sensors library
SHA-256 is retained in [`provenance.txt`](provenance.txt).

## What this does not establish

- no upstream acceptance or installed Homebrew fix;
- no general DVL physical/range/velocity accuracy;
- no long-duration or multi-DVL stability;
- no Intel Mac or non-macOS regression claim beyond the listed controls.

## Evidence index

- [`summary.json`](summary.json) — machine-readable verdict
- [`baseline_stock_crash_excerpt.txt`](baseline_stock_crash_excerpt.txt)
- [`rejected_v1_repeat_10.csv`](rejected_v1_repeat_10.csv)
- [`rejected_v1_trial_06_crash_excerpt.txt`](rejected_v1_trial_06_crash_excerpt.txt)
- [`candidate_v2_repeat_20.csv`](candidate_v2_repeat_20.csv)
- [`candidate_v2_repeat_20.json`](candidate_v2_repeat_20.json)
- [`candidate_v2_success_excerpt.txt`](candidate_v2_success_excerpt.txt)
- [`gz_dvl_message.txt`](gz_dvl_message.txt)
- [`ros_dvl_message.json`](ros_dvl_message.json)
- [`ros_topic_info.txt`](ros_topic_info.txt)
- [`camera_regression_3.csv`](camera_regression_3.csv)
- [`no_render_regression_3.csv`](no_render_regression_3.csv)
- [`provenance.txt`](provenance.txt)

Relevant upstream context:
[Gazebo macOS rendering issue #960](https://github.com/gazebosim/gz-sim/issues/960),
[`Sensors.cc`](https://github.com/gazebosim/gz-sim/blob/gz-sim10_10.4.0/src/systems/sensors/Sensors.cc),
and
[`DopplerVelocityLogSystem.cc`](https://github.com/gazebosim/gz-sim/blob/gz-sim10_10.4.0/src/systems/dvl/DopplerVelocityLogSystem.cc).
