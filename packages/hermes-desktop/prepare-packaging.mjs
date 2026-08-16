#!/usr/bin/env node

// Prepare bundled Desktop metadata for electron-builder. Runtime dependencies
// are staged in dist, so source-only workspace dependencies must not reach
// electron-builder 26.x's cycle-unsafe collector.

import fs from "node:fs"
import path from "node:path"

const desktopRoot = path.resolve(process.argv[2] || ".")
const at = relative => path.join(desktopRoot, relative)

const bundleScript = fs.readFileSync(at("scripts/bundle-electron-main.mjs"), "utf8")
const externalList = bundleScript.match(/const\s+external\s*=\s*\[([^\]]*)\]/s)
if (!externalList) {
  throw new Error("cannot verify Electron bundle externals")
}

const externals = [...externalList[1].matchAll(/["']([^"']+)["']/g)]
  .map(match => match[1])
  .sort()
const expected = ["electron", "fs", "get-windows", "node-pty"]
if (JSON.stringify(externals) !== JSON.stringify(expected)) {
  throw new Error(
    `review Electron bundle externals before pruning dependencies: ${JSON.stringify(externals)}`
  )
}

const stagedNodePty = at("dist/node_modules/node-pty")
if (!fs.existsSync(path.join(stagedNodePty, "package.json"))) {
  throw new Error("staged node-pty package.json is missing")
}
const releaseDir = path.join(stagedNodePty, "build/Release")
const nativePayloads = fs.readdirSync(releaseDir).filter(name => name.endsWith(".node"))
if (nativePayloads.length === 0) {
  throw new Error("staged node-pty native payload is missing")
}

const stagedGetWindows = at("dist/node_modules/get-windows")
if (!fs.existsSync(path.join(stagedGetWindows, "package.json"))) {
  throw new Error("staged get-windows package.json is missing")
}

const manifestPath = at("package.json")
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"))
manifest.dependencies = {}
fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}
`)
