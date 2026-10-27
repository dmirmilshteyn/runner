#!/usr/bin/env python3
"""Verify the published amd64 runner's self-contained .NET security update."""

import hashlib
import json
import os
from pathlib import Path


# SHA-256 of files from Microsoft's dotnet-runtime-8.0.33-linux-x64.tar.gz.
# The archive's SHA-512 was verified against the official 8.0 releases.json;
# see README.md for the archive URL and checksum.
expected_hashes = {
    "libcoreclr.so": "c299094f70481c4aab71114761d05f207f48f94e8f7c76eee0bc5c2ebfeb4436",
    "libSystem.IO.Compression.Native.so": "a897b9af1b2c3359ac2e20168b4d31c3549581c6415daa989caac65fd5385950",
}
runtime_markers = set(expected_hashes) | {"System.Private.CoreLib.dll"}
runner_bin = Path("/home/runner/bin")
expected_configs = {
    runner_bin / f"Runner.{name}.runtimeconfig.json"
    for name in ("Listener", "Worker", "PluginHost")
}
found_configs = set()
found_binaries = set()


def fail_walk(error):
    raise error


# Audit the entire image, including any additional self-contained .NET tools.
# Unexpected runtimes fail closed so they must be reviewed when the image changes.
for directory, subdirs, files in os.walk("/", onerror=fail_walk):
    if directory == "/":
        subdirs[:] = [name for name in subdirs if name not in ("proc", "sys", "dev", "checks")]
    for name in files:
        path = Path(directory) / name
        if name.endswith(".runtimeconfig.json"):
            found_configs.add(path)
        if name in runtime_markers:
            found_binaries.add(path)

if found_configs != expected_configs:
    raise RuntimeError(f"Unexpected .NET application inventory: {sorted(map(str, found_configs))}")
for path in sorted(found_configs):
    options = json.loads(path.read_text())["runtimeOptions"]
    frameworks = options.get("includedFrameworks")
    if frameworks != [{"name": "Microsoft.NETCore.App", "version": "8.0.33"}]:
        raise RuntimeError(f"Unexpected runtime in {path}: {options}")
    print(f"{path}: Microsoft.NETCore.App 8.0.33")

if found_binaries != {runner_bin / name for name in runtime_markers}:
    raise RuntimeError(f"Unexpected .NET runtime binaries: {sorted(map(str, found_binaries))}")
for name, expected in expected_hashes.items():
    path = runner_bin / name
    actual = hashlib.sha256(path.read_bytes()).hexdigest()
    if actual != expected:
        raise RuntimeError(f"Runtime binary mismatch: {path}: {actual}")
    print(f"{path}: SHA-256 {actual} (Microsoft .NET 8.0.33)")
