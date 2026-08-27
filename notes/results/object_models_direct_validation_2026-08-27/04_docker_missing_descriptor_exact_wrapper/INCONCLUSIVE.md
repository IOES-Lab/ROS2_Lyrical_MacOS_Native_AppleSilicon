# Inconclusive full-wrapper attempt

This attempt launched the complete wrapper with a missing namespace, but the create
client never discovered a world service and repeated `Requesting list of world
names`. It is retained as an execution record but is **not used** to support the
missing-descriptor false-success finding.

That finding comes from the controlled lower-level upload attempt in
[`../03_docker_missing_descriptor_negative_control/`](../03_docker_missing_descriptor_negative_control/)
against the already-running validated world, together with the server-side errors in
[`../02_docker_wiki_exact/launch_after_negative_control.log`](../02_docker_wiki_exact/launch_after_negative_control.log).
