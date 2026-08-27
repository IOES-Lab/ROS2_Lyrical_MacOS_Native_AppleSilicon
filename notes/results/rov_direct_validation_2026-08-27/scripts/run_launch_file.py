#!/usr/bin/env python3
import sys

from launch import LaunchDescription, LaunchService
from launch.actions import IncludeLaunchDescription
from launch.launch_description_sources import PythonLaunchDescriptionSource


source = PythonLaunchDescriptionSource(sys.argv[1])
description = LaunchDescription([IncludeLaunchDescription(source)])
service = LaunchService(argv=[])
service.include_launch_description(description)
raise SystemExit(service.run())
