# Spherical Coordinates validation

This kit exercises all four DAVE `SphericalCoords` ROS services against a
minimal world. It does not modify the DAVE checkout.

On the tested Mac migration workspace, the installed plugin library directory
must be discoverable through `GZ_SIM_SYSTEM_PLUGIN_PATH`: the generated DAVE
environment points at `lib/dave_ros_gz_plugins/`, while
`libSphericalCoords.dylib` is installed in `lib/`. The merged Docker install
also generates the nested Gazebo path, but its `install/lib` is already on
`LD_LIBRARY_PATH`, so Docker did not require a manual Gazebo-path override.

```bash
bash notes/experiments/spherical_coordinates/run.sh mac /absolute/output/path
bash notes/experiments/spherical_coordinates/run.sh docker /absolute/output/path
python3 notes/experiments/spherical_coordinates/summarize_results.py /absolute/result/root
```

The runner checks get/set, three Cartesian-to-spherical-to-Cartesian
round-trips, the exact Wiki example, and non-finite/range-invalid inputs.
