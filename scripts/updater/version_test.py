"""Tests for version parsing and comparison."""

from __future__ import annotations

import unittest
from unittest.mock import patch

from updater.version import (
    compare_versions,
    fetch_github_latest_release,
    parse_version,
    should_update,
)


class TestParseVersion(unittest.TestCase):
    def test_strips_single_v_prefix(self) -> None:
        self.assertEqual(parse_version("v1.2.3"), ([1, 2, 3], ""))

    def test_only_one_leading_v_is_stripped(self) -> None:
        # lstrip("v") would eat every leading v and yield numeric [1, 0].
        numeric, _suffix = parse_version("vv1.0")
        self.assertEqual(numeric, [])

    def test_date_style_version(self) -> None:
        self.assertEqual(
            parse_version("2025.11.06-8fe8a63"), ([2025, 11, 6], "8fe8a63")
        )


class TestCompareVersions(unittest.TestCase):
    def test_release_beats_prerelease(self) -> None:
        self.assertEqual(compare_versions("1.0.0", "1.0.0-beta"), 1)

    def test_should_update(self) -> None:
        self.assertTrue(should_update("1.0.0", "1.0.1"))
        self.assertFalse(should_update("1.0.1", "1.0.0"))


class TestFetchGithubLatestRelease(unittest.TestCase):
    def test_strips_only_the_v_prefix(self) -> None:
        # A tag whose name starts with more than one 'v' must not be mangled
        # (lstrip("v") turns "voxterm-0.3.0" into "oxterm-0.3.0").
        with patch(
            "updater.version.fetch_json",
            return_value={"tag_name": "voxterm-0.3.0"},
        ):
            self.assertEqual(
                fetch_github_latest_release("owner", "repo"), "voxterm-0.3.0"
            )

    def test_plain_v_tag(self) -> None:
        with patch("updater.version.fetch_json", return_value={"tag_name": "v1.2.3"}):
            self.assertEqual(fetch_github_latest_release("owner", "repo"), "1.2.3")


if __name__ == "__main__":
    unittest.main(verbosity=2)
