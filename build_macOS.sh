#!/bin/bash
echo "Build libcocoainput for macOS (Universal)"
mkdir build
cd src/darwin/libcocoainput
make && make install
