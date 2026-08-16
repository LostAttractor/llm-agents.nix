#!/usr/bin/env python3
"""Apply byte-length-preserving source patches inside app.asar.

The asar header records file offsets, so every replacement is padded with
spaces to the original's exact byte length instead of re-packing the archive.
"""

import sys
from pathlib import Path

# @parcel/watcher uses detect-libc in a named worker. Its process.report
# fallback trips a CFI guard in the bundled Owl/Electron runtime on NixOS.
# detect-libc falls back to its ELF/filesystem/ldd probes instead.
SKIP_PROCESS_REPORT = (
    b"isLinux() && process.report",
    b"false /* nix:skip report */",
)

# The app materializes bundled plugins in ~/.codex and rewrites selected
# manifests there. Node's fs.cp preserves the Nix store's read-only modes,
# so copy with coreutils and make only the user-owned destination writable.
COPY_PLUGINS_WRITABLE = (
    b'async function Mne(e,t){if(S.default.platform===`darwin`){await lne(`/usr/bin/ditto`,[`--noqtn`,e,t]);return}if(S.default.platform!==`win32`){await y.default.cp(e,t,{recursive:!0,verbatimSymlinks:!0});return}let{copyDirectoryAllowDecryptedDestinationOnEncryptionFailure:n}=await Promise.resolve().then(()=>require("./windows-file-copy-Bw9CB6bJ.js"));await n({copy:()=>y.default.cp(e,t,{recursive:!0,verbatimSymlinks:!0}),destination:t,source:e})}',
    b'async function Mne(e,t){let r=S.default.platform;if(r===`darwin`){await lne(`/usr/bin/ditto`,[`--noqtn`,e,t]);return}if(r!==`win32`){await lne(`cp`,[`-r`,e+`/.`,t]);await lne(`chmod`,[`-R`,`u+w`,t]);return}let{copyDirectoryAllowDecryptedDestinationOnEncryptionFailure:n}=await Promise.resolve().then(()=>require("./windows-file-copy-Bw9CB6bJ.js"));await n({copy:()=>y.default.cp(e,t,{recursive:!0,verbatimSymlinks:!0}),destination:t,source:e})}',
)


def main() -> None:
    """Patch the asar archive given as the only argument."""
    asar = Path(sys.argv[1])
    data = asar.read_bytes()
    for original, replacement in (SKIP_PROCESS_REPORT, COPY_PLUGINS_WRITABLE):
        if len(replacement) > len(original):
            sys.exit(f"replacement longer than original: {replacement[:60]!r}...")
        if original not in data:
            sys.exit(f"pattern not found in {asar}: {original[:60]!r}...")
        data = data.replace(original, replacement.ljust(len(original), b" "))
    asar.write_bytes(data)


if __name__ == "__main__":
    main()
