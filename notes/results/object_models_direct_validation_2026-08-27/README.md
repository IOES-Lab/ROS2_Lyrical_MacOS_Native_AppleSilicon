# Object Models direct validation — 2026-08-27

## Verdict

- **Packaged `mossy_cinder_block` path: FUNCTIONAL PASS in the tested scope.**
  The exact Wiki command spawned the only object descriptor shipped by this DAVE
  checkout on both Mac native and Docker/RDP. The model appeared in the world and
  simulation time advanced.
- **Generic Fuel include example: FUNCTIONAL PASS for download and spawn on Mac and Docker.**
  The page's exact Teledyne Fuel URL resolved in isolated caches, its SDF validated,
  and the model appeared in progressing minimal worlds on both platforms.
- **Custom descriptor source workflow: FUNCTIONAL PASS on Mac and Docker.** A copied
  source package with `description/codex_versioned_block/` built, installed and spawned
  on both platforms. The attempted `/1` Fuel pin is **not effective** with these clients:
  both warn that only the latest tip is supported.
- **Failure reporting: PARTIAL.** A deliberately missing descriptor caused Gazebo to
  report that it could not read the file and no entity appeared, but `ros_gz_sim
  create` still exited zero and the launch handler printed `Object Model Uploaded`.
  The success text is therefore not proof that an object exists.

The source revision was
`6aef91c823af5da073329b84ba617b572965e79e`. The object package and its launch
files were unmodified; other migration changes in the DAVE worktree are listed in
[`source/mac_environment.txt`](source/mac_environment.txt).

## Packaged object inventory and resolution

This checkout contains one packaged object descriptor:

```text
mossy_cinder_block
```

`dave_object.launch.py` resolves
`dave_object_models/description/<namespace>/model.sdf`, and the installed package
hook prepends the package share directory to `GZ_SIM_RESOURCE_PATH` on both tested
platforms. The shipped wrapper SDF contains an unversioned Fuel URI for
`mossy_cinder_block`.

The exact Wiki command was:

```bash
ros2 launch dave_demos dave_object.launch.py \
  namespace:=mossy_cinder_block paused:=false
```

### Mac native

The Fuel cache was empty before launch. The command downloaded the object and
reported entity creation; `gz model --list` then contained both `ground_plane` and
`mossy_cinder_block`. The recorded pose named model ID 10, and the stats sample
contained `sim_time=122.517 s` and `iterations=122517`.

Evidence: [`01_mac_wiki_exact/`](01_mac_wiki_exact/).

### Docker/RDP

The same command used the container's existing Fuel cache, produced the same model
list, and returned progressing stats (`iterations` 8069→8070 in the committed
sample). The Mac and Docker caches contain the same ten relative files with the
same SHA-256 values.

Evidence: [`02_docker_wiki_exact/`](02_docker_wiki_exact/).

The committed `gz sdf -k` output for the small wrapper SDF shows that this standalone
CLI invocation lacked a Fuel URI resolver callback. That output is **not** treated as
an invalid-descriptor result: both runtime launches resolved the URI, and the
downloaded `model.sdf` itself validates.

## Missing-descriptor negative control

The lower-level upload launch was called with
`namespace:=definitely_missing_object` while the validated Docker world was running.
Gazebo logged `Error finding file` and `Unable to read file`, and the model list did
not contain that name. Nevertheless, the client logged `Entity creation successful`,
exited with status 0, and the launch event handler printed `Object Model Uploaded`.

Evidence:

- client and handler output:
  [`03_docker_missing_descriptor_negative_control/`](03_docker_missing_descriptor_negative_control/)
- server-side file errors:
  [`02_docker_wiki_exact/launch_after_negative_control.log`](02_docker_wiki_exact/launch_after_negative_control.log)

The separate full-wrapper attempt in
[`04_docker_missing_descriptor_exact_wrapper/`](04_docker_missing_descriptor_exact_wrapper/)
never discovered a world service and is marked inconclusive. It is not used to
support the false-success finding.

## Generic Fuel URL example

The page also shows this URL:

```text
https://fuel.gazebosim.org/1.0/hmoyen/models/teledyne_whn_uuvsim_bare_model
```

An isolated direct download returned five files and a valid resolved SDF:
[`05_fuel_snippet_direct_download/`](05_fuel_snippet_direct_download/). Separate
minimal worlds then spawned `teledyne_whn_uuvsim` and advanced simulation time on Mac
and Docker:

- Mac: [`06_fuel_snippet_spawn_mac/`](06_fuel_snippet_spawn_mac/)
- Docker: [`07_fuel_snippet_spawn_docker/`](07_fuel_snippet_spawn_docker/)

The two resolved SDFs differ only by trailing whitespace in one XML comment. The Mac
run emitted four unsupported-LIDAR warnings. The Docker server-only world did not load
a Sensors system. These tests therefore establish **model retrieval and spawn**, not
operation of the bundled sensor elements.

## Custom descriptor and version-suffix check

A copied `dave_object_models` source package was extended with
`description/codex_versioned_block/`, rebuilt and sourced as an overlay. The normal
`dave_object.launch.py` path created that model and advanced simulation time on Mac and
Docker. This directly validates the corrected source-package extension workflow.

The wrapper requested `mossy_cinder_block/1`, but direct Fuel probes on both platforms
warned that the requested version is ignored because only the latest tip is supported.
The `/1` suffix is therefore not an immutable pin in this environment. Full evidence:
[`08_versioned_custom_descriptor/`](08_versioned_custom_descriptor/).

## Scope and limits

- One shipped descriptor and one added test descriptor were exercised.
- The generic Fuel example was spawned in minimal worlds on Mac and Docker.
- The tests used Fuel content resolved on 2026-08-27. The shipped URIs are unversioned,
  and the current clients warn that a `/1` request still resolves the latest tip, so
  future remote content may differ unless it is vendored or independently locked.
- Visual mesh fidelity, collision geometry, inertial properties, contact physics,
  and quantitative dynamics were not validated.
- Uploading a new model through a Fuel account and using the Gazebo Resource Spawner
  GUI were not tested.
- The DVL command later on the Notion page belongs to the DVL plugin scope: it passes
  in Docker but the current Mac Jetty sensor render thread crashes. See
  [`../dvl_direct_validation_2026-08-26/`](../dvl_direct_validation_2026-08-26/).

Machine-readable verdict: [`summary.json`](summary.json).
