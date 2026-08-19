<!-- 제출 대상: [`IOES-Lab/dave`](https://github.com/IOES-Lab/dave) — `models/dave_sensor_models/description/blueview_p900/model.sdf`. This is model content, not part of the WGPU backend, but it was measured on [PR #44](https://github.com/IOES-Lab/dave/pull/44)'s branch (`naitikpahwa18/dave`, `wgpu_integration`, pinned `6aef91c`); worth a quick check against `ros2` (the repository's default branch) before filing.
     라벨:     `enhancement`, `performance`
     원본:     notes/updaterate-issue-draft.md
     자동 생성: notes/make_submittable.py — 직접 고치지 말 것 -->

## 이슈 제목 (아래 한 줄을 제목 칸에 붙여넣기)

`blueview_p900` sets `<update_rate>30</update_rate>`, which the sensor cannot reach and the hardware does not do — lowering it recovers most of the sonar's simulation cost

## 이슈 본문 (아래 전체를 본문 칸에 붙여넣기)

---

## Summary

The shipped sonar model asks for 30 Hz. On an Apple M2 the sensor actually completes about
**2.8 frames per second**, so the requested rate never acts as a limit — it is effectively
"run as often as possible".

Lowering it is the largest improvement we have found that requires no code change and no
rebuild:

| `<update_rate>` | n | mean RTF | spread | overhead\* | removed |
|---|---|---|---|---|---|
| **30 (as shipped)** | 3 | 0.5243 | 7.9% | 0.905 | — |
| 10 | 3 | 0.5984 | 4.3% | 0.669 | **26%** |
| 5 | 1 | 0.6971 | — | 0.432 | 52% |
| 2 | 2 | 0.8140 | 6.2% | 0.226 | **75%** |

\* `1/RTF − 1/0.9974` — the added cost over a no-sonar control measured the same day on the
same world (n=3, spread 0.2%).

Monotonic, and both repeated conditions separate from 30 Hz by more than either one's
spread.

## Why 30 Hz is the wrong number

**It is unreachable.** At the shipped configuration the plugin logs roughly 550 frames over
~200 s of sonar-live time. Asking for 30 Hz when 2.8 Hz is achievable means the rate limit
never engages.

**It is also not physical.** A BlueView P900 tops out near 15 Hz in hardware, and lower in
most operating modes. The simulation is being asked for something the modelled device
cannot do.

## Why it matters more than a normal rate setting

The sonar's compute stage runs on its own thread and takes whatever capacity it can get.
Making each frame *cheaper* does not save CPU — it just runs more frames.

We measured this directly. Skipping the OpenCV visualisation image (an experimental local
patch, not proposed here) made RTF **40% worse**, and the plugin's own frame counter shows
why:

```
as shipped            GPU #550
visualisation skipped GPU #1300     <- 2.4x more sonar frames
```

The same axis showed up from the other side earlier: dropping `<raySkips>` to 1, which makes
the compute stage ~10x heavier, cost +73%.

So on this sensor the effective knob is **how often it runs**, not how fast each run is.
That makes `<update_rate>` unusually important here, and makes an unreachable value
unusually costly.

## Suggested fix

Set a rate the sensor can meet and the hardware plausibly does:

```diff
 <sensor name="multibeam_sonar" type="custom" gz:type="multibeam_sonar">
   <always_on>true</always_on>
-  <update_rate>30.0</update_rate>
+  <update_rate>10.0</update_rate>
```

10 Hz is below the P900's hardware ceiling and returns ~14% RTF here. 5 Hz or 2 Hz recover
considerably more if the application tolerates fewer pings.

If changing the shipped default is undesirable, documenting the trade-off would still help
— at present nothing indicates that this one number dominates simulation throughput.

## What this claim is and is not

- **Fewer pings per second is a real change in behaviour**, not free. Nothing here measures
  sonar output quality; the trade is throughput against ping rate, and which rate is
  appropriate depends on the application. We are not claiming 2 Hz is correct — only that
  30 Hz is not reachable and is above the hardware.
- **n is 3 / 3 / 1 / 2** across 30 / 10 / 5 / 2 Hz. The 5 Hz row is n=1 and shown for shape.
- **Frame counts are coarse.** The plugin logs every 50th frame and the figure recorded is
  the last one in the whole run, not within the measurement window, so small differences in
  it are not readable. Only the 2 Hz drop (250 against 600) is large enough to interpret.
- Measured on macOS / Apple Silicon (M2) / Metal only, with `multibeam_sonar` and
  `multibeam_sonar_system` built `Release` (see the separate build-type report — the
  default build carries no `-O` flag) and with `FASTDDS_BUILTIN_TRANSPORTS=UDPv4`.
- Whether the sensor reaches 30 Hz on faster hardware, or on Linux with a hardware GPU, was
  not tested. If it does there, the shipped value may be harmless on those setups — but it
  would still be above the physical device's rate.

## Environment

- `naitikpahwa18/dave`, branch `wgpu_integration`, pinned commit `6aef91c`
- ROS 2 Lyrical + Gazebo Jetty 10.4, macOS, Apple M2, Metal
- World `dave_multibeam_sonar`, sensor `blueview_p900`, otherwise shipped configuration
- RTF sampled as an endpoint delta over `/world/default/stats` across a 60 s window, after
  the simulation was confirmed to be stepping at ≥60 steps/s twice in a row

## Reproduce

Edit the `<update_rate>` inside the `multibeam_sonar` sensor block only — the same model
also defines `camera` and `depth_camera` sensors with their own `update_rate` tags — then
launch and measure.

Full write-up, raw CSVs and scripts:
[`notes/results/updaterate_2026-08-06/`](https://github.com/IOES-Lab/ROS2_Lyrical_MacOS_Native_AppleSilicon/tree/main/notes/results/updaterate_2026-08-06/)
