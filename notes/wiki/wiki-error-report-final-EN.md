# DAVE ROS 2 Wiki — corrections (applied; retained as historical draft)

**Status:** **Applied 2026-07-20 by editing the pages directly**, not sent. Retained as the historical draft and as the record of what was found.
Delivery method still undecided — see the note at the bottom.

Found while reading all 20 pages of the [DAVE ROS 2 Wiki](http://dave-ros2.notion.site) in
full during a ROS 2 Lyrical / Gazebo Jetty verification pass. Everything below was checked
against a real, running checkout — not just read off the page. Full evidence/commands for
each item are in our verification notes if useful for triage.

---

## 1. SeaPressure Plugin page — wrong package and topic names

The page currently shows:

```
ros2 launch dave_robot_launch robot_in_world.launch.py ...
```
with topic `/rexrov/Pressure`.

- The `dave_robot_launch` package doesn't exist (`ros2 pkg list` confirms no match).
- The SeaPressure plugin doesn't need a dedicated launch file at all — it's automatically
  included in any standard REXROV spawn via `dave_demos dave_robot.launch.py`.
- The real topic names are `/model/rexrov/sea_pressure` and
  `/model/rexrov/sea_pressure_depth`, not `/rexrov/Pressure`.

**Suggested fix:** replace the launch example with the standard `dave_demos
dave_robot.launch.py` command, and update the topic names.

## 2. "Create New Robot Model" and "Build World using Heightmap" pages are empty

Both are title-only placeholders with no body content as of this check.

**Suggested fix:** add content, or mark them explicitly as "coming soon" so readers don't
assume something is missing on their end.

## 3. Duplicate/stale "Multi-beam Sonar Plugin" page

There are two pages for the same topic: "Multi-beam Sonar Plugin" (hyphenated), which is a
4-line stub with just an `apt install` snippet, and "Multibeam Sonar Plugin" (no hyphen),
which is the current, complete page. Having both live at once is confusing for anyone
searching or linking.

**Suggested fix:** delete the hyphenated stub, or redirect it to the complete page.

## 4. "Local Search Scenario" demo — branch reference has no link, and its scope is unclear

The Multibeam Sonar Plugin page says this demo is "(currently available in the sonar-demo
branch - TO BE MERGED)" as plain text, with no repository or URL given.

We confirmed a `sonar-demo` branch does exist, on `IOES-Lab/dave` (not on the
`naitikpahwa18/dave` fork some readers may be working from). We have **not** confirmed that
this branch is what the "Local Search Scenario" demo actually refers to, or exercised the
branch ourselves — so we can only confirm the link target exists, not that it's the correct
one for this demo.

**Suggested fix:** add the actual branch link
(https://github.com/IOES-Lab/dave/tree/sonar-demo), and if possible, a maintainer confirm
whether this is still accurate ("TO BE MERGED" — has it been merged since?).

> **Resolved 2026-08-21.** The question below ("has it been merged since?") is answered: the sonar
> worlds are present on `IOES-Lab/dave`'s `ros2` default branch — `dave_ocean_waves_sonar.world`,
> `dave_ocean_waves_sonar_integrated.world` and `dave_multibeam_sonar.world`. Separately, this
> checkout was found on 2026-07-22 not to need the branch at all; both worlds only require
> `multibeam_sonar_system`, which is already present. **The "TO BE MERGED" wording on the wiki page
> was removed the same day.** This entry is kept as the record of the original report.


## For context, not a per-page fix

- None of the Wiki's 20 pages mention "Lyrical" or "Jetty" anywhere, including pages edited
  within the week before 2026-07-20 — the Wiki was at that point written entirely for ROS 2 Jazzy + Gazebo
  Harmonic. **This is no longer true as written** — Lyrical/Jetty context was added to 12 pages on
  2026-08-20; see [`README.md`](README.md). We're not asking for a full Lyrical/Jetty rewrite in this report, just flagging it
  since it may be relevant to how you want to handle contributions like the corrections above.
- The "Migration Progress" database only tracks the original ROS 1 → ROS 2/Harmonic migration
  (last edited months ago) — not something we're asking to be changed, just noting it in case
  it's relevant to planning.

---

*Sent by: [your name] — happy to answer questions or provide the exact commands/output behind
any of the above.*

## Delivery decision (internal note, not part of the message above)

Not yet decided how to actually send this — options: a Notion comment on the relevant pages,
a single consolidated email/message to whoever maintains the Wiki, or asking the professor to
relay it. Pick one before sending; the message above is written to work as either a page
comment (per-section) or a single combined email.
