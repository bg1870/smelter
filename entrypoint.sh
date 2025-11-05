#!/usr/bin/env bash

# This entrypoint script launches the Smelter compositor inside a
# headless X11 environment.  It closely follows the script used in
# the official Smelter Docker images【703617412425487†L1-L10】.  The
# script delays for a short moment to allow the container to
# initialize, sets up a DBus session bus and then runs the main
# Smelter process using xvfb-run so that Chromium (used by the
# WebRenderer) can operate without a display server.

set -eo pipefail
set -x

# Give the system a moment to finish booting up
sleep 2

# Configure and launch a session DBus.  Smelter's CEF component
# requires DBus to be available when running headless
export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus
sudo service dbus start

# Start a session dbus daemon in the background
dbus-daemon --session --address=$DBUS_SESSION_BUS_ADDRESS --nofork --nopidfile --syslog-only &

# Launch the Smelter compositor under Xvfb.  The compositor expects
# the environment variables SMELTER_MAIN_EXECUTABLE_PATH and
# LD_LIBRARY_PATH to be set; these are defined in the Dockerfile.
xvfb-run "$SMELTER_MAIN_EXECUTABLE_PATH"