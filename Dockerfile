FROM rust:latest

# Build argument for target platform (windows or linux)
ARG TARGET_PLATFORM=windows

RUN apt-get update && apt-get install -y \
   wget \
   unzip \
   clang \
   lld \
   llvm \
   && rm -rf /var/lib/apt/lists/*

# Windows-specific toolchain setup
RUN if [ "$TARGET_PLATFORM" = "windows" ]; then \
   ln -sf /usr/bin/clang /usr/bin/clang-cl && \
   ln -sf /usr/bin/lld /usr/bin/lld-link && \
   ln -sf /usr/bin/llvm-ar /usr/bin/llvm-lib; \
   fi

# Add Rust target based on platform
RUN if [ "$TARGET_PLATFORM" = "windows" ]; then \
   rustup target add x86_64-pc-windows-msvc; \
   else \
   rustup target add x86_64-unknown-linux-gnu; \
   fi

# Install xwin for Windows cross-compilation
RUN if [ "$TARGET_PLATFORM" = "windows" ]; then \
   cargo install xwin --locked; \
   fi

WORKDIR /app

# Download Windows SDK for cross-compilation
# Use --disable-symlinks to avoid issues and speed up the process
RUN if [ "$TARGET_PLATFORM" = "windows" ]; then \
   xwin --accept-license splat --output /opt/xwin --disable-symlinks || \
   (echo "First attempt failed, retrying with longer timeout..." && sleep 10 && \
    xwin --accept-license splat --output /opt/xwin --disable-symlinks); \
   fi

# Create lowercase symlinks for Windows libraries (xwin uses uppercase .Lib)
RUN if [ "$TARGET_PLATFORM" = "windows" ]; then \
   cd /opt/xwin/sdk/lib/um/x86_64 && \
   for file in *.Lib; do \
      lowercase=$(echo "$file" | tr '[:upper:]' '[:lower:]'); \
      if [ "$file" != "$lowercase" ]; then \
         ln -sf "$file" "$lowercase"; \
      fi; \
   done; \
   fi

# Windows-specific environment variables
RUN if [ "$TARGET_PLATFORM" = "windows" ]; then \
   echo 'export CC_x86_64_pc_windows_msvc="clang-cl"' >> /etc/profile.d/rust-windows.sh && \
   echo 'export CXX_x86_64_pc_windows_msvc="clang-cl"' >> /etc/profile.d/rust-windows.sh && \
   echo 'export AR_x86_64_pc_windows_msvc="llvm-lib"' >> /etc/profile.d/rust-windows.sh && \
   echo 'export CARGO_TARGET_X86_64_PC_WINDOWS_MSVC_LINKER="lld-link"' >> /etc/profile.d/rust-windows.sh && \
   echo 'export RUSTFLAGS="-Lnative=/opt/xwin/crt/lib/x86_64 -Lnative=/opt/xwin/sdk/lib/um/x86_64 -Lnative=/opt/xwin/sdk/lib/ucrt/x86_64 -C link-arg=/LIBPATH:/opt/xwin/sdk/lib/um/x86_64"' >> /etc/profile.d/rust-windows.sh && \
   echo 'export CFLAGS_x86_64_pc_windows_msvc="-target x86_64-pc-windows-msvc -I/opt/xwin/crt/include -I/opt/xwin/sdk/include/ucrt -I/opt/xwin/sdk/include/um -I/opt/xwin/sdk/include/shared"' >> /etc/profile.d/rust-windows.sh && \
   echo 'export CXXFLAGS_x86_64_pc_windows_msvc="-target x86_64-pc-windows-msvc -I/opt/xwin/crt/include -I/opt/xwin/sdk/include/ucrt -I/opt/xwin/sdk/include/um -I/opt/xwin/sdk/include/shared -EHsc"' >> /etc/profile.d/rust-windows.sh; \
   fi

# Download and setup ONNX Runtime based on platform
RUN if [ "$TARGET_PLATFORM" = "windows" ]; then \
   wget -O onnxruntime.zip "https://github.com/microsoft/onnxruntime/releases/download/v1.22.1/onnxruntime-win-x64-1.22.1.zip" && \
   unzip onnxruntime.zip && \
   mkdir -p /app/onnxruntime && \
   cp -r onnxruntime-win-x64-1.22.1/* /app/onnxruntime/ && \
   rm -rf onnxruntime.zip onnxruntime-win-x64-1.22.1/; \
   else \
   wget -O onnxruntime.tgz "https://github.com/microsoft/onnxruntime/releases/download/v1.19.2/onnxruntime-linux-x64-1.19.2.tgz" && \
   tar -xzf onnxruntime.tgz && \
   mkdir -p /app/onnxruntime && \
   cp -r onnxruntime-linux-x64-1.19.2/* /app/onnxruntime/ && \
   rm -rf onnxruntime.tgz onnxruntime-linux-x64-1.19.2/; \
   fi

# Set ONNX Runtime environment variables
ENV ORT_LIB_LOCATION=/app/onnxruntime/lib
ENV ORT_SKIP_DOWNLOAD=true
ENV ORT_PREFER_DYNAMIC_LINK=true
ENV ORT_STRATEGY=system
ENV ORT_DYLIB_PATH=/app/onnxruntime/lib
ENV SKIP_SETUP=1

# Verify Windows toolchain installation (if Windows)
RUN if [ "$TARGET_PLATFORM" = "windows" ]; then \
   which clang-cl && which lld-link && which llvm-lib; \
   fi

# Build command that adapts to platform
CMD sh -c ' \
   if [ "$TARGET_PLATFORM" = "windows" ]; then \
      . /etc/profile.d/rust-windows.sh && \
      export RUSTFLAGS="${RUSTFLAGS} -L /app/onnxruntime/lib" && \
      export TARGET_TRIPLE="x86_64-pc-windows-msvc" && \
      export LIB_EXT="dll"; \
   else \
      export TARGET_TRIPLE="x86_64-unknown-linux-gnu" && \
      export LIB_EXT="so"; \
   fi && \
   echo "Building with RUSTFLAGS: $RUSTFLAGS" && \
   cargo build --target $TARGET_TRIPLE --release --lib && \
   mkdir -p /app/target/$TARGET_TRIPLE/release && \
   find /app/onnxruntime -name "*.$LIB_EXT" -exec cp -v {} /app/target/$TARGET_TRIPLE/release/ \;'
