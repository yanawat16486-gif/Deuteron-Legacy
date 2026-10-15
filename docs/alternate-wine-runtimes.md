# Alternate Wine runtime support

NotProton currently treats a CrossOver app bundle as both the runtime source and the
runtime identity. Supporting other Wine distributions needs those concepts separated.

## First milestone

The first engine is pinned in `engine-lock.json`: Sikarugir Wine
`WS12WineSikarugir11.0_1` and Template `1.0.21`, with archive and x86_64 `ntdll`
hashes taken from the public NotProton-derived Sikarugir integration. This lock is
input data for the installer; it does not yet mean this repository can install or
run that engine. DXVK must be pinned separately before promising DX9 coverage.

Ship an engine manifest in the app. On first setup, download the selected macOS
Wine engine, verify its SHA-256, unpack it into NotProton's runner store, apply the
matching NotProton patch profile, and offer it as a Steam compatibility tool. Users
should not need to install CrossOver, Whisky, or Wine separately. Keep CrossOver as
an optional source with its existing license check.

Follow Highball's manifest pattern: pin each archive URL and checksum, describe
where its contents go, and identify the installed tree by engine ID. Highball ships
a Sikarugir Wine 10 engine and a separate Wine 11 option. A public NotProton
derivative also has a verified detour for Sikarugir
`WS12WineSikarugir11.0_1`. Use one specific archive as the first runtime, record its
source, architecture, clean hash, patch payload, and patched hash, then add other
builds after checking them.

## Runtime identity and safety

- Give every runner a source and build identity, such as `crossover/<build>` or
  `wine/<distribution>/<build>`.
- Describe archives with pinned checksums and explicit extraction destinations.
- Download into staging, verify before extraction, validate the completed Wine tree,
  then move it into NotProton's managed runner directory.
- Match known builds by hashes of the loader and every `ntdll.dll` that will be
  patched. Unknown builds remain visible as unsupported and are never patched.
- Keep per-build detour data and payloads separate from runtime discovery. A new
  Wine build needs a reviewed detour profile before it can be enabled.
- Make runner paths and prefix template names source-neutral while preserving the
  existing CrossOver paths when reading older installations.

## App changes

1. Add a `WineRuntimeSource` model that represents a runtime tree, its distribution,
   version, architectures, and hashes.
2. Replace CrossOver-only cloning with a source-neutral runner installer. Keep the
   CrossOver license check in the CrossOver source path.
3. Store runners by source and build, and retain a migration/read path for existing
   `crossover-*` folders and prefix templates.
4. Add an engine setup choice and report download, verification, extraction, and
   patching progress.
5. Add a pinned detour profile for the first verified Wine build, then expand the
   profile list as other builds are checked.

## Reference implementation

Highball's public source has a manifest-driven engine installer that downloads,
checksums, extracts into staging, validates required Wine files, and installs the
finished engine. Use it as a design reference while keeping NotProton's Steam
integration and app UI.

The public `Xipzer/mac-windows-gaming` project has a NotProton-derived path for
Sikarugir Wine 11. Its `ntdll-sikarugir11.json` pins exact byte ranges and its helper
refuses any `ntdll.dll` whose SHA-256 does not match. Use it as a reference for a
NotProton patch profile; the patch is specific to that build.

The app now bundles that Sikarugir 11 profile and can patch the installed x86_64
`ntdll.dll` only when its clean SHA-256 matches. It verifies the candidate's patched
SHA-256 before atomically replacing the original. The i386 `ntdll.dll` has no
verified profile yet and is left untouched. The profile data derives from the
GPL-3.0 NotProton fork in `Xipzer/mac-windows-gaming`.

`ntdll-patch/resolve.py` now accepts `NP_FORCE_LOAD_PATH` for a build whose
`build_module` stack slot does not match the resolver's heuristic. Set it only after
disassembly confirms the slot for that exact runtime build; the resulting patch must
still be pinned to the clean input hash and verified output hash before it is shipped.
