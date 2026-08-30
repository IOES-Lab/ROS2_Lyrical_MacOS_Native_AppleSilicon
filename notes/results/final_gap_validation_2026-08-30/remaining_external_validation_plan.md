# Validation paths that require a different environment or account

The 2026-08-30 local audit exhausted the bounded checks available on the attached Apple-M2
Mac and its ARM64 Docker Desktop VM. The items below are executable validation plans, not
claims that those environments passed.

## NVIDIA CUDA and hardware WGPU

**Required:** a Linux host with an NVIDIA GPU and driver, NVIDIA Container Toolkit, and enough
storage to rebuild the current image / sonar packages. The present Mac has no CUDA device and
Docker Desktop exposes neither NVIDIA nor `/dev/dri` hardware.

1. Confirm host and container visibility with NVIDIA's official sample:

   ```bash
   nvidia-smi
   docker run --rm --runtime=nvidia --gpus all ubuntu nvidia-smi
   ```

2. Build the pinned DAVE / multibeam sources with `nvcc` present. Preserve CMake's detected
   toolkit and architecture, the source commit, and the generated backend binaries.
3. Run the same controlled 3.99 m planar scene on CPU, CUDA and hardware WGPU. Capture at least
   five raw-sonar frames per backend and compare expected-bin rank, peak range and PointCloud2.
4. Run the Heavy-multibeam sonar + ArduSub/MAVROS control integration with explicit CUDA and
   explicit hardware WGPU. Do not infer either result from software `llvmpipe`.

Official prerequisite and sample workload:
<https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/sample-workload.html>

## Windows / WSL

**Required:** a real Windows host or VM. The attached machine can exercise Microsoft's RDP
client, but that is not a Windows ROS/Gazebo runtime.

1. Follow the Lyrical source-build page for Windows rather than reusing the Ubuntu apt path.
2. Record compiler, ROS, Gazebo, GPU-driver and middleware versions.
3. Re-run the 18-world matrix, then the selected sensor contract tests. Keep Windows-native and
   WSL results separate.
4. For WSL GPU tests, first pass the NVIDIA container sample above; a successful `docker run`
   without `nvidia-smi` is not GPU evidence.

Official ROS 2 Lyrical platform entry:
<https://docs.ros.org/en/lyrical/Installation/Alternatives/Latest-Development-Setup.html>

## Autopilot hardware / HIL

**Required:** a supported ArduPilot flight controller, safe bench setup, GCS link and an operator
who can handle arming and failsafes. No physical controller is attached here.

1. Start with ArduPilot's Simulation on Hardware flow and a board-specific simulation-enabled
   firmware. Keep actuators physically disconnected or otherwise made safe.
2. Validate GCS/MAVLink connectivity, parameter loading, arming checks and failsafes before
   connecting an external physics model.
3. For DAVE as the external model, use ArduPilot's documented JSON simulation path and record
   timestamp, IMU, pose, velocity and actuator exchange in both directions.
4. Repeat the bounded arm/control/disarm test and compare with SITL; do not call this physical
   vehicle validation without real actuators and water trials.

Official method:
<https://ardupilot.org/dev/docs/sim-on-hardware.html> and
<https://ardupilot.org/dev/docs/sitl-with-JSON.html>

## Gazebo Fuel account upload and immutable resource workflow

**Required:** the user's own Gazebo Fuel account and private token. This audit did not create an
account or upload to a remote service.

1. Create a private token and keep it outside the repository.
2. Upload a disposable private model with:

   ```bash
   gz fuel upload -m /path/to/model --header 'Private-token: <TOKEN>'
   ```

3. Download the returned version into an isolated cache, verify `model.config` / `model.sdf`,
   hash every file, and spawn it in a progressing world.
4. Update the model, download both explicit versions, and prove whether the tested Jetty client
   respects the requested version. If not, vendor the files or pin an independently verified
   content hash instead of calling a URL immutable.
5. Delete the disposable private resource after the test if project policy requires it.

Official Fuel CLI documentation:
<https://gazebosim.org/libs/fuel_tools/> and
<https://gazebosim.org/api/fuel_tools/10/cmdline.html>

## Physical and scientific validation

**Required:** calibrated reference instruments and controlled targets / water conditions. Source
inspection and simulation-to-simulation agreement cannot establish real-world accuracy.

- multibeam: known-range / known-reflectivity targets across distance, angle and material;
- camera: calibrated color chart and attenuation/background measurements across controlled
  turbidity and distance;
- pressure: traceable pressure/depth reference and temperature/salinity conditions;
- DVL and USBL: surveyed geometry and independent velocity/range/position reference;
- ocean current and vehicle models: measured current profile, vehicle coefficients, actuator
  calibration and repeated trajectories.

Pre-register tolerances, repeat count and failure criteria. Preserve raw data and calibration
certificates; do not promote one controlled simulation scene to general physical accuracy.
