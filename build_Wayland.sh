#!/bin/bash
echo "Build caramelChat Library for Wayland"
mkdir -p build
cd src/wayland
make && make clean && make install
