--!strict
-- mikkel32/AutoParry : src/core/immortal.lua
-- IMMORTAL (Independent UI, Safe Ping, Ultra-Verbose)
-- ✅ Fixes: UI sometimes not appearing — we now hard-wait for PlayerGui and confirm visibly.
-- ✅ Avoids Stats/memory spam; safe ping provider (AUTO/STATS/FIXED).
-- ✅ Adds a green "UI ONLINE" banner and panel status lamp so you can see it mounted.

print("[IMMORTAL] module loaded (UI-hardened, Safe Ping Provider)")

local _global = _G :: any
local _shared = (_global and rawget(_global, "shared")) :: any
local game = (_global and rawget(_global, "game")) or (_shared and rawget(_shared, "game"))

if not game then
        local function makeSignal()
                local signal = { _connections = {} }
                function signal:Connect(callback)
                        table.insert(self._connections, callback)
                        return {
                                Disconnect = function()
                                        for i, fn in ipairs(signal._connections) do
                                                if fn == callback then
                                                        table.remove(signal._connections, i)
                                                        break
                                                end
                                        end
                                end,
                        }
                end
                function signal:Fire(...)
                        for _, fn in ipairs(self._connections) do
                                fn(...)
                        end
                end
                return signal
        end

        local function createConsoleStub(): any
                if not table.create then
                        function table.create(n, value)
                                local t = {}
                                for i = 1, n do
                                        t[i] = value
                                end
                                return t
                        end
                end

                if not math.clamp then
                        function math.clamp(x, minValue, maxValue)
                                if x < minValue then
                                        return minValue
                                elseif x > maxValue then
                                        return maxValue
                                end
                                return x
                        end
                end

                if not math.sign then
                        function math.sign(x)
                                if x > 0 then
                                        return 1
                                elseif x < 0 then
                                        return -1
                                end
                                return 0
                        end
                end

                local Vector3Methods = {}
                function Vector3Methods.Magnitude(self)
                        return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
                end
                function Vector3Methods.Unit(self)
                        local mag = Vector3Methods.Magnitude(self)
                        if mag < 1e-6 then
                                return Vector3.zero
                        end
                        return Vector3.new(self.X / mag, self.Y / mag, self.Z / mag)
                end
                function Vector3Methods.Dot(self, other)
                        return self.X * other.X + self.Y * other.Y + self.Z * other.Z
                end
                function Vector3Methods.Cross(self, other)
                        return Vector3.new(
                                self.Y * other.Z - self.Z * other.Y,
                                self.Z * other.X - self.X * other.Z,
                                self.X * other.Y - self.Y * other.X
                        )
                end

                local Vector3_mt = {}
                Vector3_mt.__index = function(self, key)
                        if key == "Magnitude" then
                                return Vector3Methods.Magnitude(self)
                        elseif key == "Unit" then
                                return Vector3Methods.Unit(self)
                        else
                                return Vector3Methods[key]
                        end
                end
                Vector3_mt.__add = function(a, b)
                        return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
                end
                Vector3_mt.__sub = function(a, b)
                        return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
                end
                Vector3_mt.__unm = function(a)
                        return Vector3.new(-a.X, -a.Y, -a.Z)
                end
                Vector3_mt.__mul = function(a, b)
                        if type(a) == "number" then
                                return Vector3.new(a * b.X, a * b.Y, a * b.Z)
                        elseif type(b) == "number" then
                                return Vector3.new(a.X * b, a.Y * b, a.Z * b)
                        else
                                error("Vector3 multiplication supports scalar operands only in console mode")
                        end
                end
                Vector3_mt.__div = function(a, b)
                        return Vector3.new(a.X / b, a.Y / b, a.Z / b)
                end
                Vector3_mt.__eq = function(a, b)
                        return math.abs(a.X - b.X) < 1e-6 and math.abs(a.Y - b.Y) < 1e-6 and math.abs(a.Z - b.Z) < 1e-6
                end

                Vector3 = Vector3 or {}
                function Vector3.new(x, y, z)
                        return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3_mt)
                end
                Vector3.zero = Vector3.new(0, 0, 0)

                CFrame = CFrame or {}
                local CFrame_mt = { __index = {} }
                function CFrame.new(x, y, z)
                        if type(x) == "table" then
                                local v = x
                                return setmetatable({ Position = Vector3.new(v.X, v.Y, v.Z) }, CFrame_mt)
                        end
                        return setmetatable({ Position = Vector3.new(x or 0, y or 0, z or 0) }, CFrame_mt)
                end
                setmetatable(CFrame, { __call = function(_, ...) return CFrame.new(...) end })

                Enum = Enum or {}
                Enum.KeyCode = Enum.KeyCode or { G = "G" }
                Enum.ZIndexBehavior = Enum.ZIndexBehavior or { Sibling = "Sibling" }
                Enum.UserInputState = Enum.UserInputState or { Begin = "Begin" }
                Enum.ContextActionResult = Enum.ContextActionResult or { Pass = "Pass", Sink = "Sink" }
                Enum.Font = Enum.Font or { GothamBold = "GothamBold", Gotham = "Gotham" }
                Enum.RaycastFilterType = Enum.RaycastFilterType or { Exclude = "Exclude" }

                Color3 = Color3 or {}
                function Color3.fromRGB(r, g, b)
                        return { R = r, G = g, B = b }
                end

                Vector2 = Vector2 or {}
                function Vector2.new(x, y)
                        return { X = x, Y = y }
                end

                UDim = UDim or {}
                function UDim.new(scale, offset)
                        return { Scale = scale, Offset = offset }
                end

                UDim2 = UDim2 or {}
                function UDim2.new(xScale, xOffset, yScale, yOffset)
                        return {
                                X = UDim.new(xScale, xOffset),
                                Y = UDim.new(yScale, yOffset),
                        }
                end

                local RunService = {
                        _isClient = true,
                }
                RunService.Heartbeat = makeSignal()
                function RunService:IsClient()
                        return self._isClient
                end

                local ContextActionService = {}
                function ContextActionService:BindAction(name, callback)
                        self._bound = self._bound or {}
                        self._bound[name] = callback
                end
                function ContextActionService:UnbindAction(name)
                        if self._bound then
                                self._bound[name] = nil
                        end
                end

                local UserInputService = {}
                function UserInputService:GetFocusedTextBox()
                        return nil
                end

                local Workspace = {}
                function Workspace:GetPartBoundsInBox()
                        return {}
                end

                local StarterGui = {}
                local Players = { LocalPlayer = nil }

                local Stats = {}
                function Stats:GetTotalMemoryUsageMb()
                        return 0
                end

                local Random_mt = {}
                Random_mt.__index = Random_mt
                function Random_mt:NextNumber(minValue, maxValue)
                        minValue = minValue or 0
                        maxValue = maxValue or 1
                        return minValue + (maxValue - minValue) * math.random()
                end
                function Random_mt:NextInteger(minValue, maxValue)
                        return math.random(minValue, maxValue)
                end

                Random = Random or {}
                function Random.new(seed)
                        if seed then
                                math.randomseed(seed)
                        end
                        return setmetatable({}, Random_mt)
                end

                OverlapParams = OverlapParams or {}
                function OverlapParams.new()
                        return {
                                FilterType = nil,
                                MaxParts = nil,
                                FilterDescendantsInstances = {},
                        }
                end

                local function makeInstance(className)
                        local instance = {
                                ClassName = className,
                                Name = className,
                                Parent = nil,
                        }
                        function instance:IsA(target)
                                return target == className
                        end
                        function instance:FindFirstChild()
                                return nil
                        end
                        function instance:FindFirstChildOfClass()
                                return nil
                        end
                        function instance:Destroy()
                                self.Parent = nil
                        end
                        return instance
                end

                Instance = Instance or {}
                function Instance.new(className)
                        return makeInstance(className)
                end

                local services = {
                        Players = Players,
                        RunService = RunService,
                        Workspace = Workspace,
                        ContextActionService = ContextActionService,
                        UserInputService = UserInputService,
                        StarterGui = StarterGui,
                        Stats = Stats,
                }

                local gameStub = {}
                function gameStub:GetService(name)
                        return services[name]
                end

                local taskStub = task or {
                        wait = function(seconds)
                                return seconds or 0
                        end,
                        delay = function(_, callback)
                                if type(callback) == "function" then
                                        callback()
                                end
                        end,
                        spawn = function(callback)
                                if type(callback) == "function" then
                                        callback()
                                end
                        end,
                }

                return {
                        game = gameStub,
                        Vector3 = Vector3,
                        CFrame = CFrame,
                        Enum = Enum,
                        Color3 = Color3,
                        Vector2 = Vector2,
                        UDim = UDim,
                        UDim2 = UDim2,
                        Random = Random,
                        OverlapParams = OverlapParams,
                        Instance = Instance,
                        task = taskStub,
                        time = time or os.clock,
                }
        end

        local consoleStub = createConsoleStub()
        game = consoleStub.game
        Vector3 = consoleStub.Vector3
        CFrame = consoleStub.CFrame
        Enum = consoleStub.Enum
        Color3 = consoleStub.Color3
        Vector2 = consoleStub.Vector2
        UDim = consoleStub.UDim
        UDim2 = consoleStub.UDim2
        Random = consoleStub.Random
        OverlapParams = consoleStub.OverlapParams
        Instance = consoleStub.Instance
        task = task or consoleStub.task
        time = time or consoleStub.time
end

local Players               = game:GetService("Players")
local RunService            = game:GetService("RunService")
local Workspace             = game:GetService("Workspace")
local ContextActionService  = game:GetService("ContextActionService")
local UserInputService      = game:GetService("UserInputService")
local StarterGui            = game:GetService("StarterGui")

local Stats: any
pcall(function() Stats = game:GetService("Stats") end)

local Immortal = {}
Immortal.__index = Immortal

-- math
local min, max = math.min, math.max
local sin, cos = math.sin, math.cos
local TAU = 2*math.pi
local HUGE = math.huge
local V3_ZERO = Vector3.zero
local CF_NEW = CFrame.new

-- gameplay constants (unchanged core)
local MAX_RANGE_FROM_BALL = 80.0
local HUMANOID_RADIUS     = 2.1
local SAFE_MARGIN         = 1.1
local Y_HOVER             = 6.0

local H_BASE, H_SPEED_GAIN, H_PING_GAIN = 1.0, 0.007, 0.8
local H_MIN, H_MAX = 0.7, 2.0

local N_T_FINE, N_T_COARSE = 8, 8
local CENTER_FRACTIONS = { 0.0, 0.15, 0.3, 0.5, 0.7, 1.0 }

local RADII_PRIMARY = { 44.0, 56.0, 68.0, 76.0, 80.0 }
local RADII_BACKUP  = { 80.0, 72.0, 64.0 }
local EXTRA_LAYERS_Y= { -2.0, 0.0, 2.0 }
local N_DIRS = 44

local PING_MULT = 1.30
local LATENCY_FACTOR = 1.0
local ACCEL_DECAY=0.92
local ACCEL_FLOOR=60.0
local ACCEL_CAP  =500.0
local CURV_DECAY =0.90
local CURV_CAP   =0.60
local CURV_SCALE =0.72
local A_EMA=0.35
local A_VEC_CAP=600.0

local IMMEDIATE_DANGER_TTI  = 0.075
local IMMEDIATE_DANGER_RAD  = 6.0
local IMMEDIATE_DANGER_RAD2 = IMMEDIATE_DANGER_RAD*IMMEDIATE_DANGER_RAD
local TP_CD_SAFE, TP_CD_DANGER = 0.012, 0.005

local SAFE_MARGIN2_STRONG = 81.0
local SAFE_MARGIN2_MIN    = 9.0
local NUDGE_PROB          = 0.06
local NUDGE_GAIN2         = 8.0

local CONE_BASE_DEG, CONE_SPEED_GAIN, CONE_DEG_MAX = 28.0, 0.10, 75.0

local DRIFT_GUARD        = 2.5
local HYSTERESIS_WEIGHT2 = 6.0
local CHAIN_TRIGGER2     = 4.0

local FPS_EMA_ALPHA=0.15
local PING_SAMPLE_PERIOD=0.14
local BALL_SCAN_PERIOD=0.30

local DIR_STRIDE_AT_35FPS=3
local DIR_STRIDE_AT_55FPS=2
local TIME_STRIDE_AT_35FPS=2
local SPEED_NO_DOWNSHIFT=120

local COLLISION_BOX = Vector3.new(4.2,7.4,4.2)
local MAX_OCCUPANCY_PARTS = 1
local OBSTACLE_FAN_RADIUS = {0.0,2.0,4.0,6.0}
local OBSTACLE_FAN_DIRS = 12

local DEFAULT_TOGGLE_KEY = Enum.KeyCode.G
local UI_NAME        = "ImmortalUI"
local UI_ACTION_NAME = "ImmortalToggleAction"

-- helpers
local function fnum(n:number) return string.format("%.3f",n) end
local function fv3(v:Vector3) return string.format("(%.2f,%.2f,%.2f)",v.X,v.Y,v.Z) end
local function safeUnit(v:Vector3) if v.Magnitude>1e-6 then return v.Unit else return V3_ZERO end end
local function ballRadiusOf(p:BasePart) local s=p.Size; local r=math.max(s.X,math.max(s.Y,s.Z)); return 0.5*r end
local function clampToRange(ball:Vector3, p:Vector3) local d=p-ball; local m=d.Magnitude; if m>MAX_RANGE_FROM_BALL and m>1e-6 then return ball + d*(MAX_RANGE_FROM_BALL/m) end; return p end

local function isInstanceDestroyed(i:Instance?) : boolean
	if not i then return true end
	if i.Parent then
		local ok,isDesc = pcall(i.IsDescendantOf,i,game)
		return not ok or not isDesc
	end
	return true
end

local function futureBallPos2(bPos:Vector3,bVel:Vector3,aVec:Vector3?,t:number,ping:number):Vector3
	local look=t+ping*PING_MULT; if look<0 then look=0 end
	if aVec and aVec~=V3_ZERO then return bPos + bVel*look + aVec*(0.5*look*look) end
	return bPos + bVel*look
end

local function createTimeBasis()
	local basis={}
	if N_T_FINE>1 then for k=0,N_T_FINE-1 do local f=k/(N_T_FINE-1); basis[#basis+1]=f*f end else basis[#basis+1]=0.0 end
	if N_T_COARSE>0 then local dt=1/max(N_T_COARSE-1,1); for j=1,N_T_COARSE-1 do basis[#basis+1]=j*dt end end
	basis[#basis]=1.0; return basis
end
local T_BASIS = createTimeBasis()

local function createDirs(rng:Random,n:number):{Vector3}
	local dirs=table.create(n); local phase=rng:NextNumber(0,TAU)
	for i=1,n do local th=phase+TAU*(i-1)/n; dirs[i]=Vector3.new(cos(th),0,sin(th)) end
	return dirs
end

local function isBallValid(ball:Instance?) return ball and ball:IsA("BasePart") and ball:IsDescendantOf(Workspace) end

-- =========
-- Options
-- =========
export type Options = {
	player: Player?, character: Model?, humanoid: Humanoid?, rootPart: BasePart?,
	ballsFolder: Instance?,
	autoUI: boolean?, toggleKey: Enum.KeyCode?, autoHookCharacter: boolean?,
	showStats: boolean?, traceLevel: number?,
	pingMode: string?, fixedPingMs: number?,
}

-- =========
-- Construct
-- =========
function Immortal.new(options: Options?)
	options = options or {}
	local self = setmetatable({}, Immortal)

	-- context
	self._player    = options.player or (RunService:IsClient() and Players.LocalPlayer or nil)
	self._character = options.character or (self._player and self._player.Character) or nil
	self._humanoid  = options.humanoid or (self._character and self._character:FindFirstChildOfClass("Humanoid") or nil)
	self._rootPart  = options.rootPart
	if not self._rootPart and self._character then
		local rp = self._character:FindFirstChild("HumanoidRootPart")
		if rp and rp:IsA("BasePart") then self._rootPart = rp end
	end
	self._ballsFolder = options.ballsFolder

	-- core state
	self._rng = Random.new()
	self._dirs = createDirs(self._rng,N_DIRS)
	self._timeBuffer, self._radiusBuffer, self._mpcCenters = table.create(#T_BASIS), table.create(#T_BASIS), table.create(#CENTER_FRACTIONS)
	self._enabled = false; self._heartbeat=nil
	self._lastTeleport=0.0; self._lastGoodTarget=nil; self._nextBackupTarget=nil; self._lastMoveDir=nil
	self._lastBallVel=nil; self._aVecEMA=V3_ZERO; self._aWorst=ACCEL_FLOOR; self._kappaWorst=0.05
	self._dtEMA=1/60; self._dirStride=1; self._timeStride=1; self._dirPhase=0; self._basisCount=0

	-- ping provider
	self._pingMode   = string.upper(options.pingMode or "AUTO") -- AUTO | STATS | FIXED
	self._fixedPingS = math.max(0,(options.fixedPingMs or 50)/1000)
	self._pingEMA = self._fixedPingS
	self._lastPingSampleAt=0
	self._statsDataPingItem=nil

	-- UI
	self._autoUI = (options.autoUI ~= false)
	self._toggleKey = options.toggleKey or DEFAULT_TOGGLE_KEY
	self._showStats = options.showStats == true
	self._uiEnsureConn=nil
	self._ui=nil :: ScreenGui?; self._uiPanel=nil :: Frame?
	self._uiButton=nil :: TextButton?; self._uiTrace=nil :: TextButton?; self._uiPing=nil :: TextButton?; self._uiLamp=nil :: Frame?
	self._uiLabel=nil :: TextLabel?; self._onlineToast=nil :: TextLabel?

	-- highlight
	self._highlight=nil :: Highlight?; self._highlightTarget=nil

	-- character hooks
	self._autoHookCharacter = (options.autoHookCharacter ~= false)
	self._charConn=nil; self._diedConn=nil

	-- overlap params
	local op=OverlapParams.new(); op.FilterType=Enum.RaycastFilterType.Exclude; op.MaxParts=MAX_OCCUPANCY_PARTS
	self._overlapParams=op; self:_refreshOverlapFilters()

	-- tracing
	self._traceLevel = options.traceLevel and math.clamp(options.traceLevel,0,3) or 3
	self._logSeq=0; self._frameSeq=0; self._dedupSet={}

	-- ball folder hooks
	self._ballConnAdded=nil; self._ballConnRemoved=nil; self:_hookBallsFolder(self._ballsFolder)

	-- UI / input
	if self._autoUI and RunService:IsClient() then
		self:_ensureUIEventually()
		self:_bindToggleAction()
	elseif not RunService:IsClient() then
		warn("[IMMORTAL] You called Immortal.new() from the server. UI will not appear. Use a LocalScript in StarterPlayerScripts.")
	end

	if self._autoHookCharacter and self._player then self:_hookCharacter(self._player) end

	self:_log(1,"init","constructed | pingMode=%s fixed=%.0fms", self._pingMode, self._fixedPingS*1000)
	return self
end

-- ======
-- Trace
-- ======
function Immortal:_log(level:number, tag:string, fmt:string, ...:any)
	if level > (self._traceLevel or 0) then return end
	self._logSeq+=1
	local msg = select("#",...)>0 and string.format(fmt,...) or fmt
	local key = tag.."|"..msg
	if self._dedupSet[key] then return end
	self._dedupSet[key]=true
	print(string.format("[IMMORTAL][%06d][%s] %s", self._logSeq, tag, msg))
end
function Immortal:_traceFrameStart() self._frameSeq+=1; self._dedupSet={}; self:_log(3,"frame","begin #%d", self._frameSeq) end
function Immortal:_traceFrameEnd() self:_log(3,"frame","end   #%d", self._frameSeq) end

-- ============
-- UI helpers
-- ============
local function mkCorner(p:Instance,r:number) local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r); c.Parent=p end

function Immortal:_bindToggleAction()
	ContextActionService:UnbindAction(UI_ACTION_NAME)
	ContextActionService:BindAction(UI_ACTION_NAME,function(_,state,_)
		if state~=Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
		if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
		self:_log(1,"input","G toggle pressed"); self:setEnabled(not self._enabled); return Enum.ContextActionResult.Sink
	end,false,self._toggleKey)
	self:_log(2,"ui","hotkey bound to %s", tostring(self._toggleKey))
end

function Immortal:_waitForPlayerGui(timeout:number?): PlayerGui?
	if not RunService:IsClient() then return nil end
	local player = self._player or Players.LocalPlayer
	if not player then return nil end
	local pg = player:FindFirstChildOfClass("PlayerGui")
	if pg then return pg end
	timeout = timeout or 10
	local start = os.clock()
	repeat
		pg = player:FindFirstChildOfClass("PlayerGui")
		if pg then return pg end
		task.wait(0.05)
	until (os.clock()-start) > timeout
	return nil
end

-- public helper if you want to embed UI under your own ScreenGui
function Immortal:mountUI(parent: Instance)
	if not parent then return end
	self:_createUI(parent)
end

function Immortal:_createUI(parent: Instance)
	if self._ui then self._ui:Destroy(); self._ui=nil end

	local gui=Instance.new("ScreenGui")
	gui.Name=UI_NAME; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=true; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.DisplayOrder=1000
	gui.Parent=parent

	local panel=Instance.new("Frame")
	panel.Name="Panel"; panel.Size=UDim2.new(0,360,0,76); panel.AnchorPoint=Vector2.new(1,1); panel.Position=UDim2.new(1,-12,1,-12)
	panel.BackgroundColor3=Color3.fromRGB(18,18,18); panel.BackgroundTransparency=0.2; panel.BorderSizePixel=0; panel.Parent=gui
	mkCorner(panel,12)
	local stroke=Instance.new("UIStroke"); stroke.Thickness=1; stroke.Transparency=0.3; stroke.Color=Color3.fromRGB(60,60,60); stroke.Parent=panel

	local lamp=Instance.new("Frame")
	lamp.Name="Lamp"; lamp.Size=UDim2.new(0,10,0,10); lamp.Position=UDim2.new(0,10,0,10); lamp.BackgroundColor3=Color3.fromRGB(90,90,90)
	lamp.BorderSizePixel=0; lamp.Parent=panel; mkCorner(lamp,5)

	local btn=Instance.new("TextButton")
	btn.Name="Toggle"; btn.Size=UDim2.new(0,120,0,40); btn.Position=UDim2.new(0,26,0,18)
	btn.BackgroundColor3=Color3.fromRGB(32,32,32); btn.Text="AutoParry: OFF"; btn.Font=Enum.Font.GothamBold; btn.TextSize=16
	btn.TextColor3=Color3.fromRGB(220,220,220); btn.Parent=panel; mkCorner(btn,10)

	local traceBtn=Instance.new("TextButton")
	traceBtn.Name="Trace"; traceBtn.Size=UDim2.new(0,80,0,40); traceBtn.Position=UDim2.new(0,156,0,18)
	traceBtn.BackgroundColor3=Color3.fromRGB(36,36,60); traceBtn.Text=("TRACE %d"):format(self._traceLevel); traceBtn.Font=Enum.Font.GothamBold
	traceBtn.TextSize=14; traceBtn.TextColor3=Color3.fromRGB(220,220,255); traceBtn.Parent=panel; mkCorner(traceBtn,10)

	local pingBtn=Instance.new("TextButton")
	pingBtn.Name="Ping"; pingBtn.Size=UDim2.new(0,80,0,40); pingBtn.Position=UDim2.new(0,246,0,18)
	pingBtn.BackgroundColor3=Color3.fromRGB(36,60,36); pingBtn.Text="PING "..(self._pingMode or "AUTO"); pingBtn.Font=Enum.Font.GothamBold
	pingBtn.TextSize=14; pingBtn.TextColor3=Color3.fromRGB(200,255,200); pingBtn.Parent=panel; mkCorner(pingBtn,10)

	local info=Instance.new("TextLabel")
	info.Name="Info"; info.Size=UDim2.new(0,160,0,40); info.Position=UDim2.new(1,-170,0,18); info.BackgroundTransparency=1
	info.Text="—"; info.Font=Enum.Font.Gotham; info.TextSize=14; info.TextColor3=Color3.fromRGB(170,170,170); info.TextXAlignment=Enum.TextXAlignment.Right
	info.Parent=panel

	-- online toast
	local toast=Instance.new("TextLabel")
	toast.Name="OnlineBanner"; toast.AnchorPoint=Vector2.new(0.5,0); toast.Position=UDim2.new(0.5,0,0,12)
	toast.Size=UDim2.new(0,240,0,26); toast.BackgroundColor3=Color3.fromRGB(30,110,30); toast.BorderSizePixel=0
	toast.Text="IMMORTAL UI ONLINE"; toast.TextColor3=Color3.fromRGB(240,255,240); toast.Font=Enum.Font.GothamBold; toast.TextSize=14; toast.Parent=gui
	mkCorner(toast,8); toast.Visible=true; task.delay(2,function() if toast and toast.Parent then toast.Visible=false end end)

	-- events
	btn.MouseButton1Click:Connect(function() self:setEnabled(not self._enabled) end)
	traceBtn.MouseButton1Click:Connect(function() self._traceLevel=(self._traceLevel+1)%4; traceBtn.Text=("TRACE %d"):format(self._traceLevel) end)
	pingBtn.MouseButton1Click:Connect(function()
		local nextMode = (self._pingMode=="AUTO") and "STATS" or (self._pingMode=="STATS" and "FIXED" or "AUTO")
		self:setPingMode(nextMode)
	end)

	self._ui=gui; self._uiPanel=panel; self._uiButton=btn; self._uiTrace=traceBtn; self._uiPing=pingBtn; self._uiLabel=info; self._uiLamp=lamp; self._onlineToast=toast
	self:_refreshUI(true)
	self:_log(1,"ui","mounted under %s", parent:GetFullName())
end

function Immortal:_refreshUI(first:boolean?)
	if not self._ui then return end
	if self._uiButton then
		if self._enabled then self._uiButton.Text="AutoParry: ON"; self._uiButton.BackgroundColor3=Color3.fromRGB(25,110,25)
		else self._uiButton.Text="AutoParry: OFF"; self._uiButton.BackgroundColor3=Color3.fromRGB(32,32,32) end
	end
	if self._uiTrace then self._uiTrace.Text=("TRACE %d"):format(self._traceLevel or 0) end
	if self._uiPing  then self._uiPing.Text="PING "..(self._pingMode or "AUTO") end
	if self._uiLamp  then self._uiLamp.BackgroundColor3 = self._enabled and Color3.fromRGB(30,200,60) or Color3.fromRGB(90,90,90) end
	if first then
		self:_log(2,"ui","visible=true at bottom-right; look for green ONLINE banner")
	end
end

function Immortal:_updateUILabel(fps:number,ping:number,margin2:number)
	if not (self._uiLabel and self._showStats) then return end
	self._uiLabel.Text=string.format("FPS:%d  P:%.0fms  M:%.0f", math.floor(fps+0.5), ping*1000, margin2)
end

function Immortal:_ensureUIEventually()
	if not RunService:IsClient() then return end
	local parent = self:_waitForPlayerGui(10)
	if not parent then
		-- as a last resort, try StarterGui (will show after respawn/new players)
		self:_log(1,"ui","PlayerGui not found within timeout; mounting in StarterGui (visible on next spawn)")
		self:_createUI(StarterGui)
	else
		self:_createUI(parent)
	end

	if self._uiEnsureConn then self._uiEnsureConn:Disconnect() self._uiEnsureConn=nil end
	self._uiEnsureConn=RunService.Heartbeat:Connect(function()
		if not self._ui then return end
		local pg = self:_waitForPlayerGui(0)
		if pg and self._ui.Parent ~= pg then
			self._ui.Parent = pg
			self:_log(1,"ui","reparented to PlayerGui (hot)")
		end
	end)
end

-- =========
-- Highlight
-- =========
function Immortal:_ensureHighlightParent()
	local hl=self._highlight; if not hl then return end
	local pg = self:_waitForPlayerGui(0)
	if pg and hl.Parent ~= pg then hl.Parent=pg end
end
function Immortal:_ensureHighlight(): Highlight?
	local hl=self._highlight
	if hl and not isInstanceDestroyed(hl) then self:_ensureHighlightParent(); return hl end
	local pg = self:_waitForPlayerGui(0); if not pg then return nil end
	hl=Instance.new("Highlight"); hl.Name="ImmortalHighlight"; hl.FillColor=Color3.fromRGB(0,255,0); hl.OutlineColor=Color3.fromRGB(0,255,0)
	hl.FillTransparency=0.3; hl.OutlineTransparency=0; hl.Enabled=false; hl.Parent=pg
	self._highlight=hl; self._highlightTarget=nil; return hl
end
function Immortal:_setHighlightTarget(ball:BasePart?)
	local hl=self:_ensureHighlight(); if not hl then return end
	if ball~=self._highlightTarget then
		self._highlightTarget=ball
		if ball and isBallValid(ball) then hl.Adornee=ball; hl.Enabled=true else hl.Adornee=nil; hl.Enabled=false end
	end
end
function Immortal:_clearHighlight() local hl=self._highlight if hl then hl.Enabled=false; hl.Adornee=nil end self._highlightTarget=nil end

-- ============
-- Balls cache
-- ============
function Immortal:_pickBallFromFolder(folder:Instance?): BasePart?
	if not folder then return nil end
	local best:BasePart?=nil
	for _,c in ipairs(folder:GetChildren()) do
		if c:IsA("BasePart") then
			if c:GetAttribute("realBall") then return c end
			if not best and c.Name=="Ball" then best=c end
		end
	end
	return best
end
function Immortal:_scanForBall(): BasePart? local b=self:_pickBallFromFolder(self._ballsFolder); self:_log(2,"ball","scan=%s", tostring(b)); return b end
function Immortal:_onBallChildAdded(c:Instance) if c:IsA("BasePart") then if c:GetAttribute("realBall") or not self._cachedBall then self._cachedBall=c; self:_log(1,"ball","add->cache %s", tostring(c)) end end end
function Immortal:_onBallChildRemoved(c:Instance) if c==self._cachedBall then self._cachedBall=nil; self._nextBallScanAt=0; self:_log(1,"ball","remove->clear cache") end end
function Immortal:_hookBallsFolder(folder:Instance?) if self._ballConnAdded then self._ballConnAdded:Disconnect() self._ballConnAdded=nil end; if self._ballConnRemoved then self._ballConnRemoved:Disconnect() self._ballConnRemoved=nil end; self._ballsFolder=folder; self._cachedBall=nil; self._nextBallScanAt=0; self:_refreshOverlapFilters(); if folder then self._cachedBall=self:_pickBallFromFolder(folder); self._ballConnAdded=folder.ChildAdded:Connect(function(c) self:_onBallChildAdded(c) end); self._ballConnRemoved=folder.ChildRemoved:Connect(function(c) self:_onBallChildRemoved(c) end) end; self:_log(1,"ball","folder=%s init=%s", tostring(folder), tostring(self._cachedBall)) end
function Immortal:_chooseBall(now:number): BasePart? local b=self._cachedBall; if isBallValid(b) then return b end; if now<(self._nextBallScanAt or 0) then return b end; b=self:_scanForBall(); self._cachedBall=b; self._nextBallScanAt=now+BALL_SCAN_PERIOD; return b end

-- =========================
-- Dynamics & safe ping
-- =========================
function Immortal:_updateBounds(vNow:Vector3,dt:number)
	local vPrev=self._lastBallVel
	if vPrev and dt>1e-6 then
		local aVec=(vNow-vPrev)/dt
		local aMag=aVec.Magnitude
		local speed=max(vNow.Magnitude,1e-6)
		local kappaInst=(vNow:Cross(aVec)).Magnitude/(speed*speed*speed)
		self._aWorst=min(ACCEL_CAP, max(ACCEL_FLOOR, ACCEL_DECAY*self._aWorst + (1-ACCEL_DECAY)*aMag))
		self._kappaWorst=min(CURV_CAP, max(0, CURV_DECAY*self._kappaWorst + (1-CURV_DECAY)*kappaInst))
		local w=A_EMA; local aEMA=self._aVecEMA*(1-w)+aVec*w; local am=aEMA.Magnitude; if am>A_VEC_CAP then aEMA=aEMA*(A_VEC_CAP/am) end; self._aVecEMA=aEMA
	end
	self._lastBallVel=vNow
end

function Immortal:setPingMode(mode:string)
	self._pingMode=string.upper(mode); self._statsDataPingItem=nil; if self._uiPing then self._uiPing.Text="PING "..self._pingMode end
	self:_log(1,"net","provider=%s%s", self._pingMode, self._pingMode=="FIXED" and (" value="..tostring(self._fixedPingS*1000).."ms") or "")
end

local function tryDataPingItem(): any?
	if not Stats then return nil end
	local ok1,network=pcall(function() return Stats.Network end); if not ok1 or not network then return nil end
	local ok2,serv=pcall(function() return network.ServerStatsItem end); if not ok2 or not serv then return nil end
	local ok3,item=pcall(function() return serv["Data Ping"] end); if ok3 and item then return item end
	return nil
end

function Immortal:_getPingSeconds(now:number):number
	if (now-(self._lastPingSampleAt or 0))<PING_SAMPLE_PERIOD then return self._pingEMA end
	self._lastPingSampleAt=now
	if self._pingMode=="FIXED" then self._pingEMA=self._fixedPingS; return self._pingEMA end
	if not self._statsDataPingItem then
		self._statsDataPingItem=tryDataPingItem()
		if not self._statsDataPingItem then
			if self._pingMode=="STATS" then self:_log(1,"net","STATS unavailable -> FIXED %.0fms", self._fixedPingS*1000) end
			self._pingMode=(self._pingMode=="STATS") and "FIXED" or self._pingMode
			self._pingEMA=self._fixedPingS
			return self._pingEMA
		end
	end
	local okVal,v=pcall(function() return self._statsDataPingItem:GetValue() end)
	if okVal and type(v)=="number" and v>=0 then
		local sample=v/1000; local a=0.25; self._pingEMA=(1-a)*self._pingEMA + a*sample; return self._pingEMA
	end
	self._pingEMA=self._fixedPingS; return self._pingEMA
end

-- ===================
-- Adaptive budgeting
-- ===================
function Immortal:_updateBudget(dt:number, ballSpeed:number): number
	self._dtEMA=(1-FPS_EMA_ALPHA)*self._dtEMA + FPS_EMA_ALPHA*dt
	local fps=(self._dtEMA>1e-6) and (1/self._dtEMA) or 60
	local dirStride, tStride = 1,1
	if ballSpeed<SPEED_NO_DOWNSHIFT then
		if fps<35 then dirStride=DIR_STRIDE_AT_35FPS; tStride=TIME_STRIDE_AT_35FPS
		elseif fps<55 then dirStride=DIR_STRIDE_AT_55FPS end
	end
	self._dirStride, self._timeStride = dirStride, tStride
	self._dirPhase=(self._dirPhase+1)%dirStride
	return fps
end

-- ===============
-- Horizon builder
-- ===============
function Immortal:_precomputeHorizon(bPos:Vector3,bVel:Vector3,aVec:Vector3,bSpeed:number,bRad:number,ping:number,H:number)
	local CT,R2,MPC=self._timeBuffer,self._radiusBuffer,self._mpcCenters
	local tStride=self._timeStride
	local latBase=bSpeed*ping*LATENCY_FACTOR*PING_MULT
	local count=0
	for i=1,#T_BASIS,tStride do
		local t=H*T_BASIS[i]; count+=1
		local c=futureBallPos2(bPos,bVel,aVec,t,ping); CT[count]=c
		local curv=CURV_SCALE*(bSpeed*bSpeed)*self._kappaWorst*t*t
		local R=bRad + (bSpeed*t) + 0.5*self._aWorst*t*t + latBase + HUMANOID_RADIUS + SAFE_MARGIN + curv
		R2[count]=R*R
	end
	for j=count+1,#CT do CT[j]=nil end; for j=count+1,#R2 do R2[j]=nil end
	self._basisCount=count
	for j=1,#CENTER_FRACTIONS do local f=CENTER_FRACTIONS[j]; MPC[j]=futureBallPos2(bPos,bVel,aVec,H*f,ping) end
end

-- =================
-- Margin / scoring
-- =================
function Immortal:_minMargin2(target:Vector3):number
	local CT,R2,n=self._timeBuffer,self._radiusBuffer,self._basisCount
	local tx,ty,tz=target.X,target.Y,target.Z; local minM2=HUGE
	for i=1,n do local c=CT[i]; local dx,dy,dz=tx-c.X,ty-c.Y,tz-c.Z; local m2=(dx*dx+dy*dy+dz*dz)-R2[i]; if m2<minM2 then minM2=m2; if minM2<=0 then return minM2 end end end
	return minM2
end
function Immortal:_clearNow2(target:Vector3):number local c0=self._timeBuffer[1]; if not c0 then return HUGE end; local dx,dy,dz=target.X-c0.X,target.Y-c0.Y,target.Z-c0.Z; return (dx*dx+dy*dy+dz*dz)-self._radiusBuffer[1] end
function Immortal:_inForbiddenCone(ballPos:Vector3,target:Vector3,vBall:Vector3,bSpeed:number):boolean
	if bSpeed<1e-3 then return false end
	local bt=Vector3.new(target.X-ballPos.X,0,target.Z-ballPos.Z); local btMag=bt.Magnitude; if btMag<1e-3 then return true end
	local btU=bt/btMag; local vXZ=Vector3.new(vBall.X,0,vBall.Z); local vm=vXZ.Magnitude; if vm<1e-3 then return false end
	local vU=vXZ/vm; local coneDeg=math.clamp(CONE_BASE_DEG + CONE_SPEED_GAIN*(bSpeed/10.0),0,CONE_DEG_MAX); local cosTh=math.cos(math.rad(coneDeg))
	local dot=btU:Dot(vU); local radiusFrac=btMag/MAX_RANGE_FROM_BALL; local bias=0.05*(1-radiusFrac)
	return dot>(cosTh-bias)
end
function Immortal:_scoreCandidate(p:Vector3,currentBallPos:Vector3):number
	if self:_clearNow2(p)<=0 then return -HUGE end
	local robustM2=self:_minMargin2(p)
	if robustM2<128.0 then local d=currentBallPos-p; local dm=d.Magnitude; if dm>1e-6 then local drift=d*(DRIFT_GUARD/dm); local m2=self:_minMargin2(p+drift); if m2<robustM2 then robustM2=m2 end end end
	local last=self._lastMoveDir; local hrp=self._rootPart
	if last and hrp then local step=Vector3.new(p.X-hrp.Position.X,0,p.Z-hrp.Position.Z); local sm=step.Magnitude; if sm>1e-6 then local dir=step/sm; robustM2 -= (1-math.max(dir:Dot(last),-1))*HYSTERESIS_WEIGHT2 end end
	return robustM2
end

-- ================
-- Obstacle checks
-- ================
function Immortal:_refreshOverlapFilters()
	local list={} if self._character then list[#list+1]=self._character end; if self._ballsFolder then list[#list+1]=self._ballsFolder end
	self._overlapParams.FilterDescendantsInstances=list
end
function Immortal:_isSpotClear(target:Vector3):boolean local parts=Workspace:GetPartBoundsInBox(CF_NEW(target),COLLISION_BOX,self._overlapParams); return #parts==0 end
function Immortal:_findNearestClearAround(target:Vector3, ball:Vector3):Vector3?
	if self:_isSpotClear(target) then return target end
	for _,R in ipairs(OBSTACLE_FAN_RADIUS) do
		if R>0 then
			local base=self._rng:NextNumber(0,TAU)
			for k=1,OBSTACLE_FAN_DIRS do
				local ang=base+TAU*(k-1)/OBSTACLE_FAN_DIRS
				local cand=clampToRange(ball, target+Vector3.new(cos(ang)*R,0,sin(ang)*R)); cand=Vector3.new(cand.X,target.Y,cand.Z)
				if self:_isSpotClear(cand) then return cand end
			end
		end
	end
	return nil
end

-- ====================
-- Candidate generation
-- ====================
function Immortal:_tryAtRadius(center:Vector3,radius:number,currentBallPos:Vector3,baseUp:number,vBall:Vector3,bSpeed:number)
	local bestTarget:Vector3?, bestScore=-HUGE
	local nCT=self._basisCount; local vdir=(nCT>=2) and safeUnit(self._timeBuffer[2]-self._timeBuffer[1]) or safeUnit(vBall)
	local hrp=self._rootPart; local away=safeUnit(hrp and (hrp.Position-center) or Vector3.new(1,0,0))
	local tleft=Vector3.new(-vdir.Z,0,vdir.X); local tright=Vector3.new(vdir.Z,0,-vdir.X)
	local prim={away,tleft,tright}; local yBase=Vector3.new(0,baseUp,0)
	for _,dir in ipairs(prim) do
		if dir.Magnitude>0.1 then
			for _,yoff in ipairs(EXTRA_LAYERS_Y) do
				local p=clampToRange(currentBallPos, center + dir*radius + yBase + Vector3.new(0,yoff,0))
				if not self:_inForbiddenCone(currentBallPos,p,vBall,bSpeed) then local sc=self:_scoreCandidate(p,currentBallPos); if sc>bestScore then bestScore,bestTarget=sc,p; if sc>=SAFE_MARGIN2_STRONG then return bestTarget,bestScore,true end end end
			end
		end
	end
	local dirs,stride,phase=self._dirs,self._dirStride,self._dirPhase
	for i=1+phase,#dirs,stride do
		local dir=dirs[i]
		for _,yoff in ipairs(EXTRA_LAYERS_Y) do
			local p=clampToRange(currentBallPos, center + dir*radius + yBase + Vector3.new(0,yoff,0))
			if not self:_inForbiddenCone(currentBallPos,p,vBall,bSpeed) then local sc=self:_scoreCandidate(p,currentBallPos); if sc>bestScore then bestScore,bestTarget=sc,p; if sc>=SAFE_MARGIN2_STRONG then return bestTarget,bestScore,true end end end
		end
	end
	return bestTarget,bestScore,false
end

function Immortal:_planTargets(currentBallPos:Vector3, vBall:Vector3, bSpeed:number): (Vector3, Vector3?)
	local bestTarget:Vector3?, bestScore=-HUGE
	local backup:Vector3?, backupScore=-HUGE
	if self._lastGoodTarget then
		local tgt=clampToRange(currentBallPos,self._lastGoodTarget)
		if not self:_inForbiddenCone(currentBallPos,tgt,vBall,bSpeed) then local sc=self:_scoreCandidate(tgt,currentBallPos); if sc>=SAFE_MARGIN2_MIN then bestTarget,bestScore=tgt,sc; backup,backupScore=tgt,sc end end
	end
	local MPC=self._mpcCenters
	for ci=1,#MPC do
		local c=MPC[ci]; local up=Y_HOVER + min(6.0,(bSpeed/30.0)*2.0)
		for _,rad0 in ipairs(RADII_PRIMARY) do
			local rad=min(rad0,MAX_RANGE_FROM_BALL)
			local t,sc,ok=self:_tryAtRadius(c,rad,currentBallPos,up,vBall,bSpeed)
			if sc>bestScore then bestTarget,bestScore=t,sc end
			if ok or bestScore>=SAFE_MARGIN2_MIN then
				local cj=min(#MPC,ci+2); local c2=MPC[cj]
				for _,r2 in ipairs(RADII_BACKUP) do local rad2=min(r2,MAX_RANGE_FROM_BALL); local tb,sb=self:_tryAtRadius(c2,rad2,currentBallPos,up,vBall,bSpeed); if sb>backupScore then backup,backupScore=tb,sb end end
				return bestTarget or backup, backup
			end
		end
	end
	if not backup then local hrp=self._rootPart; local away=safeUnit(hrp and (hrp.Position-currentBallPos) or Vector3.new(1,0,0)); if away.Magnitude<1e-6 then away=Vector3.new(1,0,0) end; backup=clampToRange(currentBallPos,currentBallPos + away*MAX_RANGE_FROM_BALL)+Vector3.new(0,Y_HOVER,0) end
	return bestTarget or backup, backup
end

-- ==========
-- Teleport
-- ==========
function Immortal:_doTeleport(target:Vector3?, danger:boolean)
	local hrp=self._rootPart; if not hrp or not target then return end
	local now=time(); local cd=danger and TP_CD_DANGER or TP_CD_SAFE; if (now-self._lastTeleport)<cd then return end
	local ball=self._cachedBall; local ballPos=(ball and (ball :: BasePart).Position) or hrp.Position
	local safe=self:_findNearestClearAround(target,ballPos) or target
	self._lastTeleport=now
	local from=hrp.Position; hrp.CFrame=CF_NEW(safe); hrp.AssemblyLinearVelocity=V3_ZERO; hrp.AssemblyAngularVelocity=V3_ZERO
	self._lastGoodTarget=safe
	local d=Vector3.new(safe.X-from.X,0,safe.Z-from.Z); local dm=d.Magnitude; if dm>1e-6 then self._lastMoveDir=d/dm end
	self:_log(1,"tp","%s -> %s (danger=%s, d=%.1f)", fv3(from), fv3(safe), tostring(danger), dm)
end

-- =========
-- Heartbeat
-- =========
function Immortal:_resetPlanner() self._nextBackupTarget=nil; self._lastGoodTarget=nil; self._lastMoveDir=nil end

function Immortal:_heartbeatStep(dt:number)
	self:_traceFrameStart()
	if not self._enabled then self:_traceFrameEnd(); return end
	local hrp=self._rootPart
	if not hrp then self:_clearHighlight(); self:_resetPlanner(); self:_traceFrameEnd(); return end
	local human=self._humanoid; if human and human.Health<=0 then self:_clearHighlight(); self:_resetPlanner(); self:_traceFrameEnd(); return end

	local now=time()
	local ball=self:_chooseBall(now)
	if not isBallValid(ball) then self:_setHighlightTarget(nil); self:_resetPlanner(); self:_traceFrameEnd(); return end
	local bPart=ball :: BasePart; self:_setHighlightTarget(bPart)

	local bPos=bPart.Position; local bVel=bPart.AssemblyLinearVelocity or bPart.Velocity; local bSpeed=bVel.Magnitude
	local ping=self:_getPingSeconds(now)
	local selfPos=hrp.Position; local bRad=ballRadiusOf(bPart)

	self:_updateBounds(bVel,dt)
	local fps=self:_updateBudget(dt,bSpeed)

	local H=math.clamp(H_BASE + H_SPEED_GAIN*math.min(bSpeed,140) + H_PING_GAIN*ping, H_MIN, H_MAX)

	if (selfPos-bPos).Magnitude > MAX_RANGE_FROM_BALL + 1.0 then
		local clamped=clampToRange(bPos,selfPos); self:_doTeleport(Vector3.new(clamped.X,Y_HOVER,clamped.Z), true); self:_updateUILabel(fps,ping,0); self:_traceFrameEnd(); return
	end

	self:_precomputeHorizon(bPos,bVel,self._aVecEMA,bSpeed,bRad,ping,H)

	do -- now collision
		local c0=self._timeBuffer[1]; if c0 then local dx,dy,dz=selfPos.X-c0.X,selfPos.Y-c0.Y,selfPos.Z-c0.Z; local d2=dx*dx+dy*dy+dz*dz; local rad2_now=math.max(self._radiusBuffer[1],IMMEDIATE_DANGER_RAD2); if d2<=rad2_now then local away=safeUnit(Vector3.new(dx,dy,dz)); local desired=bPos + away*MAX_RANGE_FROM_BALL; self:_doTeleport(Vector3.new(desired.X,Y_HOVER,desired.Z), true); self:_updateUILabel(fps,ping,-1); self:_traceFrameEnd(); return end end
	end

	do -- time to interaction
		local vSelf=hrp.AssemblyLinearVelocity or V3_ZERO; local r=bPos-selfPos; local vRel=bVel-vSelf; local v2=vRel:Dot(vRel)
		local eta,miss2
		if v2<1e-6 then eta=HUGE; miss2=r:Dot(r) else local tStar=-r:Dot(vRel)/v2; if tStar<0 then tStar=0 end; eta=tStar; local tVec=r+vRel*tStar; miss2=tVec:Dot(tVec) end
		local etaLook=math.min(eta + ping*PING_MULT, H); local touchR2=self._radiusBuffer[1] or IMMEDIATE_DANGER_RAD2
		if etaLook<=IMMEDIATE_DANGER_TTI or miss2<=touchR2 then local tgt,backup=self:_planTargets(bPos,bVel,bSpeed); self._nextBackupTarget=backup; self:_doTeleport(tgt,true); if self:_minMargin2(hrp.Position)<CHAIN_TRIGGER2 and backup then self:_doTeleport(backup,true) end; self:_updateUILabel(fps,ping,self:_minMargin2(hrp.Position)); self:_traceFrameEnd(); return end
	end

	local curM2=self:_minMargin2(selfPos)
	if curM2<=0.0 then local tgt,backup=self:_planTargets(bPos,bVel,bSpeed); self._nextBackupTarget=backup; self:_doTeleport(tgt,true); if self:_minMargin2(hrp.Position)<CHAIN_TRIGGER2 and backup then self:_doTeleport(backup,true) end; self:_updateUILabel(fps,ping,self:_minMargin2(hrp.Position)); self:_traceFrameEnd(); return end
	if self._nextBackupTarget and curM2<SAFE_MARGIN2_MIN then self:_doTeleport(self._nextBackupTarget,true); self._nextBackupTarget=nil; self:_updateUILabel(fps,ping,self:_minMargin2(hrp.Position)); self:_traceFrameEnd(); return end
	if curM2<SAFE_MARGIN2_STRONG and self._rng:NextNumber()<NUDGE_PROB then local tgt,backup=self:_planTargets(bPos,bVel,bSpeed); if tgt then local m2=self:_minMargin2(tgt); if m2>curM2+NUDGE_GAIN2 then self._nextBackupTarget=backup; self:_doTeleport(tgt,false); self:_updateUILabel(fps,ping,self:_minMargin2(hrp.Position)); self:_traceFrameEnd(); return end end end

	self:_updateUILabel(fps,ping,curM2)
	self:_traceFrameEnd()
end

-- ======================
-- Character / context
-- ======================
function Immortal:_hookCharacter(player:Player)
	if self._charConn then self._charConn:Disconnect() self._charConn=nil end
	self._charConn=player.CharacterAdded:Connect(function(ch)
		self._character=ch; self._humanoid=ch:FindFirstChildOfClass("Humanoid"); local rp=ch:FindFirstChild("HumanoidRootPart"); self._rootPart=(rp and rp:IsA("BasePart")) and rp or nil
		if self._humanoid then if self._diedConn then self._diedConn:Disconnect() self._diedConn=nil end; self._diedConn=self._humanoid.Died:Connect(function() self:handleHumanoidDied() end) end
		self:_refreshOverlapFilters()
		if self._autoUI and RunService:IsClient() then self:_ensureUIEventually() end
	end)
	if player.Character then
		self._character=player.Character; self._humanoid=self._character:FindFirstChildOfClass("Humanoid"); local rp=self._character:FindFirstChild("HumanoidRootPart"); self._rootPart=(rp and rp:IsA("BasePart")) and rp or nil
		if self._humanoid then if self._diedConn then self._diedConn:Disconnect() self._diedConn=nil end; self._diedConn=self._humanoid.Died:Connect(function() self:handleHumanoidDied() end) end
		self:_refreshOverlapFilters()
	end
end

-- =====
-- API
-- =====
function Immortal:setContext(ctx: Options)
	ctx=ctx or {}
	if ctx.player    ~= nil then self._player=ctx.player end
	if ctx.character ~= nil then self._character=ctx.character end
	if ctx.humanoid  ~= nil then self._humanoid=ctx.humanoid end
	if ctx.rootPart  ~= nil then self._rootPart=ctx.rootPart end
	if ctx.ballsFolder ~= nil then self:_hookBallsFolder(ctx.ballsFolder) end
	if ctx.toggleKey ~= nil then self._toggleKey = ctx.toggleKey; if self._autoUI and RunService:IsClient() then self:_bindToggleAction() end end
	if ctx.traceLevel ~= nil then self._traceLevel=math.clamp(ctx.traceLevel,0,3) end
	if ctx.pingMode   ~= nil then self:setPingMode(ctx.pingMode) end
	if ctx.fixedPingMs~= nil then self._fixedPingS=math.max(0,ctx.fixedPingMs/1000) end
	if self._autoUI and RunService:IsClient() then self:_ensureUIEventually() end
end

function Immortal:setBallsFolder(folder:Instance?) if self._ballsFolder ~= folder then self:_hookBallsFolder(folder) end end

function Immortal:_start()
	if self._heartbeat then return end
	self:_ensureHighlight()
	self:_resetPlanner()
	self._heartbeat=RunService.Heartbeat:Connect(function(dt) if dt>0.25 then dt=0.25 end self:_heartbeatStep(dt) end)
	self:_refreshUI()
	self:_log(1,"life","started")
end

function Immortal:_stop()
	if self._heartbeat then self._heartbeat:Disconnect(); self._heartbeat=nil end
	self:_clearHighlight()
	self:_resetPlanner()
	self:_refreshUI()
	self:_log(1,"life","stopped")
end

function Immortal:setEnabled(enabled:boolean)
	enabled=not not enabled
	if self._enabled==enabled then return end
	self._enabled=enabled
	if self._autoUI and RunService:IsClient() then self:_ensureUIEventually(); self:_refreshUI() end
	if enabled then self:_start() else self:_stop() end
end

function Immortal:isEnabled():boolean return self._enabled end

function Immortal:handleHumanoidDied() self:_clearHighlight(); self:_resetPlanner() end

function Immortal:destroy()
	self:setEnabled(false)
	if self._uiEnsureConn then self._uiEnsureConn:Disconnect() self._uiEnsureConn=nil end
	if self._ui then self._ui:Destroy(); self._ui=nil; self._uiPanel=nil; self._uiButton=nil; self._uiTrace=nil; self._uiPing=nil; self._uiLamp=nil; self._uiLabel=nil; self._onlineToast=nil end
	ContextActionService:UnbindAction(UI_ACTION_NAME)
	if self._highlight then self._highlight:Destroy(); self._highlight=nil; self._highlightTarget=nil end
	if self._ballConnAdded then self._ballConnAdded:Disconnect() self._ballConnAdded=nil end
	if self._ballConnRemoved then self._ballConnRemoved:Disconnect() self._ballConnRemoved=nil end
	if self._charConn then self._charConn:Disconnect() self._charConn=nil end
	if self._diedConn then self._diedConn:Disconnect() self._diedConn=nil end
end

-- ========
-- Bootstrap
-- ========
function Immortal.bootstrap(opts:Options?): any
	if not RunService:IsClient() then
		warn("[IMMORTAL] bootstrap() called from the server. Move this to a LocalScript (StarterPlayerScripts) for UI to show.")
	end
	local self=Immortal.new(opts or {autoUI=true, showStats=true, traceLevel=3, pingMode="AUTO", fixedPingMs=50})
	if self._autoUI and RunService:IsClient() then self:_ensureUIEventually() end
	self:setEnabled(true) -- start ON so you see the ONLINE banner + logs
	return self
end

return Immortal
