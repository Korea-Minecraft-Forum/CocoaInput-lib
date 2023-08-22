#!/bin/bash
echo "Build libcocoainput for Windows"
mkdir -p build
cd src/win
make && make install
