--!strict
-- Thin executable wrapper around `examples/console_runner.luau` so the console
-- example can be launched directly via the Luau CLI.

local cliArgs = { ... }

package = package or {}
local original = package.path or ""
package.path = string.format("%s;./?.luau;../?.luau", original)

local warnFn = warn or print

local function runDirect(...: any)
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
end

local function tryModule()
        if not loadfile then
                return false
        end
        local loader, loadErr = loadfile("examples/console_runner.luau")
        if not loader then
                warnFn(string.format("[console] falling back to inline runner: %s", tostring(loadErr)))
                return false
        end
        local ok, runConsole = pcall(loader)
        if not ok or type(runConsole) ~= "function" then
                warnFn(string.format("[console] console runner module unavailable: %s", tostring(runConsole)))
                return false
        end
        local success, err = pcall(runConsole, table.unpack(cliArgs))
        if not success then
                error(err)
        end
        return true
end

if not tryModule() then
        runDirect(table.unpack(cliArgs))
end

package.path = original
