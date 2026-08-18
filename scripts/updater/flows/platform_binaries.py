"""Update flow for packages that repackage prebuilt per-platform binaries."""

from __future__ import annotations

import json
from typing import TYPE_CHECKING

from updater.fetch import PurlFetcher, Resolved
from updater.hashes_file import load_hashes, save_hashes
from updater.purl import Purl
from updater.version import should_update

if TYPE_CHECKING:
    from collections.abc import Callable
    from pathlib import Path


def update_platform_binaries(
    pkg_dir: Path,
    *,
    fetch_latest: Callable[[], str],
    url_template: str,
    platforms: dict[str, str],
    allow_downgrade: bool = False,
) -> None:
    """Update a package that repackages prebuilt per-platform binaries.

    ``url_template`` takes ``{version}`` and ``{platform}``. Version discovery
    stays with ``fetch_latest``; the URL matrix and hashing run through a
    ``pkg:generic`` purl carrying the template and platform map.
    """
    hashes_file = pkg_dir / "hashes.json"
    data = load_hashes(hashes_file)
    current = data["version"]
    latest = fetch_latest()

    print(f"Current: {current}, Latest: {latest}")

    changed = current != latest if allow_downgrade else should_update(current, latest)
    if not changed:
        print("Already up to date")
        return

    fetcher = PurlFetcher.default()
    purl = Purl(
        "generic",
        None,
        pkg_dir.name,
        qualifiers={
            "x_download_url": url_template,
            "x_platforms": json.dumps(platforms),
        },
    )
    hashes = fetcher.hashes(purl, Resolved(version=latest, ref=latest))

    save_hashes(hashes_file, {"version": latest, "hashes": hashes})
    print(f"Updated to {latest}")
