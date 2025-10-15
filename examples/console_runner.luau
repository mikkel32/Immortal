--!strict
--[=[
        Immortal console runner reusable implementation.

        This module exports a single function that executes the console
        integration test when invoked. It is consumed by both
        `examples/run_console.luau` (for direct CLI execution) and the
        backwards-compatible `run_immortal.luau` entrypoint at the repository
        root.
]=]

local function withPatchedPackagePath<T>(callback: () -> T): T
        package = package or {}
        local original = package.path or ""
        package.path = string.format("%s;./?.luau;../?.luau", original)
        local ok, result = pcall(callback)
        package.path = original
        if not ok then
                error(result)
        end
        return result :: T
end

local function runConsole()
        return withPatchedPackagePath(function()
                local Immortal = require("../immortal")

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
        end)
end

return runConsole
