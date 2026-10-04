#!/usr/bin/env bash
set -euo pipefail

test "$(dpkg --print-architecture)" = amd64
dpkg --print-foreign-architectures | grep -qx arm64
dpkg-query -W -f='${Package}:${Architecture} ${Status}\n' \
    clang gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu llvm \
    zlib1g-dev:amd64 zlib1g-dev:arm64 qemu-user-static binfmt-support \
    flatpak flatpak-builder elfutils

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT
cat > "$work_dir/smoke.c" <<'EOF'
#include <stdio.h>
#include <zlib.h>

int main(void)
{
    printf("ARM64 zlib %s\n", zlibVersion());
    return 0;
}
EOF

for compiler in gcc clang; do
    if [ "$compiler" = gcc ]; then
        aarch64-linux-gnu-gcc -g "$work_dir/smoke.c" \
            -L/usr/lib/aarch64-linux-gnu -lz -o "$work_dir/$compiler"
    else
        clang -g --target=aarch64-linux-gnu --gcc-toolchain=/usr "$work_dir/smoke.c" \
            -L/usr/lib/aarch64-linux-gnu -lz -o "$work_dir/$compiler"
    fi
    aarch64-linux-gnu-readelf -h "$work_dir/$compiler" | grep 'Machine:.*AArch64'
    llvm-objcopy --only-keep-debug "$work_dir/$compiler" "$work_dir/$compiler.debug"
    eu-strip -f "$work_dir/$compiler.elfutils.debug" "$work_dir/$compiler"
    eu-elfcompress -t zlib "$work_dir/$compiler.elfutils.debug"
    # Explicit emulation verifies the image without claiming host binfmt is registered.
    qemu-aarch64-static -L /usr/aarch64-linux-gnu \
        -E LD_LIBRARY_PATH=/usr/lib/aarch64-linux-gnu "$work_dir/$compiler"
done

flatpak --version
flatpak-builder --version
eu-strip --version
eu-elfcompress --version
