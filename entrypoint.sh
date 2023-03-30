#!/bin/sh
# Docker entrypoint script.

./bin/saturn eval Saturn.Release.migrate

./bin/saturn start
