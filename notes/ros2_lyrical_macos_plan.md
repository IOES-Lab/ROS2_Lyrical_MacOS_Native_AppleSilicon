# ROS 2 Lyrical macOS Native Installation Plan

## Goal

Install and verify ROS 2 Lyrical natively on macOS Apple Silicon.

## Current Environment

* macOS version: 15.7.3
* Architecture: arm64
* Homebrew path: /opt/homebrew
* Python version: 3.14.5
* Git version: 2.50.1
* Gazebo: Jetty
* `gz` path: /opt/homebrew/bin/gz

## Things to Check

* Official ROS 2 Lyrical installation method for macOS
* Required dependencies
* Python version compatibility
* Homebrew packages
* Build tools
* `ros2` command availability
* Talker/listener demo test
* ROS-Gazebo bridge compatibility with Gazebo Jetty

## Verification Commands

```bash
ros2 --help
ros2 run demo_nodes_cpp talker
ros2 run demo_nodes_py listener
```

## Current Concern

The current Python version is 3.14.5, which may cause compatibility issues during the ROS 2 source build. This needs to be checked during installation.


