#!/bin/bash
echo "Build libcocoainput for X11"
mkdir -p build
cd src/x11
make && make install
