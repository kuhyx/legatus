# legatus

Realistic ancient battle simulator. You are the general, mounted, in first
person: you see only what a rider could see, move only as fast as a horse,
and command 50,000 men per side by courier.

Design: `DOCS-design.md`, from Bret Devereaux's ACOUP series
"Total Generalship: Commanding Pre-Modern Armies".

## Play

    ./run.sh

Installs whatever is missing (`install.sh`), rebuilds the C++ simulation if
it changed, and opens the battle. `./run.sh --help` lists the game options.

## Commands

| What | Command |
|---|---|
| Run (installs, builds) | `./run.sh` |
| Install only | `./install.sh` |
| Build C++ sim | `scripts/build.sh` |
| Tests | `scripts/test.sh` |
| Lint | `scripts/lint.sh` |
| Everything | `scripts/check.sh` |
| FPS bench (opens a window) | `scripts/bench.sh` |
