# LumenWeave Shaders

- `shaders/` is the Iris/OpenGL preview. Keep `/lib/...` includes relative to the pack's `shaders/` root. Keep shader source and language files in UTF-8 without BOM.
- Keep Iris entry points close to the stages that own them. Verify buffer formats, flip behavior, and compute barriers against the pinned loader before introducing a new pass.
- Keep GPU feature probes in `experiments/` and package them separately from the preview.
- Run `python tools/check_shaders.py`, `python -m unittest discover -s tests -v`, and package the active pack, P0 baseline (`--p0`), and voxel probe (`--voxel-probe`) after shader changes. Record the game, loader, GPU, and actual runtime coverage for game or performance claims.
- Keep MakeUp references pinned and record file-level origin and attribution before importing external code.
- Keep work logs local under `.codex/`. Obtain explicit approval before pushing or publishing.
- Run game tests on isolated background desktops with `soundCategory_master:0.0`. Keep the user's foreground desktop and game settings untouched.

- The `develop` branch owns AGENTS.md, tests, tools, experiments and technical audit notes. `main` is the distributed player-facing source. Publish only the public source tree and release archives; do not blindly merge development-only paths back into main. Run the complete validation suite before release. Iris parsing tests are mandatory in addition to GLSL compilation.
