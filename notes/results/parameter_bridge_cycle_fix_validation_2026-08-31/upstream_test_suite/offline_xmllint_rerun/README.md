# Offline xmllint rerun

The package suite's `xmllint` test timed out after 60 seconds while
`ament_xmllint` was downloading the HTTP schema from
`download.ros.org`. A direct transfer reproduced the stalled response after
1,036 of 8,027 bytes, so the suite timeout is a schema-delivery/environment
failure rather than an XML or C++ candidate failure.

The schemas were fetched instead from the ROS project's canonical archived
`ros-infrastructure/rep` repository:

- `https://raw.githubusercontent.com/ros-infrastructure/rep/master/xsd/package_format3.xsd`
- `https://raw.githubusercontent.com/ros-infrastructure/rep/master/xsd/package_common.xsd`

Two retained checks passed:

1. `xmllint --schema` validated the exact, unmodified candidate `package.xml`.
2. `ament_xmllint` validated a temporary copy whose only change was replacing
   the unreachable remote schema URL with the local schema path.

No production XML file was changed.
