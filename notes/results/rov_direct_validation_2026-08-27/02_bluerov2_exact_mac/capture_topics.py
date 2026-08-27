import json, time
import rclpy
from rclpy.node import Node
from nav_msgs.msg import Odometry
from sensor_msgs.msg import Imu, MagneticField, Joy

rclpy.init()
node = Node('rov_exact_capture_20260827')
rows = {}

def add(name):
    def cb(m):
        if name in rows:
            return
        if name == 'odometry':
            rows[name] = {'x': m.pose.pose.position.x, 'y': m.pose.pose.position.y, 'z': m.pose.pose.position.z,
                          'vx': m.twist.twist.linear.x, 'vy': m.twist.twist.linear.y, 'vz': m.twist.twist.linear.z}
        elif name == 'imu':
            rows[name] = {'frame_id': m.header.frame_id, 'ax': m.linear_acceleration.x,
                          'ay': m.linear_acceleration.y, 'az': m.linear_acceleration.z}
        elif name == 'magnetometer':
            rows[name] = {'frame_id': m.header.frame_id, 'x': m.magnetic_field.x,
                          'y': m.magnetic_field.y, 'z': m.magnetic_field.z}
        else:
            rows[name] = {'axes': list(m.axes), 'buttons': list(m.buttons)}
        print(name, json.dumps(rows[name]), flush=True)
    return cb

node.create_subscription(Odometry, '/model/bluerov2/odometry', add('odometry'), 10)
node.create_subscription(Imu, '/model/bluerov2/imu', add('imu'), 10)
node.create_subscription(MagneticField, '/model/bluerov2/magnetometer', add('magnetometer'), 10)
node.create_subscription(Joy, '/keyboard/joy', add('keyboard_joy'), 10)
end = time.monotonic() + 90
while time.monotonic() < end and len(rows) < 4:
    rclpy.spin_once(node, timeout_sec=0.5)
with open('/Users/gwon-yeseol/ROS2_Lyrical_review_fixes/notes/results/rov_direct_validation_2026-08-27/02_bluerov2_exact_mac/topic_samples.json', 'w') as f:
    json.dump({'received': rows, 'missing': sorted(set(['odometry','imu','magnetometer','keyboard_joy'])-set(rows))}, f, indent=2)
print(json.dumps({'received': sorted(rows), 'missing': sorted(set(['odometry','imu','magnetometer','keyboard_joy'])-set(rows))}), flush=True)
node.destroy_node(); rclpy.shutdown()
