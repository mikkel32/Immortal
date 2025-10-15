-- Console runner for the Immortal module using the Luau CLI.
-- The Immortal module now provides its own console-safe stubs when the
-- Roblox runtime objects are unavailable. To keep the repository organised,
-- the actual runner implementation lives in `examples/console_runner.luau`.
-- This file remains as a backwards-compatible entrypoint and falls back to
-- an inline implementation when the example cannot be loaded (for instance,
-- inside file-system restricted sandboxes).

local function runFallback()
        package = package or {}
        local originalPath = package.path or ""
        package.path = originalPath .. ";./?.luau"

        local Immortal = require("./immortal")

        print("[console] Immortal module loaded.")
        local immortal = Immortal.new({
                autoUI = false,
                autoHookCharacter = false,
                showStats = false,
                ballsFolder = nil,
        })

        print(string.format("[console] Enabled by default? %s", tostring(immortal:isEnabled())))
        immortal:setEnabled(true)
        print(string.format("[console] Enabled after setEnabled(true)? %s", tostring(immortal:isEnabled())))
        immortal:setEnabled(false)
        print(string.format("[console] Enabled after setEnabled(false)? %s", tostring(immortal:isEnabled())))

        print("[console] Immortal console run completed.")

        package.path = originalPath
end

local function tryRunExample(...: any)
        package = package or {}
        local originalPath = package.path or ""
        package.path = string.format("%s;./?.luau;./?/init.luau", originalPath)

        local ok, runner = pcall(require, "examples.console_runner")

        package.path = originalPath

        if ok and type(runner) == "function" then
                local success, err = pcall(runner, ...)
                if not success then
                        error(err)
                end
                return true
        end

        return false
end

if not tryRunExample(...) then
        runFallback()
end
