#!/usr/bin/env bash
set -euo pipefail

root="${1:?output root required}"
image="${BRIDGE_IMAGE:-dave-sonar-deferred-compute-test:20260830}"
mkdir -p "$root"
printf 'case\trun\trc\tsegfault_text\tescalation\n' >"$root/summary.tsv"

for case_name in full_bidirectional full_gz_to_ros point_bidirectional point_gz_to_ros; do
  for run in $(seq 1 10); do
    out="$root/${case_name}/run_$(printf '%02d' "$run")"
    mkdir -p "$out"
    case "$case_name" in
      full_bidirectional)
        args=(
          '/sensor/camera@sensor_msgs/msg/Image@gz.msgs.Image'
          '/sensor/camera_info@sensor_msgs/msg/CameraInfo@gz.msgs.CameraInfo'
          '/sensor/depth_camera@sensor_msgs/msg/Image@gz.msgs.Image'
          '/sensor/multibeam_sonar/point_cloud@sensor_msgs/msg/PointCloud2@gz.msgs.PointCloudPacked'
        )
        ;;
      full_gz_to_ros)
        args=(
          '/sensor/camera@sensor_msgs/msg/Image[gz.msgs.Image'
          '/sensor/camera_info@sensor_msgs/msg/CameraInfo[gz.msgs.CameraInfo'
          '/sensor/depth_camera@sensor_msgs/msg/Image[gz.msgs.Image'
          '/sensor/multibeam_sonar/point_cloud@sensor_msgs/msg/PointCloud2[gz.msgs.PointCloudPacked'
        )
        ;;
      point_bidirectional)
        args=('/sensor/multibeam_sonar/point_cloud@sensor_msgs/msg/PointCloud2@gz.msgs.PointCloudPacked')
        ;;
      point_gz_to_ros)
        args=('/sensor/multibeam_sonar/point_cloud@sensor_msgs/msg/PointCloud2[gz.msgs.PointCloudPacked')
        ;;
    esac

    printf -v quoted ' %q' "${args[@]}"
    domain=$((120 + (run % 20)))
    partition="bridge_standalone_${case_name}_${run}_$$"
    set +e
    docker run --rm --entrypoint bash "$image" -lc "
      set +e
      source /opt/ros/lyrical/setup.bash
      export ROS_DOMAIN_ID=$domain
      export GZ_PARTITION=$partition
      export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
      setsid ros2 run ros_gz_bridge parameter_bridge $quoted > /tmp/bridge.log 2>&1 &
      pid=\$!
      sleep 3
      kill -INT -- -\$pid 2>/dev/null || true
      escalation=none
      for i in \$(seq 1 15); do
        kill -0 \$pid 2>/dev/null || break
        sleep 1
      done
      if kill -0 \$pid 2>/dev/null; then
        escalation=TERM
        kill -TERM -- -\$pid 2>/dev/null || true
        sleep 2
      fi
      if kill -0 \$pid 2>/dev/null; then
        escalation=KILL
        kill -KILL -- -\$pid 2>/dev/null || true
      fi
      wait \$pid
      rc=\$?
      cat /tmp/bridge.log
      printf '__RESULT__ rc=%s escalation=%s\n' \$rc \$escalation
      exit 0
    " >"$out/output.txt" 2>&1
    docker_rc=$?
    set -e

    result=$(grep '__RESULT__' "$out/output.txt" | tail -1 || true)
    rc=$(printf '%s' "$result" | sed -n 's/.*rc=\([0-9]*\).*/\1/p')
    escalation=$(printf '%s' "$result" | sed -n 's/.*escalation=\([^ ]*\).*/\1/p')
    [[ -n "$rc" ]] || rc="missing"
    [[ -n "$escalation" ]] || escalation="missing"
    seg=0
    grep -Eqi 'segmentation|stack trace|exit code -11' "$out/output.txt" && seg=1
    printf '%s\t%s\t%s\t%s\t%s\n' \
      "$case_name" "$run" "$rc" "$seg" "$escalation" >>"$root/summary.tsv"
    echo "$case_name $run rc=$rc seg=$seg escalation=$escalation docker_rc=$docker_rc"
  done
done

docker image inspect "$image" --format '{{.Id}}' >"$root/image_id.txt"
