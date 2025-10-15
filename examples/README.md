# Examples

This directory hosts runnable scripts that demonstrate how to integrate the
Immortal module outside of Roblox Studio. The primary entrypoint is
`run_console.luau`, which bootstraps the module using the Luau CLI and
verifies the core lifecycle methods. The shared implementation lives in
`console_runner.luau` so other scripts (including `run_immortal.luau`) can
reuse the same harness.

All example scripts should be self-contained and callable through the
repository's Luau wrapper:

```bash
./scripts/luau examples/run_console.luau
```

Keeping examples in their own directory keeps the repository root focused on
the production module and loader artefacts that are fetched by `loadstring`
within Roblox experiences.
