# macOS stock DVL crash diagnosis and controlled workaround

## Diagnosis

LLDB stopped on `EXC_BAD_ACCESS` at address 0 in
`gz::sim::v10::systems::SensorsPrivate::WaitForInit()+560`. The exact
`gz-sim10_10.4.0` source shows why this is macOS-specific:

1. `WaitForInit()` skips `renderUtil.Init()` on Apple because render-engine
   initialization must happen on the main thread.
2. `Sensors::Update()` performs that main-thread initialization only when one of the
   standard camera/lidar component types is present.
3. The DVL is a custom rendering sensor managed by `DopplerVelocityLogSystem`, and by
   itself does not satisfy that standard-sensor component test.
4. The render thread then obtains a null scene and dereferences it.

## Workaround control

`dvl_with_init_camera.sdf` adds one hidden static 8×8 camera to the official DVL world.
With that initializer present on the same Apple M2 machine, `/dvl/velocity` published a
complete four-beam bottom-lock message, Gazebo stayed alive through capture, and exited
cleanly after deliberate shutdown.

This proves an actionable workaround, not an upstream fix. The distributed stock world
still crashes until Gazebo changes its initialization trigger or the world supplies a
recognized rendering sensor.

Primary source references:

- <https://github.com/gazebosim/gz-sim/blob/gz-sim10_10.4.0/src/systems/sensors/Sensors.cc>
- <https://github.com/gazebosim/gz-sim/blob/gz-sim10_10.4.0/src/systems/dvl/DopplerVelocityLogSystem.cc>

Key artifacts: `lldb_delayed_attach.log`, `Sensors_gz-sim10.cc`,
`Sensors_macos_Update_excerpt.txt`, `dvl_with_init_camera.sdf`, and
`init_camera_dvl_message.txt`.
