# tools/ci/

What CI and the playtest builds run: installing the pinned Godot (and export templates), exporting the Windows and macOS builds, and `HOW-TO-PLAY.txt`, shipped in each build.

## Files

| File | What it is |
| --- | --- |
| `HOW-TO-PLAY.txt` | Shipped in each playtest build: how to start the game, and the first-launch warnings on Windows and macOS. |
| `export_builds.sh` | Exports the Windows and macOS playtest builds and zips |
| `install_godot.sh` | Installs the pinned Godot as `godot`, checksum- |
