# Immortal Console Runner

This repository packages the hardened Immortal auto-parry module together with a
lightweight Luau console runner so you can exercise core functionality without a
full Roblox client.

## Prerequisites

1. Build the Luau CLI (once per machine):
   ```bash
   git clone https://github.com/Roblox/luau.git
   cmake -S luau -B luau/build -DCMAKE_BUILD_TYPE=Release
   cmake --build luau/build --target Luau.Repl.CLI -j
   ```
   The CLI binary will be available at `luau/build/luau`.

2. Ensure the `luau` binary is on your `PATH` **or** reference it directly when
   running the console script.

## Running Immortal in the console

Execute the bundled Luau script:

```bash
luau run_immortal.luau
```

(or `/tmp/luau/build/luau run_immortal.luau` if you built Luau in `/tmp`).

The Immortal module automatically provisions console-safe stubs for Roblox
services whenever it detects that the real runtime is unavailable. The runner
simply instantiates the module, toggles it on/off, and prints the resulting log
messages so you can verify that everything wires up correctly.
