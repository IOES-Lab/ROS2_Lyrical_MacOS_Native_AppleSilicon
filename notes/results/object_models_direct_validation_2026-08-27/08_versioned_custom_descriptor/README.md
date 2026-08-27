# Custom Object Models extension check

This check exercised the source-package extension path that the corrected Wiki page
describes. It did not modify the read-only DAVE checkout.

## Test asset

The copied `dave_object_models` package received one additional descriptor:

```text
description/codex_versioned_block/model.config
description/codex_versioned_block/model.sdf
```

The wrapper requested this Fuel URI:

```text
https://fuel.gazebosim.org/1.0/hmoyen/models/mossy_cinder_block/1
```

The retained source is under [`test_assets/`](test_assets/), and the copied package
source is under [`overlay_ws/src/dave_object_models/`](overlay_ws/src/dave_object_models/).

## Build and spawn result

- **Mac native: PASS.** The overlay became the active `dave_object_models` prefix,
  the descriptor was installed, `dave_object.launch.py` created
  `codex_versioned_block`, and simulation time advanced.
- **Docker: PASS.** The same copied source package built in the container, became the
  active prefix, created the same model name, and simulation time advanced.
- The resolved ten-file Fuel caches had identical relative paths and SHA-256 values
  across Mac and Docker.

Evidence:

- [`mac_build.log`](mac_build.log), [`mac_active_prefix.txt`](mac_active_prefix.txt)
- [`mac_launch_retry/`](mac_launch_retry/)
- [`docker_build.log`](docker_build.log),
  [`docker_active_prefix.txt`](docker_active_prefix.txt)
- [`docker_launch/`](docker_launch/)

## The `/1` suffix is not an effective pin here

Both platform clients accepted the URI and downloaded the current version-1 cache,
but both also emitted this warning:

```text
Requested version [1], but currently only the model's latest (tip) version is supported.
```

Therefore the successful launches validate the **custom descriptor build/install/spawn
workflow**, not immutable version pinning. With these clients, appending `/1` cannot be
cited as a reproducibility guarantee. Vendoring or an independently verified content
lock is still required for offline or immutable reproduction.

Evidence: [`version_probe_mac/`](version_probe_mac/) and
[`version_probe_docker/`](version_probe_docker/).

## Limits

- This test added one descriptor only.
- It did not upload content to a Fuel account or use the Resource Spawner GUI.
- It did not validate visual fidelity, collision, inertial/contact physics or dynamics.
- It did not establish offline operation.
