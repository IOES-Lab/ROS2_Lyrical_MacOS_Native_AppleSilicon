#!/bin/zsh
set -euo pipefail

HERE=${0:A:h}
WINDOW_ENUM=/tmp/list_windows

for name in plain_mainwindow opengl_mainwindow qwindow_container qopenglwindow_container; do
  out="$HERE/$name"
  mkdir -p "$out"
  "$HERE/${name}_app" >"$out/app.log" 2>&1 &
  pid=$!
  echo "$pid" >"$out/pid.txt"
  sleep 5

  ps -p "$pid" -o pid,ppid,stat,etime,command >"$out/process.txt" || true
  osascript - "$pid" >"$out/window_state.txt" 2>&1 <<'APPLESCRIPT' || true
on run argv
  set targetPid to item 1 of argv as integer
  tell application "System Events"
    set targetProcess to first process whose unix id is targetPid
    return "name=" & name of targetProcess & ", visible=" & visible of targetProcess & ", windows=" & (count windows of targetProcess)
  end tell
end run
APPLESCRIPT

  if [[ -x "$WINDOW_ENUM" ]]; then
    "$WINDOW_ENUM" "$pid" >"$out/coregraphics_windows.txt" 2>&1 || true
  fi

  kill -TERM "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
done
