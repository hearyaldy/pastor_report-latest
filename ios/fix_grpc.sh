#!/bin/bash
# Fix for gRPC modulemap path issue

cd "$(dirname "$0")"

GRPC_DIR="Pods/Headers/Private/grpc"
MODULEMAP="$GRPC_DIR/gRPC-Core.modulemap"
TARGET_MODULEMAP="../../Target Support Files/gRPC-Core/gRPC-Core.modulemap"

# Create the grpc directory if it doesn't exist
mkdir -p "$GRPC_DIR"

# Remove existing symlink if it exists
rm -f "$MODULEMAP"

# Create the symlink
ln -s "$TARGET_MODULEMAP" "$MODULEMAP"

echo "✓ Created symlink for gRPC-Core.modulemap"
ls -la "$MODULEMAP"
