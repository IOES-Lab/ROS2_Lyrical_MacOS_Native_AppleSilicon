# BlueROV sensor-contract audit — 2026-08-30

This audit checks the three BlueROV variants with ArduSub disabled so that model sensor contracts
are not confused with the separately validated autopilot control loop.  Runtime used the isolated
deferred-sonar Docker image; a manual camera bridge was added because the shipped robot configs do
not bridge camera images.

## Valid runtime result

| Variant | Odometry | Camera | bridged IMU | bridged magnetometer | default Gazebo IMU | sonar payload |
|---|---|---|---|---|---|---|
| `bluerov2` | PASS | PASS | silent | silent | PASS | n/a |
| `bluerov2_heavy` | PASS | PASS | silent | silent | PASS | n/a |
| `bluerov2_heavy_multibeam_sonar` | PASS | PASS | silent | silent | PASS | silent |

The IMU and magnetometer ROS names existed because bridge endpoints were created, but bounded echo
files contained no message.  All three default Gazebo IMU sensor paths emitted real `gz.msgs.IMU`
data.  The two base models in the runtime image omit an explicit IMU `<topic>`; the fifth model also
omits it.  None of the three model descriptors declares a magnetometer sensor although all three
configs bridge a magnetometer alias.

The fifth sonar result is scoped to this image's `dave_ocean_waves.world`, whose installed world has
the ordinary Sensors system but not `MultibeamSonarSystem`.  That is the already identified world-
composition omission.  Separate candidate evidence adds that system and validates sonar plus
MAVROS control; this audit intentionally preserves the distributed contract failure instead of
mixing patched and unpatched scopes.

## Source-scope correction

The first source inventory read the host overlay, where the earlier four-model IMU patch is already
present for `bluerov2` and `bluerov2_heavy`.  Runtime used image
`sha256:9a419bd753cf...`, whose corresponding descriptors have different hashes and do not include
those topic lines.  [`source/scope_comparison.json`](source/scope_comparison.json) records that
distinction.  Runtime verdicts are based on the image inventory and captured messages, not on the
differently patched host source.

An initial harness chose ROS domain IDs in 220–239; Fast DDS rejected IDs above its transport-port
limit before spawn.  Those outputs are retained under [`invalid_high_domain_attempt/`](invalid_high_domain_attempt/)
and excluded from the verdict.  The valid rerun used IDs 80–119.  The analyzer was also tightened
after `!rclpy.ok()` timeout text was initially mistaken for a message; each PASS now requires a
message-specific field signature.

## Scope

This establishes which configured message contracts actually publish in one Docker model run.
It does not re-test ArduSub/MAVROS control, sensor calibration, hardware-in-the-loop behavior or
real-vehicle accuracy.

## Evidence

- [`summary.json`](summary.json)
- [`runtime_summary.json`](runtime_summary.json)
- [`runtime/`](runtime/): captured messages and launch/topic inventories
- [`source/candidate_image_inventory.txt`](source/candidate_image_inventory.txt)
- [`source/scope_comparison.json`](source/scope_comparison.json)
- [`source/source_inventory.json`](source/source_inventory.json): host-overlay inventory, retained with scope warning
- [`scripts/analyze_runtime.py`](scripts/analyze_runtime.py)
- [`scripts/run_variant.sh`](scripts/run_variant.sh)
