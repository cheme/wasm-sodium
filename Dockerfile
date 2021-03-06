FROM ubuntu:16.04

RUN apt-get update -y
RUN apt-get install -y \
  g++ \
  make \
  cmake \
  curl \
  xz-utils \
  python \
  git

WORKDIR /
RUN git clone https://github.com/rust-lang/llvm --depth=1 -b rust-llvm-release-7-0-0-v2
RUN mkdir /llvm/tools/clang
WORKDIR /llvm/tools
RUN git clone https://github.com/llvm-mirror/clang.git --depth=1 -b release_70
WORKDIR /
RUN git clone https://github.com/llvm-mirror/lld.git --depth=1 -b release_70
WORKDIR /llvm/build
RUN cmake .. \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/clang \
  -DLLVM_TARGETS_TO_BUILD=X86 \
  -DLLVM_ENABLE_PROJECTS=lld \
  -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD=WebAssembly
RUN make -j $(nproc)
RUN make install

# Install Rust as we'll use it later. We'll also be cribbing `lld` out of Rust's
# sysroot to use when compiling libsodium
ENV CARGO_HOME /cargo
ENV RUSTUP_HOME /rustup
RUN curl https://sh.rustup.rs | sh -s -- -y --default-toolchain nightly
ENV PATH $PATH:/cargo/bin:/rustup/toolchains/nightly-x86_64-unknown-linux-gnu/lib/rustlib/x86_64-unknown-linux-gnu/bin
RUN rustup target add wasm32-unknown-unknown

ENV CC /clang/bin/clang

WORKDIR /
RUN git clone https://github.com/jfbastien/musl --depth=1
WORKDIR /musl
ENV CFLAGS -O3 --target=wasm32-unknown-unknown-wasm -nostdlib -Wl,--no-entry
RUN CFLAGS="$CFLAGS -Wno-error=pointer-sign" ./configure --prefix=/musl-sysroot wasm32
RUN make -j$(nproc) install

WORKDIR /
#RUN curl https://download.libsodium.org/libsodium/releases/libsodium-1.0.16.tar.gz | tar xzf -
#WORKDIR /libsodium-1.0.16
RUN git clone	https://github.com/jedisct1/libsodium.git --depth=1
WORKDIR /libsodium
RUN apt-get install -y libtool autoconf
RUN CFLAGS="$CFLAGS --sysroot=/musl-sysroot -DSODIUM_STATIC"\
  ./autogen.sh
RUN ln -s /clang/bin/lld /bin/lld
# /clang/bin/lld (vue sur log)
RUN CFLAGS="$CFLAGS --sysroot=/musl-sysroot -DSODIUM_STATIC"\
  ./configure \
  --host=asmjs \
  --prefix=/musl-sysroot \
  --without-pthreads \
  --enable-minimal \
  --disable-asm \
  --disable-ssp
RUN make -j$(nproc) install
ENV SODIUM_LIB_DIR /musl-sysroot/lib
ENV SODIUM_STATIC 1
RUN rustup self uninstall -y
ENV PATH /rust/bin:$PATH
ENV SODIUM_INC_DIR /musl-sysroot/include
ENV LIBCLANG_PATH /clang/lib
# try openssl
WORKDIR /
RUN git clone https://github.com/openssl/openssl.git --depth=1
WORKDIR /openssl
RUN apt-get install -y libc6-dev-i386 
#RUN ./Configure linux-x86_64 no-asm no-hw  no-threads  no-shared no-engine no-dso
RUN CFLAGS="$CFLAGS --sysroot=/musl-sysroot "\
  ./Configure linux-x86 \
  --prefix=/musl-sysroot \
  --openssldir=/musl-sysroot \
  no-threads \
  no-shared \
  no-hw \
  no-engine \
  no-dso \
  no-asm \
  --target=wasm32-unknown-unknown-wasm \
  -nostdlib \
  -Wl,--rpath=/openssl \
  --sysroot=/musl-sysroot
#  -lcrypto \
#  -lssl
RUN CFLAGS="$CFLAGS --sysroot=/musl-sysroot "\
   make build_libs install_dev
#RUN CC=/clang/bin/clang; CFLAGS="$CFLAGS --target=wasm32-unknown-unknown-wasm -nostdlib -Wl,--no-entry"; ./Configure linux-x86_64 no-asm no-hw  no-threads  no-shared no-engine no-dso
#RUN CC=/clang/bin/clang; CFLAGS="$CFLAGS --target=wasm32-unknown-unknown-wasm -nostdlib -Wl,--no-entry"; make
#ENV LIB_CLANG /clang/include/clang
ENV OPENSSL_LIB_DIR /musl-sysroot/lib
ENV OPENSSL_INCLUDE_DIR /musl-sysroot/include
ENV OPENSSL_STATIC 1
ENV OPENSSL_LIBS ssl:crypto
ENV WASM32_UNKNOWN_UNKNOWN_OPENSSL_STATIC 1

