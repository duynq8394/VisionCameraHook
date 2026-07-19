#!/bin/bash

set -e

SDK=$(xcrun --sdk iphoneos --show-sdk-path)

clang -dynamiclib \
  -arch arm64 \
  -isysroot $SDK \
  -miphoneos-version-min=12.0 \
  -fobjc-arc \
  -fvisibility=default \
  -install_name @rpath/VisionCameraHook.dylib \
  -framework UIKit \
  -framework Foundation \
  -framework CoreGraphics \
  VisionCameraHook.m \
  -o VisionCameraHook.dylib

echo "✅ Build completed"
