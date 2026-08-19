<!-- 제출 대상: [`IOES-Lab/dave`](https://github.com/IOES-Lab/dave) — this is world-file content in `models/dave_worlds/worlds/`, unrelated to the WGPU sonar backend. Confirmed in the `naitikpahwa18/dave` `wgpu_integration` checkout at pinned commit `6aef91c`; worth a quick check against `IOES-Lab/dave`'s `ros2` branch (its default) before filing, but the world files are unlikely to differ.
     라벨:     `bug`
     원본:     notes/upstream/drafts/world-name-collision-issue-draft.md
     자동 생성: notes/upstream/make_submittable.py — 직접 고치지 말 것 -->

## 이슈 제목 (아래 한 줄을 제목 칸에 붙여넣기)

`dave_ocean_waves.world` and `dave_ocean_waves_sonar.world` both declare `<world name="oceans_waves">`, making their topics indistinguishable

## 이슈 본문 (아래 전체를 본문 칸에 붙여넣기)

---

## Summary

Two different world files ship with the same internal world name. Gazebo derives topic
namespaces from `<world name>`, not from the filename, so running both worlds
concurrently — or running one while inspecting the other — produces
`/world/oceans_waves/...` topics that cannot be attributed to either world.

This is not hypothetical. It caused a real misattributed performance measurement in our
own work (details below), which stood in our records for a week before being caught.

## Evidence

```bash
cd models/dave_worlds/worlds
for f in dave_ocean_waves.world dave_ocean_waves_sonar.world \
         dave_ocean_waves_sonar_integrated.world dave_multibeam_sonar.world; do
  printf '%-42s %s\n' "$f" "$(grep -o '<world name=[^>]*>' "$f" | head -1)"
done
```

Output:

| world file | `<world name>` |
|---|---|
| `dave_ocean_waves.world` | **`oceans_waves`** |
| `dave_ocean_waves_sonar.world` | **`oceans_waves`** |
| `dave_ocean_waves_sonar_integrated.world` | `oceans_waves_sonar_integrated` |
| `dave_multibeam_sonar.world` | `default` |

Verified identically on a macOS-native workspace and inside an Ubuntu 26.04 container.

## Why it matters

Anything keyed on the world name collides: `/world/<name>/stats`, `/world/<name>/control`,
`/world/<name>/scene/info`, and the corresponding services. A subscriber has no way to tell
which of the two worlds it is reading.

**Concretely, how this bit us.** On 2026-07-29 we sampled `/world/oceans_waves/stats` while
investigating `dave_multibeam_sonar`, believing that to be its topic. It is not —
`dave_multibeam_sonar.world` is `default`. Meanwhile a 4-hour `dave_ocean_waves` stability
run was executing in the same container. The resulting figure (RTF ~0.0018) was recorded
against the wrong world and propagated into a cross-platform performance comparison before
we caught it on 2026-08-03 and withdrew both.

The name collision is not the only reason that happened — we should have checked the world
name — but two files sharing a name made the wrong assumption easy to hold and hard to
notice.

## Suggested fix

Give each world file a distinct `<world name>`. The obvious choice is to match the filename:

```diff
 # dave_ocean_waves_sonar.world
-<world name="oceans_waves">
+<world name="oceans_waves_sonar">
```

Leaving `dave_ocean_waves.world` as `oceans_waves` keeps the more commonly used world's
topics stable and changes only the one that duplicates it.

Note this is a breaking change for anyone with hardcoded `/world/oceans_waves/...` paths
pointing at the sonar world, so it may warrant a changelog note.

## Related observation, lower priority

`dave_multibeam_sonar.world` declares `<world name="default">`. That is valid and unique,
but `default` is the name Gazebo uses for an unnamed world, so `/world/default/stats` gives
no indication of which world is running. A descriptive name would be easier to work with,
though this is a usability point rather than a bug.

## Environment

- `naitikpahwa18/dave`, branch `wgpu_integration`, pinned commit `6aef91c`
- Checked on macOS (Apple Silicon, native) and Ubuntu 26.04 aarch64 (Docker)
- ROS 2 Lyrical + Gazebo Jetty 10.4
- The world files are plain SDF; nothing here is distro- or platform-specific
