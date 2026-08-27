from launch import LaunchDescription
from launch.actions import IncludeLaunchDescription, LogInfo, RegisterEventHandler
from launch.event_handlers import OnProcessExit
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch_ros.actions import Node


WORLD = "/home/docker/dave_ws/install/share/dave_worlds/worlds/dave_ocean_waves.world"
MODEL = (
    "/home/docker/dave_ws/install/share/dave_robot_models/description/"
    "bluerov2_heavy_multibeam_sonar/model.sdf"
)
CONFIG = (
    "/home/docker/dave_ws/install/share/dave_robot_models/config/"
    "bluerov2_heavy_multibeam_sonar/robot_config.py"
)
GZ_LAUNCH = "/opt/ros/lyrical/share/ros_gz_sim/launch/gz_sim.launch.py"


def generate_launch_description():
    gazebo = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(GZ_LAUNCH),
        launch_arguments={"gz_args": f"{WORLD} -s -r"}.items(),
    )
    create = Node(
        package="ros_gz_sim",
        executable="create",
        arguments=[
            "-name",
            "bluerov2_heavy_multibeam_sonar",
            "-file",
            MODEL,
            "-z",
            "-0.5",
        ],
        output="both",
    )
    config = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(CONFIG),
        launch_arguments={
            "namespace": "bluerov2_heavy_multibeam_sonar",
            "use_ardusub": "false",
            "use_teleop": "false",
            "use_web_joystick": "false",
            "open_qgc": "false",
            "open_virtual_joystick": "false",
            "zoom_camera": "false",
        }.items(),
    )
    after_create = RegisterEventHandler(
        OnProcessExit(
            target_action=create,
            on_exit=[LogInfo(msg="Robot Model Uploaded (isolated)"), config],
        )
    )
    return LaunchDescription([gazebo, create, after_create])
