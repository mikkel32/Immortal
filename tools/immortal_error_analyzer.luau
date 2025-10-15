--!strict
--[[
        Immortal Error Analyzer

        This console-focused diagnostic script exercises the hardened Immortal
        module and the HTTP loader to proactively surface wiring issues. It
        performs staged validations, captures stack traces, and emits actionable
        hints so you can quickly identify misconfiguration or runtime errors.

        Usage (Luau CLI):
            luau immortal_error_analyzer.luau

        Optional flags:
            --skip-loader      Skip exercising the HTTP loader (module-only).
            --json             Emit a machine-readable JSON summary instead of
                               the human-readable report.
            --module-path=...  Override the path to `immortal.luau` for local
                               analysis (defaults to ./immortal.luau).
            --loader-path=...  Override the path to `loader.luau` when testing
                               the HTTP loader (defaults to ./loader.luau).
            --module-url=...   Override the synthetic URL fed to the loader
                               stub. When not provided, `immortal://local` is
                               used.
]]

local fmt = string.format

package = package or {}
package.path = (package.path or "") .. ";./?.luau;../?.luau"

local args = { ... }
local outputMode = "pretty"
local skipLoader = false
local modulePath = "../immortal.luau"
local loaderPath = "../loader.luau"
local moduleUrl = "immortal://local"

for _, arg in ipairs(args) do
        if arg == "--skip-loader" then
                skipLoader = true
        elseif arg == "--json" then
                outputMode = "json"
        elseif string.sub(arg, 1, 14) == "--module-path=" then
                modulePath = string.sub(arg, 15)
        elseif string.sub(arg, 1, 14) == "--loader-path=" then
                loaderPath = string.sub(arg, 15)
        elseif string.sub(arg, 1, 13) == "--module-url=" then
                moduleUrl = string.sub(arg, 14)
        end
end

local function now()
        if os and os.clock then
                return os.clock()
        end
        return nil
end

local function readFile(path: string): (string?, string?)
        if not io or not io.open then
                return nil, "io.open is unavailable in this environment"
        end
        local handle, openErr = io.open(path, "r")
        if not handle then
                return nil, openErr or fmt("unable to open %s", path)
        end
        local ok, contents = pcall(function()
                return handle:read("*a")
        end)
        handle:close()
        if not ok then
                return nil, fmt("failed to read %s: %s", path, tostring(contents))
        end
        return contents, nil
end

local function loadLuauChunk(path: string): (((...any) -> ...any)?, string?)
        local compiler = load or loadstring
        if not compiler then
                return nil, "load/loadstring is unavailable in this environment"
        end
        local source, readErr = readFile(path)
        if not source then
                return nil, readErr
        end
        local chunk, compileErr = compiler(source, "@" .. path)
        if not chunk then
                return nil, compileErr or "failed to compile chunk"
        end
        return chunk, nil
end

local function summarizeError(trace: string?): string
        if not trace then
                return "(no error message captured)"
        end
        local message = tostring(trace)
        local newline = string.find(message, "\n")
        if newline then
                return string.sub(message, 1, newline - 1)
        end
        return message
end

local function diagnoseFailure(trace: string?): { string }
        if not trace then
                return {}
        end
        local hints = {}
        local lower = string.lower(tostring(trace))
        if string.find(lower, "httpget") or string.find(lower, "download module") then
                table.insert(hints, "Provide a HttpGet/HttpGetAsync implementation (stub or real) before invoking the loader.")
        end
        if string.find(lower, "immortal module did not return a table") then
                table.insert(hints, "Verify the remote Immortal module URL and ensure it returns a module table.")
        end
        if string.find(lower, "unable to open") or string.find(lower, "failed to read") then
                table.insert(hints, "Check the local file paths passed to the analyzer; the module may be missing or moved.")
        end
        if string.find(lower, "attempt to call a nil value") and string.find(lower, "new") then
                table.insert(hints, "Immortal.new appears to be unavailable; confirm the module exported constructors correctly.")
        end
        if string.find(lower, "attempt to index nil") and string.find(lower, "immortal") then
                table.insert(hints, "Immortal instance may not have been created; inspect earlier failures for context.")
        end
        if string.find(lower, "destroy") and string.find(lower, "function expected") then
                table.insert(hints, "Immortal.destroy was not callable; ensure the instance came from Immortal.new or loader instantiate mode.")
        end
        return hints
end

local traceback = (debug and debug.traceback) or function(message: any)
        return tostring(message)
end

local SAFE_IMMORTAL_CONFIG = {
        autoUI = false,
        autoHookCharacter = false,
        showStats = false,
        ballsFolder = nil,
}

type StageResult = {
        stage: string,
        ok: boolean,
        duration: number?,
        value: any?,
        error: string?,
        hints: { string }?,
        details: string?,
}

local results: { StageResult } = {}

local function record(stage: string, operation: () -> any, describeSuccess: ((any) -> string)?)
        local start = now()
        local ok, valueOrErr = xpcall(operation, traceback)
        local finish = now()

        local entry: StageResult = {
                stage = stage,
                ok = ok,
                duration = (start and finish) and (finish - start) or nil,
        }

        if ok then
                entry.value = valueOrErr
                if describeSuccess then
                        local okDescribe, description = pcall(describeSuccess, valueOrErr)
                        if okDescribe then
                                entry.details = description
                        else
                                entry.details = fmt("(detail error) %s", summarizeError(description))
                        end
                elseif valueOrErr ~= nil then
                        local valueType = typeof and typeof(valueOrErr) or type(valueOrErr)
                        if valueType == "boolean" or valueType == "number" or valueType == "string" then
                                entry.details = tostring(valueOrErr)
                        elseif valueType == "table" then
                                entry.details = "[table]"
                        end
                end
        else
                entry.error = tostring(valueOrErr)
                entry.hints = diagnoseFailure(entry.error)
        end

        table.insert(results, entry)
        return entry
end

local function createGameStub(): (any, { string })
        local requests: { string } = {}
        local stub = {}
        function stub:HttpGetAsync(url: string)
                table.insert(requests, url)
                if url == moduleUrl then
                        local source, readErr = readFile(modulePath)
                        if not source then
                                error(readErr)
                        end
                        return source
                end
                error(fmt("[HttpStub] Unexpected URL: %s", tostring(url)))
        end
        stub.HttpGet = stub.HttpGetAsync
        return stub, requests
end

local function withGameStub(stub: any, callback: () -> any)
        local previousGame = rawget(_G, "game")
        rawset(_G, "game", stub)
        local ok, result = xpcall(callback, traceback)
        rawset(_G, "game", previousGame)
        if not ok then
                error(result)
        end
        return result
end

-- Stage 1: require the module
local ImmortalModuleEntry = record("require ../immortal", function()
        return require("../immortal")
end, function(moduleTable)
        local valueType = typeof and typeof(moduleTable) or type(moduleTable)
        local hasNew = (type(moduleTable) == "table" and type(moduleTable.new) == "function")
        return fmt("type=%s | has_new=%s", valueType, tostring(hasNew))
end)

local immortalInstanceEntry: StageResult? = nil
if ImmortalModuleEntry.ok then
        local ImmortalModule = ImmortalModuleEntry.value
        immortalInstanceEntry = record("Immortal.new(console config)", function()
                return ImmortalModule.new(SAFE_IMMORTAL_CONFIG)
        end, function(instance)
                local fields = {}
                for key, value in pairs(instance) do
                        if type(value) == "function" then
                                table.insert(fields, key)
                        end
                end
                table.sort(fields)
                local previewCount = math.min(3, #fields)
                local preview = {}
                for index = 1, previewCount do
                        preview[index] = fields[index]
                end
                local enabledState = nil
                if type(instance) == "table" and type(instance.isEnabled) == "function" then
                        local okState, state = pcall(function()
                                return instance:isEnabled()
                        end)
                        if okState then
                                enabledState = state
                        end
                end
                local summary = fmt("methods~=%d", #fields)
                if previewCount > 0 then
                        summary = summary .. fmt(" | sample=%s", table.concat(preview, ","))
                end
                if enabledState ~= nil then
                        summary = summary .. fmt(" | enabled=%s", tostring(enabledState))
                end
                return summary
        end)
end

local immortalToggleEntry: StageResult? = nil
if immortalInstanceEntry and immortalInstanceEntry.ok then
        local immortalInstance = immortalInstanceEntry.value
        immortalToggleEntry = record("Immortal:setEnabled(true/false)", function()
                immortalInstance:setEnabled(true)
                local afterEnable = immortalInstance:isEnabled()
                immortalInstance:setEnabled(false)
                local afterDisable = immortalInstance:isEnabled()
                return { afterEnable = afterEnable, afterDisable = afterDisable }
        end, function(payload)
                return fmt("afterEnable=%s | afterDisable=%s", tostring(payload.afterEnable), tostring(payload.afterDisable))
        end)

        record("Immortal:destroy()", function()
                immortalInstance:destroy()
                return "destroyed"
        end)
end

local loaderModuleEntry: StageResult? = nil
local loaderInstanceEntry: StageResult? = nil
local loaderDiagnosticsAvailable = (io and io.open and (load or loadstring)) ~= nil
if not loaderDiagnosticsAvailable then
        if not skipLoader then
                table.insert(results, {
                        stage = "loader diagnostics (skipped)",
                        ok = true,
                        duration = nil,
                        value = nil,
                        error = nil,
                        hints = nil,
                        details = "skipped (Luau CLI sandbox lacks io/load primitives)",
                })
        end
        skipLoader = true
end
if not skipLoader then
        loaderModuleEntry = record("loader fetch module table", function()
                local stub, requests = createGameStub()
                local chunk, loadErr = loadLuauChunk(loaderPath)
                if not chunk then
                        error(loadErr)
                end
                local payload = withGameStub(stub, function()
                        return chunk({
                                moduleUrl = moduleUrl,
                        })
                end)
                return {
                        module = payload,
                        requests = requests,
                }
        end, function(payload)
                local moduleTable = payload.module
                local requestCount = #payload.requests
                local hasNew = (type(moduleTable) == "table" and type(moduleTable.new) == "function")
                return fmt("type=%s | requests=%d | has_new=%s", type(moduleTable), requestCount, tostring(hasNew))
        end)

        if loaderModuleEntry.ok then
                loaderInstanceEntry = record("loader instantiate Immortal", function()
                        local stub, requests = createGameStub()
                        local chunk, loadErr = loadLuauChunk(loaderPath)
                        if not chunk then
                                error(loadErr)
                        end
                        local instance = withGameStub(stub, function()
                                return chunk({
                                        moduleUrl = moduleUrl,
                                        instantiate = true,
                                        autoEnable = false,
                                        immortalConfig = SAFE_IMMORTAL_CONFIG,
                                })
                        end)
                        return {
                                instance = instance,
                                requests = requests,
                                stub = stub,
                        }
                end, function(payload)
                        local instance = payload.instance
                        local requestCount = #payload.requests
                        local summaryParts = { fmt("requests=%d", requestCount) }
                        if type(instance) == "table" then
                                local okState, enabledState = pcall(function()
                                        if type(instance.isEnabled) == "function" then
                                                return instance:isEnabled()
                                        end
                                        return nil
                                end)
                                if okState and enabledState ~= nil then
                                        table.insert(summaryParts, fmt("enabled=%s", tostring(enabledState)))
                                end
                                table.insert(summaryParts, fmt("has_destroy=%s", tostring(type(instance.destroy) == "function")))
                        else
                                table.insert(summaryParts, fmt("type=%s", type(instance)))
                        end
                        return table.concat(summaryParts, " | ")
                end)

                if loaderInstanceEntry.ok then
                        local payload = loaderInstanceEntry.value
                        record("loader instance destroy()", function()
                                return withGameStub(payload.stub, function()
                                        payload.instance:destroy()
                                        return "destroyed"
                                end)
                        end)
                end
        end
end

local function buildJson()
        local function escape(str: string)
                local replacements = {
                        ["\\"] = "\\\\",
                        ["\""] = "\\\"",
                        ["\n"] = "\\n",
                        ["\r"] = "\\r",
                        ["\t"] = "\\t",
                }
                return (str:gsub("[\\\"\n\r\t]", function(ch)
                        return replacements[ch] or ch
                end))
        end

        local function toJson(value: any): string
                local valueType = typeof and typeof(value) or type(value)
                if valueType == "nil" then
                        return "null"
                elseif valueType == "number" or valueType == "boolean" then
                        return tostring(value)
                elseif valueType == "string" then
                        return "\"" .. escape(value) .. "\""
                elseif valueType == "table" then
                        local isArray = true
                        local count = 0
                        for key, _ in pairs(value) do
                                count += 1
                                if type(key) ~= "number" then
                                        isArray = false
                                        break
                                end
                        end
                        if isArray then
                                local buffer = {}
                                for index = 1, #value do
                                        buffer[index] = toJson(value[index])
                                end
                                return "[" .. table.concat(buffer, ",") .. "]"
                        else
                                local buffer = {}
                                for key, val in pairs(value) do
                                        table.insert(buffer, "\"" .. escape(tostring(key)) .. "\":" .. toJson(val))
                                end
                                table.sort(buffer)
                                return "{" .. table.concat(buffer, ",") .. "}"
                        end
                end
                return "\"" .. escape(tostring(value)) .. "\""
        end

        local entries = {}
        for _, entry in ipairs(results) do
                local serialized = {
                        stage = entry.stage,
                        ok = entry.ok,
                        durationMs = entry.duration and entry.duration * 1000 or nil,
                        details = entry.details,
                        error = entry.error,
                        hints = entry.hints,
                }
                table.insert(entries, serialized)
        end
        return toJson(entries)
end

local function printPretty()
        print("=== Immortal Error Analyzer ===")
        for _, entry in ipairs(results) do
                local status = entry.ok and "[OK]  " or "[FAIL]"
                local durationSuffix = ""
                if entry.duration then
                        durationSuffix = fmt(" (%.2f ms)", entry.duration * 1000)
                end
                print(fmt("%s %s%s", status, entry.stage, durationSuffix))
                if entry.details then
                        print(fmt("        -> %s", entry.details))
                end
                if not entry.ok then
                        print(fmt("        error: %s", summarizeError(entry.error)))
                        if entry.hints and #entry.hints > 0 then
                                for _, hint in ipairs(entry.hints) do
                                        print(fmt("        hint: %s", hint))
                                end
                        end
                end
        end

        local successCount = 0
        local failureCount = 0
        local maxDuration = 0
        local slowest: StageResult? = nil
        for _, entry in ipairs(results) do
                if entry.ok then
                        successCount += 1
                else
                        failureCount += 1
                end
                if entry.duration and entry.duration > maxDuration then
                        maxDuration = entry.duration
                        slowest = entry
                end
        end
        print("")
        print(fmt("Summary: %d/%d stages succeeded", successCount, #results))
        if slowest then
                        print(fmt("Slowest stage: %s (%.2f ms)", slowest.stage, maxDuration * 1000))
        end

        if maxDuration > 0 then
                print("\nStage durations:")
                local scale = 1
                if maxDuration > 0 then
                        scale = 40 / (maxDuration * 1000)
                end
                for _, entry in ipairs(results) do
                        if entry.duration then
                                local ms = entry.duration * 1000
                                local barLength = math.max(1, math.floor(ms * scale + 0.5))
                                local bar = string.rep("█", math.min(barLength, 40))
                                print(fmt("  %-4s %-32s %6.2f ms %s", entry.ok and "OK" or "FAIL", entry.stage, ms, bar))
                        else
                                print(fmt("  %-4s %-32s    n/a   (timing unavailable)", entry.ok and "OK" or "FAIL", entry.stage))
                        end
                end
        end
end

if outputMode == "json" then
        print(buildJson())
else
        printPretty()
end
