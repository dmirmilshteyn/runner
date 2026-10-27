# runner

Custom Ubuntu x64 image for Actions Runner Controller (ARC). The build workflow
publishes only `linux/amd64`; ARM64 is a cross-compilation and packaging target.

## Bundled .NET security verification

The base Actions runner is pinned to `2.338.2` and its immutable image digest.
It bundles .NET `8.0.33` for Listener, Worker, and PluginHost, addressing
[CVE-2026-111497](https://github.com/dotnet/announcements/issues/494).
Installing a separate SDK would not update these self-contained applications.

After pushing, the build workflow pulls the published image by digest, checks
all three runtime configurations, audits the image for additional .NET runtimes,
compares CoreCLR and the native compression binary with Microsoft's
runtime distribution, and starts the listener with `--version`. The image digest
and verification result are recorded in the workflow summary. Run the same audit
locally with:

```sh
docker run --rm --platform linux/amd64 --user root \
  -v "$PWD/scripts:/checks:ro" --entrypoint python3 \
  IMAGE@sha256:DIGEST /checks/verify-dotnet-runtime.py
```

The binary hashes in the check come from
[Microsoft's linux-x64 .NET 8.0.33 runtime archive](https://builds.dotnet.microsoft.com/dotnet/Runtime/8.0.33/dotnet-runtime-8.0.33-linux-x64.tar.gz),
verified against [official release metadata](https://builds.dotnet.microsoft.com/dotnet/release-metadata/8.0/releases.json).
The archive's SHA-512 is
`b314039d337a8c5c4be6a6f99712a2618cbeb5e1ab7cac7a5c1cbf1c97bd355f5d116b9932a8cfc604ac7849f74638896eba0534892c6518311908aba29b4f7b`.
Review and refresh these checks when updating the base runner/runtime.

## ARM64 toolchain

The image includes Git LFS with system-wide filters, Clang and LLVM 21 from the
signed LLVM apt repository, and matching amd64 libc++ and libc++abi development
libraries for native C++ linking. LLVM's bin directory is first on PATH so its
compiler finds the matching static runtime archives required by Needle.
It also includes the ARM64 GCC/binutils toolchain and development
libraries for zlib on both amd64 and arm64, Flatpak, Flatpak Builder, elfutils
(`eu-strip` and `eu-elfcompress`), and static
QEMU user emulators. Existing Ubuntu/PPA and HashiCorp sources are limited to
amd64. ARM64 packages come from Ubuntu Ports, including the matching release,
updates, backports, and security suites.

Build and check the toolchain locally:

```sh
docker build --platform linux/amd64 -t runner:arm64-toolchain .
docker run --rm --platform linux/amd64 \
  -v "$PWD/scripts:/checks:ro" runner:arm64-toolchain \
  bash /checks/verify-arm64-toolchain.sh
```

The check compiles and links ARM64 programs against ARM64 zlib using GCC and
Clang, checks the ELF architecture and LLVM tooling, and runs them by explicitly
invoking QEMU. It also strips and compresses ARM64 debug information with
elfutils and checks the installed packages and Flatpak/elfutils tool versions.
Explicit QEMU execution does **not** verify transparent execution through binfmt.

For .NET NativeAOT, install the required .NET SDK in the job and publish with
`dotnet publish path/to/app.csproj -c Release -r linux-arm64 -p:PublishAot=true`.
For Flatpak, install the manifest's matching ARM64 runtime and SDK, then use
`flatpak-builder --arch=aarch64 build-dir manifest.json`. Flatpak uses `aarch64`
as its architecture name. Actual Flatpak builds also need the host setup below
and permission to create their usual Bubblewrap sandbox; follow the deployment's
Flatpak sandbox policy.

## Host setup for ARM64 execution

ARC runs the image in Kubernetes pods. ARM64 Flatpak builds can execute target
SDK tools inside their sandboxes, so every amd64 worker node eligible to run
these jobs needs a registered `qemu-aarch64` binfmt handler. Registration is
kernel state on the **worker node**, not part of the image. Installing
`qemu-user-static` and `binfmt-support` during `docker build` does not provision
that state on future runner hosts.

On Ubuntu 24.04 worker nodes, provision the following through the node image or your
normal node bootstrap process, as root:

```sh
sudo apt-get update
sudo apt-get install -y qemu-user-static binfmt-support
sudo systemctl restart systemd-binfmt
cat /proc/sys/fs/binfmt_misc/qemu-aarch64
```

Ubuntu 24.04's `qemu-user-static` supplies
`/usr/lib/binfmt.d/qemu-aarch64.conf` for `systemd-binfmt`, with an interpreter
at `/usr/libexec/qemu-binfmt/aarch64-binfmt-P` and flags `OPF`. It does not supply
a `qemu-aarch64` definition for `update-binfmts`; installing `binfmt-support`
alone is insufficient. The systemd service reads the package configuration at
boot and on restart, on the actual node.

The handler must be `enabled`, have an interpreter provided by the node's QEMU
installation, and include `F` in its flags. The `F` (fix-binary) flag keeps the
interpreter available across container and Flatpak mount namespaces. If the
entry is absent or lacks `F`, correct the node's binfmt configuration before
scheduling these jobs. Keep registration persistent across node reboots and
provision replacement nodes too. A cluster-managed privileged registration
DaemonSet is an alternative if supported by your platform; it must install the
ARM64 handler with `F` on each eligible node. Regular runner jobs should not
register handlers themselves.

After provisioning, check `/proc/sys/fs/binfmt_misc/qemu-aarch64` on the node and
verify transparent ARM64 execution from an ordinary runner pod, for example:

```sh
printf 'int main(void) { return 0; }\n' > /tmp/arm64-smoke.c
aarch64-linux-gnu-gcc -static /tmp/arm64-smoke.c -o /tmp/arm64-smoke
/tmp/arm64-smoke
rm /tmp/arm64-smoke.c /tmp/arm64-smoke
```

Run this without a QEMU command prefix. Then validate an actual ARM64 Flatpak
build with the intended runtime, SDK, and manifest to verify sandbox behavior.
For local Docker testing, provision the **Docker daemon's Linux host/VM**, which
may differ from the machine running the Docker CLI.

This checkout contains the image build workflow but no ARC deployment manifests
or worker-node bootstrap configuration. Host registration and cluster sandbox
permissions must therefore be applied and verified by the deployment operator;
an image build or the toolchain check above cannot establish them.
