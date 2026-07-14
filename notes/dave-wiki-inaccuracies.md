# DAVE Wiki inaccuracies found while cross-checking

The [official DAVE Wiki](http://dave-ros2.notion.site) is written entirely for ROS 2 Jazzy + Gazebo Harmonic. No page anywhere in the Wiki mentions "Lyrical" or "Jetty" — not even pages edited as recently as this week (e.g. Native Local Installation Manual, System Requirements). A few unrelated inaccuracies were also found while reading every page for this verification:

- **SeaPressure Plugin page** — cites `ros2 launch dave_robot_launch robot_in_world.launch.py ...`. The `dave_robot_launch` package does not exist (`ros2 pkg list` confirms). The plugin is actually bundled automatically into any REXROV spawn via the normal `dave_demos dave_robot.launch.py` — no special launch file needed. The topic names cited (`/rexrov/Pressure`) are also stale; the real topics are `/model/rexrov/sea_pressure` and `/model/rexrov/sea_pressure_depth`.
- **"Create New Robot Model"** and **"Build World using Heightmap"** pages are completely empty placeholders (title only, no content).
- **"Multi-beam Sonar Plugin"** (hyphenated) is a stale, near-empty duplicate (just a 4-line `apt install` snippet) of the current, complete **"Multibeam Sonar Plugin"** page.
- The **"Local Search Scenario"** demo on the Multibeam Sonar Plugin page is noted as "(currently available in the sonar-demo branch - TO BE MERGED)" as plain, non-linked text — no repo URL given anywhere in the Wiki. Confirmed via GitHub that a `sonar-demo` branch exists on `IOES-Lab/dave` (not on `naitikpahwa18/dave`); untested so far.
- The **"Migration Progress"** page is an inline Notion database tracking the *original* ROS 1 Noetic/Gazebo Classic → ROS 2 Jazzy/Harmonic migration (20 items, last edited 2025-02-11) — it does not track Lyrical/Jetty at all.
