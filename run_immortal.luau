-- Console runner for the Immortal module using the Luau CLI.
-- The Immortal module now provides its own console-safe stubs when the
-- Roblox runtime objects are unavailable, so this script simply requires
-- the module and exercises a few public APIs.

package = package or {}
package.path = (package.path or "") .. ";./?.luau"

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
