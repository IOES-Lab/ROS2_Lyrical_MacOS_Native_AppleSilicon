# Fast DDS create-hang controlled recheck

An isolated empty Gazebo world and minimal model were run on ROS domain 49.

## Result

- dirty pre-clean default transport: 5/5 success;
- after official `fastdds shm clean`: 5/5 success;
- after SIGKILL injection into five create processes: 5/5 success;
- explicit `FASTDDS_BUILTIN_TRANSPORTS=UDPv4`: 3/3 success.

Total: **18/18**, with no current create hang reproduced. Before cleanup `/dev/shm`
contained 193 entries; the official cleaner reported and removed zombie ports/segments.
That demonstrates stale state and a valid official cleanup path, but does not prove stale
state caused the historical 1/9 failure.

A separate current defect is also preserved: `ros_gz_sim create --help` prints help and
then aborts with return code 250 and `mutex lock failed: Invalid argument`, both before and
after SHM cleanup. It is not evidence for the create-hang mechanism.

Official references:

- <https://fast-dds.docs.eprosima.com/en/stable/fastdds/env_vars/env_vars.html>
- <https://github.com/eProsima/Fast-DDS/blob/master/tools/fastdds/shm/clean.py>

Machine-readable results are in `summary.json`.
