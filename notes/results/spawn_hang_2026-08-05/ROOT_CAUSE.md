# Root cause: Fast DDS shared-memory transport hangs in `rmw_create_node` (2026-08-06)

The intermittent spawn failure documented in [`README.md`](README.md) is not a DAVE problem,
not a Gazebo problem, and not a race between `create` and the world. **`ros_gz_sim create`
hangs while constructing its own ROS node, inside Fast DDS.**

Setting `FASTDDS_BUILTIN_TRANSPORTS=UDPv4` avoids it.

## How it was found

`sample`-ing the hung `create` process — the one diagnostic that had not been tried:

```
$ P=$(pgrep -f ros_gz_sim | head -1)
$ sample $P 5 1 -f /tmp/create_stuck.txt
```

**4218 of 4218 samples on one stack.** Completely blocked, not slow:

```
main (in create)
  rclcpp::Node::make_shared<char const (&)[11]>
    rclcpp::Node::Node(...)
      rclcpp::node_interfaces::NodeBase::NodeBase(...)
        rcl_node_init
          rmw_create_node                                  (rmw_implementation)
            rmw_create_node                                (rmw_fastrtps_cpp)
              rmw_fastrtps_cpp::increment_context_impl_ref_count
                init_context_impl
                  rmw_fastrtps_cpp::create_subscription
                    rmw_fastrtps_cpp::__create_subscription
                      rmw_fastrtps_shared_cpp::create_datareader
                        SubscriberImpl::create_datareader
                          DataReader::enable()
                            DataReaderImpl::enable()
                              RTPSDomain::createRTPSReader  <- stuck here
```

It never reaches the model SDF, the `/world/*/create` service, or any Gazebo code. Every
earlier hypothesis was looking in the wrong place because the failure happens before any of
it runs.

## Evidence

`FASTDDS_BUILTIN_TRANSPORTS=UDPv4` switches Fast DDS off its shared-memory transport.

| transport | spawned | attempts |
|---|---|---|
| **UDPv4 (shm off)** | **5** | **5** |
| default (shm on) | 1 | 9 |

The UDPv4 successes are `exp9`'s `noshm` and `both` conditions plus three consecutive
launches run specifically to test this. The failures are `exp9`'s `baseline` and `cpu1`,
three launches on 2026-08-05, and three on 2026-08-06 with retries enabled.

Within `exp9` the correlation is exact, 4/4: the two conditions that happened to set the
variable — for an unrelated reason, to remove DDS spin from the profile — are precisely the
two that spawned. That was visible in the data for hours before anyone noticed it.

## Consistent with earlier observations

- The 2026-08-05 profile showed `boost::interprocess::spin_wait::yield()` at **16.1% of
  busy CPU** across two `dds.shm.*` threads, plus `__open` (3.4%) and `__unlink` (1.3%) —
  a shared-memory transport working hard at something.
- The session repeatedly `pkill -9`-ed Gazebo, which leaves shared-memory segments and
  lock files behind. That is a plausible trigger for the intermittency but **has not been
  confirmed** — no stale segment was ever located. `$TMPDIR` on macOS is
  `/var/folders/.../T/`, not `/tmp`, and a search there found no `fastdds`/`fastrtps`
  entries at the time it was checked.

## Applied

`common.sh` now exports `FASTDDS_BUILTIN_TRANSPORTS=UDPv4` by default. `SHM=1` restores the
old behaviour for anyone wanting to reproduce the hang.

**This changes measurement conditions.** The shared-memory transport was 16% of busy CPU;
removing it plausibly changes RTF. Any figure taken from 2026-08-06 onward needs its own
baseline and must not be compared against earlier numbers.

## Not yet established

- **Why it is intermittent.** One run out of nine did succeed with shm enabled.
- **Whether stale segments are the trigger.** Plausible, unverified.
- **Whether this is macOS-specific**, ROS 2 Lyrical-specific, or specific to this Fast DDS
  build (`libfastdds.3.6.2.0`). Untested elsewhere — Docker has not been checked.
- Whether the same hang affects other ROS nodes in the stack. Only `create` was sampled;
  `parameter_bridge` and `static_transform_publisher` start from the same launch file and
  were never checked.

## Worth reporting upstream, once scoped

A ROS node blocking forever in `rmw_create_node` with no output and no timeout is a bad
failure mode regardless of the trigger — it is silent, and downstream it produced a world
that ran normally with no sensor in it, which reads as success. But the report needs at
least the questions above answered before it would be actionable. Likely target:
`ros2/rmw_fastrtps` or `eProsima/Fast-DDS`, not DAVE.
