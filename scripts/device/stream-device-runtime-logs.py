#!/usr/bin/env python3

from __future__ import annotations

import os
import subprocess


def main() -> int:
    device_id = os.getenv("YOUTUBEFEEDER_DEVICE_ID", "55F9A799-6DA8-59A7-A64E-E78239F84351")
    bundle_id = os.getenv("YOUTUBEFEEDER_APP_BUNDLE_ID", "Neko.YoutubeFeeder")
    print(f"[stream-device-runtime-logs] device={device_id} bundle={bundle_id}")
    print("[stream-device-runtime-logs] launching with YOUTUBEFEEDER_RUNTIME_LOGGING=1")
    process = subprocess.run(
        [
            "xcrun",
            "devicectl",
            "device",
            "process",
            "launch",
            "--device",
            device_id,
            "--terminate-existing",
            "--console",
            "--environment-variables",
            '{"YOUTUBEFEEDER_RUNTIME_LOGGING":"1"}',
            bundle_id,
        ],
        check=False,
    )
    return process.returncode


if __name__ == "__main__":
    raise SystemExit(main())
