# Combined Heavy-multibeam sonar and vehicle control

This closes the earlier execution gap by running the sonar-world candidate and the
BlueROV2 Heavy multibeam control stack in one derived container.

## Result

- `auto/`: **FAIL**. WGPU selected the Vulkan `llvmpipe` software adapter, then Gazebo
  reproduced the OGRE2 `CreateSampleTexture` / null-`memcpy` stack and exited 139.
  This run retained a final process exit instead of being manually terminated.
- `cpu_control/`: **FUNCTIONAL PASS in the tested scope**. The forced CPU sonar backend
  published a 513×301 PointCloud2, MAVROS entered MANUAL, force-armed, accepted 100
  manual-control messages, moved X by +1.348464 m, and disarmed.
- The CPU run's `parameter_bridge` later exited -11 during intentional SIGINT teardown.
  That is recorded separately and does not erase the completed runtime evidence.

The result is backend-dependent: it does not justify calling the combined path globally
PASS or globally FAIL.

Key artifacts: `auto/launch.log` and `auto/key_lines.txt` preserve the Gazebo child exit 139;
`auto/runner_note.txt` distinguishes the later wrapper timeout/status. The CPU result is in
`cpu_control/functional_summary.json` and `cpu_control/core_scope_note.txt`.
