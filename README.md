# NotProton Wine Runtimes

An experimental fork of [NotProton](https://github.com/NotProtonNot/NotProton) exploring selectable Wine engines for Steam Play on macOS.

The current development branch adds an installer and initial integration path for Sikarugir Wine 11, plus per-game graphics renderer settings. This work is in progress and has not been qualified across games or macOS configurations. CrossOver remains supported through the existing NotProton path.

## Current status

- Development branch: `codex/alternate-wine-runtimes`
- First managed engine: Sikarugir Wine 11
- Graphics options are experimental; D9VK support is limited to the Sikarugir runtime integration.
- DXVK/MoltenVK and other renderer combinations are not yet verified as a complete DX9–12 solution.

Please include the macOS version, Steam version, game, selected engine and renderer, and relevant NotProton log excerpts when reporting a problem. Remove account names, personal paths, and other private details from logs before sharing them.

## Contributing

Issues and pull requests are welcome. Please keep changes focused and include the exact runtime build and test result for compatibility or patch changes. Runtime patch profiles must match verified input and output hashes.

## Upstream and license

This repository is a fork of [NotProtonNot/NotProton](https://github.com/NotProtonNot/NotProton). NotProton is licensed under GPL-3.0; third-party components may have separate licenses. See `LICENSE`, `NOTICE`, and the individual license files before redistributing.
