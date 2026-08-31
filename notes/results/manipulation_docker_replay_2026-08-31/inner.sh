#!/usr/bin/env bash
set -eo pipefail
source /opt/ros/lyrical/setup.bash
source /home/docker/dave_ws/install/setup.bash
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
export ROS_DOMAIN_ID=218
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"

ws=/home/docker/manipulation_overlay

python3 - <<'PY'
from pathlib import Path
p=Path('/home/docker/manipulation_overlay/src/dave/examples/dave_demos/launch/dave_world.launch.py')
s=p.read_text()
changes=[
 ('from launch.conditions import IfCondition\n',''),
 ('if headless_flag.lower() == "true":','if headless_flag.lower() == "true" or gui.perform(context).lower() == "false":'),
 ('        condition=IfCondition(gui),\n',''),
 ('description=(\n                    "Flag to enable launching Gazebo at all -- matches "\n                    "dave_sensor.launch.py/dave_robot.launch.py\'s existing convention: "\n                    "gui:=false disables Gazebo entirely, not just the window. "\n                    "Pass gui:=true headless:=true for real headless mode."\n                ),','description="Enable the Gazebo GUI; false starts the server only",'),
]
for old,new in changes:
    if old not in s:
        raise RuntimeError(f'missing candidate patch context: {old!r}')
    s=s.replace(old,new,1)
p.write_text(s)
PY

cd "$ws"
colcon build --packages-select dave_demos dave_worlds \
  --cmake-args -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF \
  > /tmp/build.log 2>&1
source "$ws/install/local_setup.bash"

printf 'world\tsdf_world\tstats_messages\titeration_increase\tlaunch_alive\tstack_trace\tlaunch_rc\n' >/tmp/summary.tsv
cases=(
  'dave_bimanual_example:dave_bimanual_example'
  'dave_electrical_mating:dave_electrical_mating'
  'dave_plug_and_socket:dave_plug_and_socket'
)
for entry in "${cases[@]}"; do
  world=${entry%%:*}; sdf_world=${entry##*:}; out=/tmp/$world
  mkdir -p "$out"
  export GZ_PARTITION="manip_${world}_$$"
  setsid bash -c "trap - INT TERM; exec ros2 launch dave_demos dave_world.launch.py world_name:=$world paused:=false gui:=false headless:=false" \
    >"$out/launch.log" 2>&1 &
  pid=$!
  stats_topic="/world/$sdf_world/stats"
  ready=0
  for i in $(seq 1 180); do
    kill -0 "$pid" 2>/dev/null || break
    if gz topic -l 2>/dev/null | grep -qx "$stats_topic"; then ready=1; break; fi
    sleep 1
  done
  alive=0; kill -0 "$pid" 2>/dev/null && alive=1
  if [[ $ready -eq 1 ]]; then
    timeout 60 gz topic -e -t "$stats_topic" -n 5 >"$out/stats.txt" 2>&1 || true
    gz topic -l | sort >"$out/gz_topics.txt" 2>&1 || true
  else
    : >"$out/stats.txt"; gz topic -l | sort >"$out/gz_topics.txt" 2>&1 || true
  fi
  kill -INT -- "-$pid" 2>/dev/null || true
  for i in $(seq 1 30); do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
  kill -TERM -- "-$pid" 2>/dev/null || true
  set +e; wait "$pid"; rc=$?; set -e
  python3 - "$out/stats.txt" >"$out/stats_analysis.json" <<'PY'
from pathlib import Path
import json,re,sys
s=Path(sys.argv[1]).read_text(errors='replace')
its=[int(x) for x in re.findall(r'^iterations: (\d+)$',s,re.M)]
print(json.dumps({'messages':len(its),'iterations':its,'iteration_increase':its[-1]-its[0] if len(its)>1 else 0},indent=2))
PY
  msgs=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["messages"])' "$out/stats_analysis.json")
  inc=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["iteration_increase"])' "$out/stats_analysis.json")
  stack=0; grep -Eq 'Stack trace|Segmentation fault|exit code 139' "$out/launch.log" && stack=1
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$world" "$sdf_world" "$msgs" "$inc" "$alive" "$stack" "$rc" >>/tmp/summary.tsv
done
