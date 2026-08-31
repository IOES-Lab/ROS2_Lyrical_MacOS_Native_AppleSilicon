#!/usr/bin/env bash
set +e
source /opt/ros/lyrical/setup.bash
source /home/docker/bridge_cycle_ws/install/setup.bash
export ROS_DOMAIN_ID=198
export GZ_PARTITION=bridge_cycle_r2g_18_35276
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4

setsid /home/docker/bridge_cycle_ws/install/ros_gz_bridge/lib/ros_gz_bridge/parameter_bridge   '/cycle_ros_to_gz@std_msgs/msg/String]gz.msgs.StringMsg'   >/tmp/bridge.log 2>&1 &
bp=$!
sleep 3

timeout 20 gz topic -e -t /cycle_ros_to_gz -n 1 >/tmp/gz_received.txt 2>&1 &
gz_echo=$!
sleep 1
ros2 topic pub --once /cycle_ros_to_gz std_msgs/msg/String '{data: from_ros}'   >/tmp/ros_publish.txt 2>&1
wait $gz_echo
gz_echo_rc=$?
payload=0
[[ $gz_echo_rc -eq 0 ]] && grep -q 'from_ros' /tmp/gz_received.txt && payload=1

kill -INT "$bp" 2>/dev/null || true
escalation=none
for i in $(seq 1 20); do
  kill -0 $bp 2>/dev/null || break
  sleep 1
done
if kill -0 $bp 2>/dev/null; then
  escalation=TERM
  kill -TERM "$bp" 2>/dev/null || true
  sleep 2
fi
if kill -0 $bp 2>/dev/null; then
  escalation=KILL
  kill -KILL "$bp" 2>/dev/null || true
fi
wait $bp
bridge_rc=$?
printf '%s\n' $payload >/tmp/payload.txt
printf '%s\n' $bridge_rc >/tmp/bridge_rc.txt
printf '%s\n' $escalation >/tmp/escalation.txt
exit 0
