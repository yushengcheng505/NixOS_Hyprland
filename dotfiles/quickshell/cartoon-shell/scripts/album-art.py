#!/usr/bin/env python3
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from urllib.parse import urlsplit


CACHE_LIMIT = 50 * 1024 * 1024
IMAGE_LIMIT = 5 * 1024 * 1024
CACHE_NAME = re.compile(r"[0-9a-f]{64}\.img\Z")
PROXY = "http://127.0.0.1:2080"


def image_file(path):
    size = path.stat().st_size
    if not 0 < size <= IMAGE_LIMIT:
        return False
    with path.open("rb") as stream:
        header = stream.read(16)
    return (
        header.startswith(b"\xff\xd8\xff")
        or header.startswith(b"\x89PNG\r\n\x1a\n")
        or header.startswith((b"GIF87a", b"GIF89a"))
        or (header.startswith(b"RIFF") and header[8:12] == b"WEBP")
    )


def prune(directory, limit):
    files = [
        path for path in directory.iterdir()
        if CACHE_NAME.fullmatch(path.name) and path.is_file() and not path.is_symlink()
    ]
    files.sort(key=lambda path: (path.stat().st_mtime_ns, path.name))
    total = sum(path.stat().st_size for path in files)
    for path in files:
        if total <= limit:
            break
        size = path.stat().st_size
        path.unlink()
        total -= size


def curl_config(url):
    return 'url = "' + url.replace("\\", "\\\\").replace('"', '\\"') + '"\n'


def download(url, destination, proxy):
    command = [
        "curl", "--disable", "--silent", "--show-error", "--fail", "--location",
        "--proto", "=http,https", "--proto-redir", "=http,https", "--max-redirs", "3",
        "--connect-timeout", "5", "--max-time", "15", "--max-filesize", str(IMAGE_LIMIT),
        "--proxy", PROXY if proxy else "", "--noproxy", "" if proxy else "*",
        "--output", str(destination), "--config", "-",
    ]
    try:
        result = subprocess.run(
            command, input=curl_config(url), text=True, stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL, timeout=18, check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return False
    return result.returncode == 0 and image_file(destination)


def cache_art(directory, url):
    parsed = urlsplit(url)
    if (
        parsed.scheme not in ("http", "https") or not parsed.hostname
        or parsed.username is not None or parsed.password is not None
        or len(url) > 8192 or any(ord(char) < 32 or ord(char) == 127 for char in url)
    ):
        raise ValueError("Unsupported album art URL")
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    target = directory / (hashlib.sha256(url.encode("utf-8")).hexdigest() + ".img")
    with (directory / ".lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        for partial in directory.glob("*.part"):
            if partial.is_file() or partial.is_symlink():
                partial.unlink()
        if target.is_symlink():
            target.unlink()
        if target.exists():
            if image_file(target):
                os.utime(target, None)
                prune(directory, CACHE_LIMIT)
                return target.resolve().as_uri()
            target.unlink()
        prune(directory, CACHE_LIMIT - IMAGE_LIMIT)
        descriptor, name = tempfile.mkstemp(suffix=".part", dir=directory)
        os.close(descriptor)
        temporary = Path(name)
        try:
            for proxy in (True, False):
                temporary.write_bytes(b"")
                if download(url, temporary, proxy):
                    temporary.replace(target)
                    prune(directory, CACHE_LIMIT)
                    return target.resolve().as_uri()
            raise ValueError("Album art download failed")
        finally:
            temporary.unlink(missing_ok=True)


def main():
    os.umask(0o077)
    url = sys.stdin.readline(8194).strip()
    try:
        source = cache_art(Path(sys.argv[1]), url)
        result = {"source": source, "error": ""}
    except (OSError, ValueError, IndexError):
        result = {"source": "", "error": "Album art unavailable"}
    print(json.dumps(result))
    return 0 if result["source"] else 1


if __name__ == "__main__":
    sys.exit(main())
