import json, sys, time
import rclpy
from rclpy.node import Node
from nav_msgs.msg import Odometry
from sensor_msgs.msg import Imu, MagneticField, PointCloud2

ns, out, want_sonar = sys.argv[1], sys.argv[2], sys.argv[3] == '1'
timeout_s = int(sys.argv[4]) if len(sys.argv) > 4 else 120
rclpy.init()
node = Node('capture_' + ns.replace('-', '_'))
rows = {}

def odom(m):
    rows.setdefault('odometry', {'frame_id': m.header.frame_id, 'child_frame_id': m.child_frame_id,
      'position': [m.pose.pose.position.x,m.pose.pose.position.y,m.pose.pose.position.z],
      'linear_velocity': [m.twist.twist.linear.x,m.twist.twist.linear.y,m.twist.twist.linear.z]})
def imu(m):
    rows.setdefault('imu', {'frame_id': m.header.frame_id,
      'linear_acceleration': [m.linear_acceleration.x,m.linear_acceleration.y,m.linear_acceleration.z],
      'angular_velocity': [m.angular_velocity.x,m.angular_velocity.y,m.angular_velocity.z]})
def mag(m):
    rows.setdefault('magnetometer', {'frame_id': m.header.frame_id,
      'magnetic_field': [m.magnetic_field.x,m.magnetic_field.y,m.magnetic_field.z]})
def sonar(m):
    rows.setdefault('sonar_point_cloud', {'frame_id': m.header.frame_id, 'width':m.width,'height':m.height,
      'fields':[f.name for f in m.fields], 'point_step':m.point_step,'row_step':m.row_step,'data_length':len(m.data)})
node.create_subscription(Odometry, f'/model/{ns}/odometry', odom, 10)
node.create_subscription(Imu, f'/model/{ns}/imu', imu, 10)
node.create_subscription(MagneticField, f'/model/{ns}/magnetometer', mag, 10)
if want_sonar:
    node.create_subscription(PointCloud2, f'/model/{ns}/multibeam_sonar/point_cloud', sonar, 10)
expected={'odometry','imu','magnetometer'} | ({'sonar_point_cloud'} if want_sonar else set())
end=time.monotonic()+timeout_s
while time.monotonic()<end and not expected.issubset(rows):
    rclpy.spin_once(node, timeout_sec=0.5)
result={'namespace':ns,'received':rows,'missing':sorted(expected-set(rows)),'timeout_s':timeout_s}
with open(out,'w') as f: json.dump(result,f,indent=2)
print(json.dumps(result,indent=2),flush=True)
node.destroy_node(); rclpy.shutdown()
