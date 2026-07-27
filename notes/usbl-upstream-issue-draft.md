# Upstream issue draft — USBL Gazebo server crash on `sigma=0`

**Status:** Draft, not yet filed. Ready to paste into a GitHub Issue.

**Suggested target repo:** [`IOES-Lab/dave`](https://github.com/IOES-Lab/dave) (the plugin code
in question, `UsblTransponder.cc`, is core DAVE code unrelated to the WGPU sonar backend —
found via `naitikpahwa18/dave`'s `wgpu_integration` branch, but the bug and the buggy line are
not specific to that fork/branch. Worth a quick `git blame`/diff check against
`IOES-Lab/dave`'s `main` before filing, to confirm the exact line number still matches, but the
logic itself is unlikely to differ).

**Suggested labels:** `bug`, `crash`

---

## Title

`UsblTransponder` plugin crashes the Gazebo server when a world file sets `<sigma>0.0</sigma>`

## Summary

The Gazebo **server** process (not the GUI client) aborts with `SIGABRT` when a world file
configures a `UsblTransponder` plugin instance with `<sigma>0.0</sigma>`. The included
`usbl_tutorial.world` demo world itself ships with this exact configuration on both of its
`UsblTransponder` instances, so the crash reproduces out of the box from a fresh checkout —
no custom world file needed.

This was originally reported/investigated as a "GUI crash" because the symptom (the demo
failing to come up) was observed via a GUI launch; the actual failure is server-side and
reproduces identically with `gui:=false`.

## Environment

- ROS 2 Lyrical, Gazebo Jetty (also expected on Jazzy/Harmonic and other libstdc++ builds
  where `_GLIBCXX_ASSERTIONS`-style checks are enabled — this is a libstdc++ contract
  violation, not a Gazebo- or ROS-distro-specific bug)
- Ubuntu 26.04, gcc-15 / libstdc++ (Docker, arm64)
- Reproduced on both Docker and macOS-native Gazebo Jetty builds

## Steps to reproduce

```bash
ros2 launch dave_demos dave_sensor.launch.py \
  namespace:=usbl world_name:=usbl_tutorial gui:=false headless:=true
```

## Observed behavior

```
[gazebo-1] /usr/include/c++/15/bits/random.h:2138: std::normal_distribution<_RealType>::param_type::param_type(_RealType, _RealType) [with _RealType = double]: Assertion '_M_stddev > _RealType(0)' failed.
[gazebo-1] Aborted
[ERROR] [gazebo-1]: process has died [pid 3148, exit code 134, cmd 'ruby .../gz sim .../usbl_tutorial.world -s -r --force-version 10'].
```

Exit code 134 = `SIGABRT`. The Gazebo server dies within a few seconds of startup; no GUI is
involved.

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
models), overriding the safe default. `std::normal_distribution`'s constructor requires
`stddev > 0` strictly per the C++ standard; libstdc++ builds with debug assertions enabled
enforce this at runtime with an `abort()`, which is what kills the Gazebo server process.

Whether the assertion is compiled in depends on the specific libstdc++ build's assertion
flags — this may be why the bug wasn't caught on other platforms/toolchains where the check
is compiled out (in which case `sigma=0` would silently construct an actually-invalid
distribution object instead of crashing, arguably worse).

## Suggested fix

Guard the distribution construction against non-positive sigma, e.g.:

```cpp
if (this->dataPtr->m_noiseSigma <= 0)
{
  gzwarn << "[UsblTransponder] sigma must be > 0; ignoring configured value ("
         << this->dataPtr->m_noiseSigma << ") and disabling noise for this instance."
         << std::endl;
  // skip noise application entirely, or clamp to a small positive epsilon --
  // maintainer's call on which behavior is more correct for this plugin
}
else
{
  std::normal_distribution<> d(this->dataPtr->m_noiseMu, this->dataPtr->m_noiseSigma);
  // ... existing logic
}
```

Separately, `usbl_tutorial.world`'s own `<sigma>0.0</sigma>` should probably be reconsidered —
it's unclear whether zero noise was ever actually reachable/intended, or whether it was meant
to approximate "no noise" without realizing the constructor doesn't accept exactly zero.

## What we did as a workaround (not a substitute for the real fix)

In our own fork, we patched the world file's `<sigma>0.0</sigma>` → `<sigma>0.0001</sigma>` to
unblock testing without touching the plugin itself. This changes the demo's runtime behavior
from "exactly zero noise" to "near-zero noise" and does **not** protect against any other world
file or user config that sets `sigma=0` or `sigma<0` — the plugin-level fix above is still
needed for that.

## Additional context

Full investigation notes, including the earlier (superseded) hypothesis that this was a
GUI/rendering issue, are available on request if useful for triage.
