--!strict
--[[
        Immortal HTTP bootstrapper

        This loader is designed to be executed directly through
        loadstring(game:HttpGet(...))(). It fetches the hardened Immortal module
        from this repository, returns the module table by default, and can optionally
        instantiate and auto-enable the module when requested through configuration.

        Example usages:

            -- Fetch the module table (most explicit control)
            local Immortal = loadstring(game:HttpGet("https://raw.githubusercontent.com/mikkel32/Immortal/main/loader.luau"))()

            -- Instantiate immediately with the default configuration and auto-enable it
            local immortal = loadstring(game:HttpGet("https://raw.githubusercontent.com/mikkel32/Immortal/main/loader.luau"))({
                    instantiate = true,
            })

            -- Instantiate with custom Immortal.new options, without auto enabling
            local immortal = loadstring(game:HttpGet("https://raw.githubusercontent.com/mikkel32/Immortal/main/loader.luau"))({
                    instantiate = true,
                    autoEnable = false,
                    immortalConfig = {
                            autoUI = true,
                            showStats = true,
                    },
            })

        You can override the branch or raw module URL by passing `branch` or `moduleUrl`
        inside the configuration table.
]]

local HttpGet = game and game.HttpGetAsync or (game and game.HttpGet)
if not HttpGet then
        error("game:HttpGetAsync or game:HttpGet is required to use the Immortal loader")
end

local DEFAULT_OWNER = "mikkel32"
local DEFAULT_REPO = "Immortal"
local DEFAULT_BRANCH = "main"
local MODULE_PATH = "immortal.luau"

local function buildModuleUrl(branch: string): string
        return string.format(
                "https://raw.githubusercontent.com/%s/%s/%s/%s",
                DEFAULT_OWNER,
                DEFAULT_REPO,
                branch,
                MODULE_PATH
        )
end

local function fetchSource(url: string): string
        local ok, result = pcall(function()
                return HttpGet(game, url)
        end)
        if not ok or type(result) ~= "string" then
                error(string.format("[ImmortalLoader] Failed to download module: %s", tostring(result)))
        end
        return result
end

local function resolveConfig(options: any?)
        if options == nil then
                return {
                        branch = DEFAULT_BRANCH,
                        autoEnable = true,
                        instantiate = false,
                        immortalConfig = nil,
                        moduleUrl = nil,
                }
        end

        if type(options) ~= "table" then
                error("[ImmortalLoader] Expected table configuration or nil")
        end

        return {
                branch = options.branch or DEFAULT_BRANCH,
                autoEnable = options.autoEnable ~= false,
                instantiate = options.instantiate == true,
                immortalConfig = options.immortalConfig,
                moduleUrl = options.moduleUrl,
        }
end

local function loadImmortal(options: any?)
        local config = resolveConfig(options)
        local moduleUrl = config.moduleUrl or buildModuleUrl(config.branch)

        local source = fetchSource(moduleUrl)
        local ImmortalModule = loadstring(source, "@Immortal.module")()
        if type(ImmortalModule) ~= "table" then
                error("[ImmortalLoader] Immortal module did not return a table")
        end

        if not config.instantiate then
                return ImmortalModule
        end

        local immortalInstance = ImmortalModule.new(config.immortalConfig or {})
        if config.autoEnable then
                immortalInstance:setEnabled(true)
        end
        return immortalInstance
end

return loadImmortal(...)
