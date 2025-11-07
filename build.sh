#!/bin/bash

# Parse platform argument (default: windows)
PLATFORM=${1:-windows}

# Validate platform argument
if [ "$PLATFORM" != "windows" ] && [ "$PLATFORM" != "linux" ]; then
    echo "❌ Invalid platform: $PLATFORM"
    echo "Usage: ./build.sh [windows|linux]"
    echo ""
    echo "Examples:"
    echo "  ./build.sh          # Build for Windows (default)"
    echo "  ./build.sh windows  # Build for Windows"
    echo "  ./build.sh linux    # Build for Linux"
    exit 1
fi

echo "Building NPC Neural Affect Matrix binaries for $PLATFORM"
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Set platform-specific variables
if [ "$PLATFORM" = "windows" ]; then
    TARGET_TRIPLE="x86_64-pc-windows-msvc"
    IMAGE_TAG="npc-neural-affect-matrix:windows"
    LIB_EXT="dll"
    MAIN_LIB_PATTERN="*.dll"
    ONNX_RT_LIB="onnxruntime.dll"
    ONNX_RT_PROVIDERS_LIB="onnxruntime_providers_shared.dll"
else
    TARGET_TRIPLE="x86_64-unknown-linux-gnu"
    IMAGE_TAG="npc-neural-affect-matrix:linux"
    LIB_EXT="so"
    MAIN_LIB_PATTERN="*.so"
    ONNX_RT_LIB="libonnxruntime.so"
    ONNX_RT_PROVIDERS_LIB="libonnxruntime_providers_shared.so"
fi

# Clean up previous builds
rm -rf "${SCRIPT_DIR}/dist/"
rm -rf "${SCRIPT_DIR}/target/${TARGET_TRIPLE}/"

# Build Docker image with platform-specific tag
echo "Building Docker image for $PLATFORM..."
docker build -f Dockerfile \
    --build-arg TARGET_PLATFORM=$PLATFORM \
    -t $IMAGE_TAG .

if [ $? -ne 0 ]; then
    echo "❌ Docker image build failed!"
    exit 1
fi

echo "✅ Docker image built successfully"
echo ""

# Create target directory
mkdir -p "${SCRIPT_DIR}/target/${TARGET_TRIPLE}"

# Generate unique container name
CONTAINER_NAME="npc-build-${PLATFORM}-$(date +%s)"

echo "Running build in container..."

# Run build in container with platform-specific environment
MSYS_NO_PATHCONV=1 docker run --name "$CONTAINER_NAME" \
    -e TARGET_PLATFORM=$PLATFORM \
    -v "${SCRIPT_DIR}/src:/app/src" \
    -v "${SCRIPT_DIR}/Cargo.toml:/app/Cargo.toml" \
    -v "${SCRIPT_DIR}/Cargo.lock:/app/Cargo.lock" \
    $IMAGE_TAG

BUILD_RESULT=$?

if [ $BUILD_RESULT -ne 0 ]; then
    echo "❌ Build failed for $PLATFORM!"
    docker rm "$CONTAINER_NAME" 2>/dev/null
    rm -rf "${SCRIPT_DIR}/target/${TARGET_TRIPLE}/"
    exit 1
fi

echo "✅ Build completed successfully"
echo ""

# Copy build artifacts from container
echo "Copying build artifacts..."
docker cp "$CONTAINER_NAME:/app/target/${TARGET_TRIPLE}/" "${SCRIPT_DIR}/target/"
docker rm "$CONTAINER_NAME"

# Create dist directory and copy binaries
mkdir -p dist
TARGET_DIR="target/${TARGET_TRIPLE}/release"

# Find main library (excluding onnxruntime libraries)
if [ "$PLATFORM" = "windows" ]; then
    MAIN_LIB=$(find "$TARGET_DIR" -name "*.dll" -type f ! -name "onnxruntime*" | head -1)
else
    MAIN_LIB=$(find "$TARGET_DIR" -name "libnpc_neural_affect_matrix.so" -type f | head -1)
fi

if [ -z "$MAIN_LIB" ]; then
    echo "❌ Could not find main library in $TARGET_DIR"
    exit 1
fi

# Copy libraries to dist
echo "Copying libraries to dist/..."
cp "$MAIN_LIB" "dist/"

# Copy ONNX Runtime libraries
if [ -f "$TARGET_DIR/$ONNX_RT_LIB" ]; then
    cp "$TARGET_DIR/$ONNX_RT_LIB" "dist/"
else
    echo "⚠️  Warning: $ONNX_RT_LIB not found"
fi

if [ -f "$TARGET_DIR/$ONNX_RT_PROVIDERS_LIB" ]; then
    cp "$TARGET_DIR/$ONNX_RT_PROVIDERS_LIB" "dist/"
else
    echo "⚠️  Warning: $ONNX_RT_PROVIDERS_LIB not found"
fi

# Also look for versioned ONNX Runtime libraries (Linux may have .so.1.22.1)
if [ "$PLATFORM" = "linux" ]; then
    find "$TARGET_DIR" -name "libonnxruntime.so*" -type f -exec cp {} "dist/" \;
    find "$TARGET_DIR" -name "libonnxruntime_providers_shared.so*" -type f -exec cp {} "dist/" \;
fi

echo ""
echo "✅ Build completed successfully for $PLATFORM!"
echo ""
echo "📦 Output files in dist/:"
ls -lh dist/
