# CMake / API migration patterns — Harmonic → Jetty

Recurring patterns found while porting `dave_lyrical_jetty_migration_mac.diff` (base commit `6aef91c`, branch `wgpu_integration`). Reproduced identically on both macOS and Docker/Ubuntu 26.04.

## 1. Versioned package names dropped

| Harmonic | Jetty |
|---|---|
| `find_package(gz-cmake3 REQUIRED)` | `find_package(gz-cmake 5 REQUIRED)` |
| `find_package(gz-sim8 REQUIRED)` | `find_package(gz-sim 10 REQUIRED)` |
| `find_package(gz-msgs10 REQUIRED)` | `find_package(gz-msgs 12 REQUIRED)` |
| `find_package(gz-plugin2 ...)` | `find_package(gz-plugin 4 ...)` |
| `find_package(gz-common5 ...)` | `find_package(gz-common 7 ...)` |
| `find_package(gz-sensors8 ...)` | `find_package(gz-sensors 10 ...)` |
| `find_package(gz-rendering8 ...)` | `find_package(gz-rendering 10 ...)` |
| `find_package(gz-transport13 ...)` | `find_package(gz-transport 15 ...)` |
| target `gz-sim8::gz-sim8` | target `gz-sim::gz-sim` |

## 2. `ament_target_dependencies` removed

```cmake
# Before (Harmonic)
ament_target_dependencies(MyPlugin rclcpp std_msgs geometry_msgs)
# After (Jetty)
target_link_libraries(MyPlugin
  rclcpp::rclcpp
  ${std_msgs_TARGETS}
  ${geometry_msgs_TARGETS}
)
```

## 3. Boost `COMPONENTS system` no longer needed

**Corrected 2026-07-23 (caught in review):** the original version of this note conflated two
separate Boost.System facts. Boost.System has actually been header-only since **Boost 1.69**
(2018) — `<boost/system/error_code.hpp>` stopped needing a compiled library that long ago. What
actually broke the build here is that **Boost 1.89** removed the small compatibility *stub*
library that older code (including some CMake `find_package(Boost COMPONENTS system)` calls) had
been quietly linking against for backward compatibility — once that stub was gone, requesting
`system` as a component started failing outright rather than silently doing nothing. See the
[Boost.System docs](https://www.boost.org/doc/libs/latest/libs/system/doc/html/system.html) for
the version history. Fix is the same either way:

```cmake
find_package(Boost REQUIRED)   # not COMPONENTS system
```

## 4. `gz::math::SphericalCoordinates` API change (gz-math9)

The only C++ source change needed (`dave_ros_gz_plugins/src/SphericalCoords.cc`). `Vector3d` → `CoordinateVector3` wrapped in `std::optional`.

```cpp
// Before
gz::math::Vector3d scVec = gz::math::Vector3d(lat, lon, alt);
gz::math::Vector3d cartVec = coords->LocalFromSphericalPosition(scVec);

// After
gz::math::Angle lat, lon;
lat.SetDegree(request->latitude_deg);
lon.SetDegree(request->longitude_deg);
auto scVec = gz::math::CoordinateVector3::Spherical(lat, lon, request->altitude);
auto cartOpt = coords->LocalFromSphericalPosition(scVec);
gz::math::Vector3d cartVec = gz::math::Vector3d::Zero;
if (cartOpt && cartOpt->AsMetricVector()) cartVec = *cartOpt->AsMetricVector();
```

## 5. `multibeam_sonar_system` missing `package.xml` dependencies

`CMakeLists.txt` pulls the neighboring `multibeam_sonar` package via `add_subdirectory`, but `package.xml` never declared it — race condition under parallel colcon builds, independent of ROS distro. Fixed with 7 added `<depend>` tags: `wgpu_vendor`, `rclcpp`, `sensor_msgs`, `marine_acoustic_msgs`, `cv_bridge`, `image_transport`, `pcl_conversions`.

## 6. `gui`/`headless` launch argument gating (runtime)

`dave_sensor.launch.py` / `dave_robot.launch.py` gate all of Gazebo behind `condition=IfCondition(gui)`. `gui:=false` disables Gazebo entirely. Correct headless invocation: `gui:=true headless:=true`.

## 7. `ogre2` → `ogre` as a sonar workaround (Docker only)

```bash
sed -i 's/ogre2/ogre/g' world_file.world   # both render_engine and engine tags
```

**Scope correction 2026-08-21.** This section used to be headed "OGRE2 unavailable on this
OS/arch", which later evidence does not support: a stock `gpu_lidar` runs on `ogre2` in the same
container, and the DAVE sonar reaches `Ogre2Scene::PreRender` before segfaulting — both impossible
if the plugin were missing. The patch works around a **sonar-specific** OGRE2 crash, not an absent
renderer.

**OGRE1 needs a real X display**, and `xvfb-run -a` is a plausible way to supply one that **was
never tried here** — do not read it as verified. What was verified is an authorised connection to
the container's live xrdp X server:

```bash
docker exec -u docker -e DISPLAY=:10 -e XAUTHORITY=/home/docker/.Xauthority ...
```

`DISPLAY` alone is not enough — a 2026-08-03 attempt set it without `XAUTHORITY`, ran as root, and
was refused. See [`results/docker_sonar_x_display_2026-08-07/`](results/docker_sonar_x_display_2026-08-07/).

## 8. `xrdp` group permission (RDP screen setup only)

```bash
usermod -aG root xrdp
pkill -9 -f xrdp && rm -f /run/xrdp/*.pid
/usr/sbin/xrdp-sesman && service xrdp start
```

## 9. ArduSub SITL build vs. Python 3.14 (BlueROV2 only)

See [`ardusub-sitl-setup.md`](setup/ardusub-sitl-setup.md).
