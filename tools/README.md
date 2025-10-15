# Tools

Developer-focused scripts and utilities for the Immortal module live in this
folder. The flagship utility is `immortal_error_analyzer.luau`, which can be
invoked via the repository root (`./scripts/luau immortal_error_analyzer.luau`)
or executed directly from within the tools directory. The root-level stub
exists to keep long-lived entrypoints stable while the implementation resides
next to its companion assets.

Additional helpers can be added here to keep the project root focused on the
production artefacts consumed by Roblox experiences.
