# Ocean-current Gauss-Markov and tidal validation — 2026-08-31

## Verdict

**FUNCTIONAL PASS within the bounded synthetic controls.**

Two previously open paths were exercised directly in Docker:

1. non-zero Gauss-Markov noise in the WorldPlugin;
2. harmonic tide propagation through the documented per-model path.

No real-ocean or coefficient-accuracy claim is made.

## Gauss-Markov noise

The noise-enabled control produced 400 global current messages and 100
stratified messages. All three global axes had 400 distinct values.

| axis | standard deviation |
|---|---:|
| X | 0.072814 |
| Y | 0.090647 |
| Z | 0.111639 |

The deterministic baseline remained exactly (1, 0, 0) in all 400 global
samples.

Evidence: [runtime/](runtime/) and [summary.json](summary.json).

## Tidal path

The first experiment compared only the WorldPlugin global and stratified
outputs. Even extreme harmonic parameters did not change those payloads. That
was initially interpreted as an unapplied feature, but source inspection
showed that this was the wrong oracle: DAVE transports tidal metadata through
StratifiedCurrentDatabase and applies it in each OceanCurrentModelPlugin.

A corrected end-to-end world placed two static models at the same depth:

- probe_no_tide: tide_oscillation=false;
- probe_tide: tide_oscillation=true.

Both received the same 12-layer database. The ROS wrapper delivered the
configured M2, S2 and N2 constituents to the model plugins.

| output | messages | X minimum | X maximum | distinct X values |
|---|---:|---:|---:|---:|
| no-tide control | 200 | 0.005000 | 0.005000 | 1 |
| tide-enabled model | 200 | 0.116522 | 0.623991 | 200 |

The paired payloads were not equal. This directly validates the following
route:

    OceanCurrentWorldPlugin tidal configuration
      -> OceanCurrentPlugin StratifiedCurrentDatabase
      -> OceanCurrentModelPlugin UpdateDatabase
      -> TidalOscillation::Initiate / Update
      -> /model/<namespace>/ocean_current

Evidence: [tidal_model_path/](tidal_model_path/),
[test_assets/tidal_model_path.world](test_assets/tidal_model_path.world), and
[source_audit.txt](source_audit.txt).

## Invalid attempts

- [invalid_host_ffmpeg_attempt/](invalid_host_ffmpeg_attempt/) did not start:
  the local Homebrew Gazebo binary referenced a removed ffmpeg dylib.
- [invalid_docker_plugin_path_attempt/](invalid_docker_plugin_path_attempt/)
  omitted the common install/lib plugin directory, so the two world plugins
  did not load.

Neither invalid attempt contributes to the verdict.

## Limits

- The harmonic values are intentionally extreme synthetic inputs.
- One static depth and 200 messages per tidal condition were compared.
- Noise variation was observed, but the full stochastic distribution was not
  statistically certified.
- Physical tidal-current accuracy, field-data agreement, multi-day behavior
  and hydrodynamic coefficient accuracy remain outside this result.
