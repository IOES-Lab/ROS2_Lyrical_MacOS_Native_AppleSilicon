# ROS 2 Lyrical Native Installation on macOS Apple Silicon

## Purpose

This repository documents the native installation process of ROS 2 Lyrical and Gazebo Jetty on macOS Apple Silicon.

The long-term goal is to test whether DAVE ROS2, currently documented for ROS 2 Jazzy and Gazebo Harmonic, can be updated and tested in a ROS 2 Lyrical / Gazebo Jetty environment.

## Environment

* macOS version: 15.7.3
* Architecture: arm64
* Xcode path: /Applications/Xcode.app/Contents/Developer
* Homebrew path: /opt/homebrew
* Python version: 3.14.5
* Git version: 2.50.1
* ROS 2 version: Lyrical
* Gazebo version: Jetty

## Progress Log

| Date       | Task                                     | Result | Notes                                                                      |
| ---------- | ---------------------------------------- | ------ | -------------------------------------------------------------------------- |
| 2026-06-26 | Repository cloned                        | Done   | Empty repository warning appeared because the repository had no files yet. |
| 2026-06-26 | Environment checked                      | Done   | macOS Apple Silicon environment confirmed.                                 |
| 2026-06-26 | Gazebo command check before installation | Failed | `gz` command was not found before Gazebo Jetty installation.               |
| 2026-06-26 | Gazebo Jetty installation                | Done   | Installed using Homebrew.                                                  |
| 2026-06-26 | Gazebo command check after installation  | Done   | `gz` command found at `/opt/homebrew/bin/gz`.                              |
| 2026-06-26 | Gazebo server test                       | Done   | `gz sim -s` executed successfully and was manually stopped with Ctrl+C.    |
| 2026-06-26 | Gazebo GUI test                          | Done   | `gz sim -g` launched the Gazebo application successfully.                  |

## Gazebo Jetty Installation

### Installation

Gazebo Jetty was installed using Homebrew.

```bash
brew tap osrf/simulation
brew trust osrf/simulation
brew install gz-jetty
```

### Verification

The `gz` command was successfully detected after installation.

```bash
which gz
# /opt/homebrew/bin/gz
```

The Gazebo server was tested with:

```bash
gz sim -s
```

Result: The Gazebo server command executed successfully and was manually stopped with `Ctrl+C`.

The Gazebo GUI was tested with:

```bash
gz sim -g
```

Result: The Gazebo application launched successfully and was manually stopped with `Ctrl+C`.

### Notes

The `^C` output is expected because the Gazebo process was manually stopped using `Ctrl+C`.

The first test before installation produced:

```bash
zsh: command not found: gz
```

This happened because Gazebo Jetty had not been installed yet. After installing Gazebo Jetty through Homebrew, the `gz` command was available at `/opt/homebrew/bin/gz`.
