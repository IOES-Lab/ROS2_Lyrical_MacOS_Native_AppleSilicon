# Upstream issue draft — seven world files fall into three duplicate `<world name>` groups

**Status:** Draft, not yet filed. Ready to paste into a GitHub Issue.

**Suggested target repo:** [`IOES-Lab/dave`](https://github.com/IOES-Lab/dave) — this is
world-file content in `models/dave_worlds/worlds/`, unrelated to the WGPU sonar backend.
Confirmed in the `naitikpahwa18/dave` `wgpu_integration` checkout at pinned commit
`6aef91c`; check the current `IOES-Lab/dave` `ros2` branch immediately before filing.

**Suggested labels:** `bug`

---

## Title

Seven DAVE world files fall into three duplicate `<world name>` groups, making their topic namespaces ambiguous

## Summary

The 18 distributed world files expose only 14 distinct internal names. Seven files fall
into three duplicate-name groups. Gazebo derives `/world/<name>/...` topic and service
namespaces from `<world name>`, not from the filename, so concurrent or leftover runs can
be misattributed or rejected as another world of the same name.

This is not hypothetical. One collision contributed to a real misattributed performance
measurement in our work, which stood in our records for a week before being caught.

## Evidence

```bash
cd models/dave_worlds/worlds
for f in *.world; do
  printf '%-46s %s\n' "$f" "$(grep -o '<world name=[^>]*>' "$f" | head -1)"
done | sort
```

The duplicate groups are:

| internal name | world files |
|---|---|
| `oceans_waves` | `dave_ocean_waves.world`, `dave_ocean_waves_mossy_ground.world`, `dave_ocean_waves_sonar.world` |
| `default` | `dave_multibeam_sonar.world`, `usbl_tutorial.world` |
| `dvl_world` | `dvl_world.world`, `new_dvl.world` |

The filename/internal-name inventory was identical in the macOS source checkout, Ubuntu
26.04 Docker source checkout, and Docker installed package. Full retained evidence:
[`world_models_audit_2026-08-27`](../../results/world_models_audit_2026-08-27/).

## Why it matters

Anything keyed on the world name can collide: `/world/<name>/stats`,
`/world/<name>/control`, `/world/<name>/scene/info`, and the corresponding services. A
subscriber cannot identify the source world from that namespace alone.

**Concretely, how this bit us.** On 2026-07-29 we sampled
`/world/oceans_waves/stats` while investigating `dave_multibeam_sonar`, believing that to
be its topic. It is not: `dave_multibeam_sonar.world` declares `default`. Meanwhile a
`dave_ocean_waves` stability run was active in the same container. The resulting RTF
figure was assigned to the wrong world and propagated into a comparison before it was
withdrawn on 2026-08-03.

The collision is not the only reason the mistake happened — the running world should have
been identified independently — but duplicate internal names make that failure easier and
make concurrent launches ambiguous by construction.

## Suggested fix

Give every distributed file a distinct internal world name, preferably matching its
filename without `.world`. For example:

```diff
 # dave_ocean_waves_sonar.world
-<world name="oceans_waves">
+<world name="dave_ocean_waves_sonar">

 # usbl_tutorial.world
-<world name="default">
+<world name="usbl_tutorial">

 # new_dvl.world
-<world name="dvl_world">
+<world name="new_dvl">
```

This changes `/world/<name>/...` paths, so the release notes should call out the namespace
change and any launch/tests with hardcoded world names should be updated together.

## Environment and scope

- `naitikpahwa18/dave`, branch `wgpu_integration`, pinned commit `6aef91c`
- Checked on macOS Apple Silicon and Ubuntu 26.04 aarch64 Docker
- ROS 2 Lyrical + Gazebo Jetty 10.4
- Plain SDF inventory; the naming result is not ROS-distro- or CPU-architecture-specific
- Only `dave_ocean_waves` was rerun during the final inventory audit; this issue is about
  static internal names, not a claim that all 18 worlds were feature-tested that day
