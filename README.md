# Immortal Console Runner

This repository packages the hardened Immortal auto-parry module together with a
lightweight Luau console runner so you can exercise core functionality without a
full Roblox client.

## Prerequisites

The repository now ships with a self-installing Luau CLI wrapper. The first
time you execute `./scripts/luau` it will download the official Luau release for
your platform, cache it inside `.luau-cli/`, and reuse it for subsequent runs.

No manual toolchain setup is required beyond having `curl` and `unzip`
available (they are bundled with most developer environments and CI images).
If you need to pin a specific Luau release, set `IMMORTAL_LUAU_VERSION` before
invoking the wrapper (for example `IMMORTAL_LUAU_VERSION=0.695 ./scripts/luau`).

## Running Immortal in the console

Execute the bundled Luau script:

```bash
./scripts/luau run_immortal.luau
```

The Immortal module automatically provisions console-safe stubs for Roblox
services whenever it detects that the real runtime is unavailable. The runner
simply instantiates the module, toggles it on/off, and prints the resulting log
messages so you can verify that everything wires up correctly.

## Advanced error analysis

For a deeper validation pass, the repository ships with
`immortal_error_analyzer.luau`. It orchestrates a series of staged diagnostics
that (1) require the module, (2) instantiate it with console-safe settings,
(3) toggle it on and off, and (4) optionally exercise the HTTP loader via a
synthetic `HttpGet` stub. Every stage is wrapped in rich error capture logic
that reports stack traces, heuristic hints, and per-stage timing so you can
quickly root-cause misconfiguration.

```bash
./scripts/luau immortal_error_analyzer.luau
```

Use `--skip-loader` to focus solely on the local module, or `--json` to emit a
machine-readable summary you can pipe into automated tooling. Additional flags
allow you to override the module path, loader path, or the synthetic loader URL
used during diagnostics. Arguments are passed directly after the script path,
for example `./scripts/luau immortal_error_analyzer.luau --skip-loader`.

> **Note:** The official Luau CLI builds ship without file-system APIs. When
> running inside that sandbox, the analyzer will automatically skip loader
> diagnostics and surface a "skipped" entry to document the limitation.

## Loading the module from Roblox with `loadstring`

To pull the latest hardened Immortal build directly into a Roblox experience,
use the bundled HTTP loader. It fetches `immortal.luau` from the repository and
returns the module table by default, while optionally supporting one-line
instantiation.

```lua
-- Fetch the module table so you can manage instantiation yourself
local Immortal = loadstring(game:HttpGet("https://raw.githubusercontent.com/mikkel32/Immortal/main/loader.luau"))()

-- Or instantiate immediately (auto-enabled by default)
local immortal = loadstring(game:HttpGet("https://raw.githubusercontent.com/mikkel32/Immortal/main/loader.luau"))({
        instantiate = true,
})
```

Additional loader options allow you to override the branch, provide a custom
raw file URL, disable auto-enable, or pass through any `Immortal.new`
configuration in `immortalConfig`.
