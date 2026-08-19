# ArduSub SITL setup on Ubuntu 26.04 + Python 3.14 (BlueROV2)

Not documented anywhere in the DAVE Wiki. BlueROV2 launch needs the `ardusub` binary in `PATH`; building it from source on Ubuntu 26.04 hits several chained environment issues, all fixable (corrected 2026-07-23: earlier versions of this line tried to pin an exact count — "three," then "four/five" — but a careful tally of every distinct fix applied across the four sections below (non-root sudo user, hardcoded `python-argparse`, PEP 668's pip block, `imp` removed from Python, `pipes` removed from Python, and `waf`'s tool loader needing `waflib/extras` added to `PYTHONPATH`) comes to six, not five — "several" avoids re-litigating the exact number each time this file is touched).

## 1. `install-prereqs-ubuntu.sh` refuses to run as root

Create a regular user with sudo rights first and run everything from that account.

```bash
apt update && apt install -y sudo
adduser --disabled-password --gecos "" arduuser
usermod -aG sudo arduuser
echo "arduuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
su - arduuser
```

## 2. `python-argparse` hardcoded in the prereqs script, doesn't exist on 26.04

Strip just the word, not the whole line — deleting the whole line breaks an `if`/`fi` block.

```bash
sed -i "s/ python-argparse//g" Tools/environment_install/install-prereqs-ubuntu.sh
```

## 3. `pip install` blocked by PEP 668 ("externally-managed-environment")

```bash
export PIP_BREAK_SYSTEM_PACKAGES=1
Tools/environment_install/install-prereqs-ubuntu.sh -y
```

## 4. `waf` itself imports two Python stdlib modules removed in modern Python

- `imp` — removed in Python 3.12. Only use in `waflib/Context.py` is `imp.new_module(name)`.
- `pipes` — removed in Python 3.13. Only use in `waflib/extras/clang_compilation_database.py` is `pipes.quote(s)`.

Minimal compatibility shims, added to `PYTHONPATH`:

```bash
mkdir -p ~/imp_shim
cat > ~/imp_shim/imp.py << 'EOF'
import types
def new_module(name):
    return types.ModuleType(name)
EOF
cat > ~/imp_shim/pipes.py << 'EOF'
import shlex
def quote(s):
    return shlex.quote(s)
EOF
export PYTHONPATH=~/imp_shim:$PYTHONPATH
```

`waf`'s tool loader also doesn't search `waflib/extras/` by default — add it too:

```bash
export PYTHONPATH=~/ardupilot/modules/waf/waflib/extras:$PYTHONPATH
```

## 5. Build and install

```bash
cd ~/ardupilot
./waf configure --board sitl
./waf sub                       # NOT ./waf copter — target is 'sub' for ArduSub
sudo cp build/sitl/bin/ardusub /usr/local/bin/ardusub
```

Build took ~4m19s. `ros2 launch dave_demos dave_robot.launch.py namespace:=bluerov2 ...` then finds `ardusub` on `PATH` and launches correctly, with the keyboard teleop node also starting normally.
