# Upstream issue draft — USBL Gazebo server crash on `sigma=0`

**Status:** Draft, not yet filed. Ready to paste into a GitHub Issue.

**Suggested target repo:** [`IOES-Lab/dave`](https://github.com/IOES-Lab/dave) (the plugin code
in question, `UsblTransponder.cc`, is core DAVE code unrelated to the WGPU sonar backend —
found via `naitikpahwa18/dave`'s `wgpu_integration` branch, but the bug and the buggy line are
not specific to that fork/branch. Worth a quick `git blame`/diff check against
`IOES-Lab/dave`'s `ros2` branch (its default) before filing, to confirm the exact line number still matches, but the
logic itself is unlikely to differ).

**Suggested labels:** `bug`, `crash`

---

## Title

`UsblTransponder` plugin crashes the Gazebo server when a world file sets `<sigma>0.0</sigma>`

## Summary

On Docker/libstdc++, the Gazebo **server** process (not the GUI client) aborts with `SIGABRT`
when a world file configures a `UsblTransponder` plugin instance with `<sigma>0.0</sigma>`. The included
`usbl_tutorial.world` demo world itself ships with this exact configuration on both of its
`UsblTransponder` instances, so the crash reproduces out of the box from a fresh checkout —
no custom world file needed.

This was originally reported/investigated as a "GUI crash" because the symptom (the demo
failing to come up) was observed via a GUI launch; the Docker failure is server-side and
reproduces without a GUI. Direct 2026-08-27 controls also showed that macOS/libc++ accepts
the same literal zero and returns finite near-exact coordinates. That platform difference
does not make the input portable; it shows why the plugin must handle zero explicitly.

## Environment

- ROS 2 Lyrical, Gazebo Jetty
- Ubuntu 26.04, gcc-15 / libstdc++ (Docker, arm64)
- Docker/libstdc++: abort on the first ping, exit 134
- macOS arm64/libc++: finite output for the same literal-zero control

## Steps to reproduce

```bash
ros2 launch dave_demos dave_world.launch.py \
  world_name:=usbl_tutorial
```

## Observed behavior

```
[gazebo-1] /usr/include/c++/15/bits/random.h:2138: std::normal_distribution<_RealType>::param_type::param_type(_RealType, _RealType) [with _RealType = double]: Assertion '_M_stddev > _RealType(0)' failed.
[gazebo-1] Aborted
[ERROR] [gazebo-1]: process has died [pid 3148, exit code 134, cmd 'ruby .../gz sim .../usbl_tutorial.world -s -r --force-version 10'].
```

Exit code 134 = `SIGABRT`. The Gazebo server dies within a few seconds of startup; no GUI is
involved.

The abort occurs on the first interrogation ping, not merely while loading the world. On
macOS/libc++, the same world and ping sequence returned finite data instead of aborting.

## Root cause

`gazebo/dave_gz_sensor_plugins/src/UsblTransponder.cc`, around line 263:

```cpp
std::normal_distribution<> d(this->dataPtr->m_noiseMu, this->dataPtr->m_noiseSigma);
```

`m_noiseSigma` is read directly from the world file's `<sigma>` SDF parameter with no
validation:

```cpp
this->dataPtr->m_noiseSigma = _sdf->Get<double>("sigma");
```

The plugin's own compiled-in default (`m_noiseSigma = 1.0`) is safe, but
[`usbl_tutorial.world`](https://github.com/IOES-Lab/dave/search?q=usbl_tutorial) explicitly
sets `<sigma>0.0</sigma>` on both of its `UsblTransponder` instances (`sphere` and `sphere2`
models), overriding the safe default. The standard distribution has a strictly positive
standard-deviation precondition. The tested libstdc++ build enforces it with an assertion
and abort; the tested libc++ build accepted zero and returned finite values. Relying on either
library's behavior leaves the plugin non-portable.

## Suggested fix

Handle zero and negative values before constructing the distribution, e.g.:

```cpp
if (this->dataPtr->m_noiseSigma < 0)
{
  gzerr << "[UsblTransponder] sigma must be non-negative" << std::endl;
  return;  // or fail configuration using the project's preferred mechanism
}
else if (this->dataPtr->m_noiseSigma == 0)
{
  // Return the configured mean directly; do not construct the distribution.
}
else
{
  std::normal_distribution<> d(this->dataPtr->m_noiseMu, this->dataPtr->m_noiseSigma);
  // ... existing logic
}
```

This preserves the tutorial world's apparent intent that zero means "no noise" while rejecting
negative values explicitly.

## What we did as a workaround (not a substitute for the real fix)

In our own fork, we patched the world file's `<sigma>0.0</sigma>` → `<sigma>0.0001</sigma>` to
unblock testing without touching the plugin itself. This changes the demo's runtime behavior
from "exactly zero noise" to "near-zero noise" and does **not** protect against any other world
file or user config that sets `sigma=0` or `sigma<0` — the plugin-level fix above is still
needed for that.

## Additional context

Full investigation notes and the Mac/Docker direct evidence, including common/individual
routing controls and the earlier superseded GUI hypothesis, are available on request.
