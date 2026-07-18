#!/bin/bash

set -e

echo "🔧 Getting iOS SDK path..."
SDK=$(xcrun --sdk iphoneos --show-sdk-path)

echo "📦 Building VisionCameraHook.dylib..."

clang -dynamiclib \
  -arch arm64 \
  -isysroot $SDK \
  -miphoneos-version-min=16.0 \
  -fobjc-arc \
  -framework UIKit \
  -framework PhotosUI \
  -framework Foundation \
  -framework ObjectiveC \
  VisionCameraHook.m \
  -o VisionCameraHook.dylib

echo "✅ Build completed successfully!"