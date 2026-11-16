--[[
    Blade Ball -- executor suite
    Loader: any Lua executor (Wave, Solara, Delta, Synapse-class).
    UI: same sharp-cornered tabbed rectangle window as the old suite.
    Auto Parry: finds the live ball, predicts impact from its velocity, and
                fires a parry through a discovered remote, the parry key, or
                a click. Method is selectable; every parry is logged.
    Syntax-checked against luac 5.4 and driven against a Roblox API stub with
    a synthetic incoming ball. Not run against the live game.
]]

if not game:IsLoaded() then game.Loaded:Wait() end

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInput         = game:GetService("UserInputService")
local VirtualUser       = game:GetService("VirtualUser")
local TweenService      = game:GetService("TweenService")
local HttpService       = game:GetService("HttpService")
local Stats             = game:GetService("Stats")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LP = Players.LocalPlayer

-- ============================== CONFIG BLOCK ==============================
local Config = {
    -- window
    Keybind        = Enum.KeyCode.RightShift,
    Accent         = Color3.fromRGB(0, 255, 130),
    Bg             = Color3.fromRGB(12, 12, 15),
    Panel          = Color3.fromRGB(21, 21, 26),
    PanelAlt       = Color3.fromRGB(32, 32, 39),
    Text           = Color3.fromRGB(236, 236, 241),
    Dim            = Color3.fromRGB(138, 138, 148),
    ThemeName      = "Ollie",
    UiScale        = 1,
    UiTransparency = 0,
    Tab            = 1,

    -- parry
    AutoParry      = true,
    ParryMethod    = "AUTO",     -- AUTO / REMOTE / KEY / CLICK
    ParryKey       = "Q",
    ParryLead      = 120,        -- ms before predicted impact
    ParryRange     = 30,         -- studs
    ParryCooldown  = 180,        -- ms
    ParryPrediction = true,      -- release on ETA instead of pure distance
    IncomingOnly   = true,       -- require the ball to be closing in
    SpamParry      = false,
    Verbose        = false,

    -- combat
    AutoAim        = false,
    AimStrength    = 0.5,
    AutoCurve      = false,
    CurveStrength  = 0.6,
    AutoDodge      = false,
    DodgeRange     = 18,
    AutoAbility    = false,
    AbilityKey     = "E",
    AbilityCooldown = 800,
    AutoClash      = false,
    ClashRange     = 8,
    AutoReturn     = false,
    ReturnMs       = 220,

    -- movement
    SpeedToggle    = false,
    WalkSpeed      = 24,
    JumpPower      = 50,
    InfiniteJump   = false,

    -- visual
    Watermark      = true,
    BallESP        = true,
    ParryFlash     = true,
    FpsCounter     = true,
    Capture        = false,

    Schema         = 1,
}
-- ======================== END CONFIG BLOCK (edit here) ====================

local THEMES = {
    { Name = "Ollie",  Color = Color3.fromRGB(0, 255, 130) },
    { Name = "Ember",  Color = Color3.fromRGB(255, 82, 60) },
    { Name = "Ice",    Color = Color3.fromRGB(92, 190, 255) },
    { Name = "Gold",   Color = Color3.fromRGB(255, 200, 60) },
    { Name = "Violet", Color = Color3.fromRGB(172, 112, 255) },
    { Name = "Mono",   Color = Color3.fromRGB(235, 235, 240) },
}

local DEFAULTS = {}
for k, v in pairs(Config) do DEFAULTS[k] = v end

-- ============================== UTIL =====================================
local function rgb(c) return c.R, c.G, c.B end

local function make(class, props, parent)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then inst[k] = v end
    end
    inst.Parent = parent
    return inst
end

local function cornerless(inst)
    local c = inst:FindFirstChildOfClass("UICorner")
    if c then c:Destroy() end
    return inst
end

local function stroke(inst, color, thickness)
    cornerless(inst)
    local s = Instance.new("UIStroke")
    s.Color = color or Config.PanelAlt
    s.Thickness = thickness or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = inst
    return s
end

local function tween(inst, props, time)
    local t = TweenService:Create(inst, TweenInfo.new(time or 0.12), props)
    t:Play()
    return t
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function isOwnGui(inst)
    local pg = LP:FindFirstChild("PlayerGui")
    local p = inst
    while p and p ~= pg do
        if string.sub(p.Name, 1, 3) == "PB_" then return true end
        p = p.Parent
    end
    return false
end

local function normalizedScale()
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
    local fit = clamp(math.min(vp.X * 0.94 / 470, vp.Y * 0.92 / 560), 0.55, 1)
    return fit * Config.UiScale, fit
end

local function vdot(a, b)
    return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end

local function vunit(v)
    local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
    if m < 0.0001 then return Vector3.new(0, 0, 0) end
    return Vector3.new(v.X / m, v.Y / m, v.Z / m)
end

local function vlen(v)
    return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
end

-- ============================== RUNTIME STATE ============================
local State = {
    alive = true,
    uiOpen = true,
    minimized = false,
    capturing = false,
    dragSlider = nil,
    gen = 0,
    pos = UDim2.new(0, 40, 0.5, -280),
    scale = nil,
    fit = 1,
    toggleGui = nil,

    lastParry = 0,
    lastAbility = 0,
    lastJump = 0,
    lastDodge = 0,
    lastReturn = 0,
    returnAt = nil,
    parries = 0,
    lastAction = "-",
    lastReason = "-",
    target = nil,
    dodgeDir = 1,

    signalLabel = nil,
    ballLabel = nil,
    fpsLabel = nil,
    pingLabel = nil,
    esp = nil,
    tag = nil,
    wmBar = nil,
    statusAt = 0,
}

local Accent = { fills = {}, texts = {}, strokes = {}, renders = {} }
local Panes = {}

local function regFill(o) table.insert(Accent.fills, o) return o end
local function regText(o) table.insert(Accent.texts, o) return o end
local function regStroke(s) table.insert(Accent.strokes, s) return s end
local function regRender(fn) table.insert(Accent.renders, fn) return fn end
local function regPane(o, base) table.insert(Panes, { o = o, base = base or 0 }) return o end

local function applyTransparency(v)
    for _, p in ipairs(Panes) do
        if p.o and p.o.Parent then
            p.o.BackgroundTransparency = clamp(p.base + (1 - p.base) * v, 0, 1)
        end
    end
end

local function applyTheme(c)
    Config.Accent = c
    for _, o in ipairs(Accent.fills) do
        if o.Parent then o.BackgroundColor3 = c end
    end
    for _, o in ipairs(Accent.texts) do
        if o.Parent then o.TextColor3 = c end
    end
    for _, s in ipairs(Accent.strokes) do
        if s.Parent then s.Color = c end
    end
    for _, fn in ipairs(Accent.renders) do pcall(fn) end
    if State.paintTabs then State.paintTabs() end
    if State.esp and State.esp.Parent then State.esp.FillColor = c end
    if State.wmBar and State.wmBar.Parent then State.wmBar.BackgroundColor3 = c end
end

local function notify(text, dur)
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return end
    local gui = pg:FindFirstChild("PB_Notify")
    if not gui then
        gui = make("ScreenGui", { Name = "PB_Notify", ResetOnSpawn = false,
            IgnoreGuiInset = true, DisplayOrder = 999 }, pg)
    end
    local old = gui:FindFirstChild("toast")
    if old then old:Destroy() end
    local f = make("Frame", {
        Name = "toast",
        Size = UDim2.fromOffset(320, 34),
        Position = UDim2.new(0.5, -160, 1, -74),
        BackgroundColor3 = Config.Panel,
        BorderSizePixel = 0,
    }, gui)
    stroke(f, Config.Accent, 1)
    make("Frame", {
        Size = UDim2.fromOffset(3, 34),
        BackgroundColor3 = Config.Accent,
        BorderSizePixel = 0,
    }, f)
    make("TextLabel", {
        Size = UDim2.new(1, -16, 1, 0),
        Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Config.Text,
        Text = text,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, f)
    task.delay(dur or 2.0, function()
        if not f.Parent then return end
        tween(f, { BackgroundTransparency = 1,
            Position = UDim2.new(0.5, -160, 1, -56) }, 0.22)
    end)
    task.delay((dur or 2.0) + 0.3, function()
        if f.Parent then f:Destroy() end
        if gui.Parent and #gui:GetChildren() == 0 then gui:Destroy() end
    end)
end

local flash
flash = function()
    if not Config.ParryFlash then return end
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return end
    local gui = pg:FindFirstChild("PB_Flash")
    if not gui then
        gui = make("ScreenGui", { Name = "PB_Flash", ResetOnSpawn = false,
            IgnoreGuiInset = true, DisplayOrder = 999 }, pg)
    end
    local old = gui:FindFirstChild("f")
    if old then old:Destroy() end
    local f = make("Frame", {
        Name = "f",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, gui)
    local s = Instance.new("UIStroke")
    s.Color = Config.Accent
    s.Thickness = 2
    s.Transparency = 0.1
    s.Parent = f
    tween(s, { Transparency = 1 }, 0.4)
end

-- ============================== BALL READ ================================
local BallCache = { p = nil, at = 0, missAt = 0 }
local Track = setmetatable({}, { __mode = "k" })

local function nameBall(n)
    n = string.lower(n)
    if n == "ball" or n == "bladeball" or n == "orb" then return true end
    if string.find(n, "ball", 1, true) then return true end
    return false
end

local function ballLike(d)
    if not d or not d.Parent then return false end
    if d:IsA("BasePart") then return nameBall(d.Name) end
    if d:IsA("Model") then
        if nameBall(d.Name) then return true end
        local h = d:FindFirstChild("Handle")
        if h and h:IsA("BasePart") and nameBall(h.Name) then return true end
    end
    return false
end

local function ballPos(b)
    if not b or not b.Parent then return nil end
    if b:IsA("BasePart") then return b.Position end
    if b:IsA("Model") then
        local pp = b.PrimaryPart
        if not pp then pcall(function() pp = b:FindFirstChildWhichIsA("BasePart") end) end
        if pp then return pp.Position end
        local ok, cf = pcall(function() return b:GetPivot() end)
        if ok and cf then return cf.Position end
    end
    return nil
end

local function scanBall(force)
    local now = os.clock()
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local rp = root and root.Position
    if not force and now - BallCache.at < 0.1 and BallCache.p
       and BallCache.p.Parent then
        return BallCache.p
    end
    if not force and not BallCache.p and now - BallCache.missAt < 0.15 then
        return nil
    end
    BallCache.at = now
    local best, bestD = nil, 1e9
    for _, d in ipairs(workspace:GetDescendants()) do
        if ballLike(d) and not (char and d:IsDescendantOf(char)) then
            local p = ballPos(d)
            if p then
                local dist = rp and vlen(p - rp) or 0
                if dist < bestD then best, bestD = d, dist end
            end
        end
    end
    if best and bestD <= 400 then
        BallCache.p = best
        return best
    end
    BallCache.p = nil
    BallCache.missAt = now
    return nil
end

local function ballMotion(ball)
    local now = os.clock()
    local p = ballPos(ball)
    if not p then return 0, Vector3.new(0, 0, 0) end
    local tr = Track[ball]
    if not tr then
        Track[ball] = { p = p, t = now, v = Vector3.new(0, 0, 0), speed = 0 }
        return 0, Vector3.new(0, 0, 0)
    end
    local dt = now - tr.t
    if dt < 0.008 then return tr.speed or 0, tr.v or Vector3.new(0, 0, 0) end
    local v = (p - tr.p) / dt
    tr.p, tr.t = p, now
    tr.v, tr.speed = v, vlen(v)
    return tr.speed, tr.v
end

local function ballReport()
    local ball = scanBall()
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not (ball and root) then return nil end
    local p = ballPos(ball)
    if not p then return nil end
    local speed, vel = ballMotion(ball)
    local toMe = root.Position - p
    local dist = vlen(toMe)
    local closing = 0
    if dist > 0.05 and speed > 0.05 then
        closing = vdot(vel, vunit(toMe))
    end
    local eta = math.huge
    if closing > 0.5 then eta = dist / closing end
    return { ball = ball, pos = p, dist = dist, speed = speed, vel = vel,
             closing = closing, eta = eta }
end

-- ============================== INPUT BRIDGE =============================
local Bridge = { name = "none", key = false, click = false, virtual = false }

local function viewportCenter()
    local cam = workspace.CurrentCamera
    if cam then
        return Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    end
    return Vector2.new(400, 300)
end

do
    local parts = {}
    if typeof(keypress) == "function" or typeof(keyPress) == "function" then
        Bridge.key = true
        table.insert(parts, "key")
    end
    if typeof(mouse1click) == "function" then
        Bridge.click = true
        table.insert(parts, "click")
    end
    local vu = false
    pcall(function()
        vu = type(VirtualUser.Button1Down) == "function"
             and type(VirtualUser.Button1Up) == "function"
    end)
    if vu then
        Bridge.virtual = true
        table.insert(parts, "vu")
    end
    Bridge.name = #parts > 0 and table.concat(parts, "+") or "none"
end

local function keyTap(code)
    local fn = nil
    if typeof(keypress) == "function" then fn = keypress
    elseif typeof(keyPress) == "function" then fn = keyPress end
    if fn then
        local ok = pcall(fn, code)
        if ok then return "key" end
    end
    local ok2 = pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ButtonDown(code)
    end)
    if ok2 then
        task.delay(0.03, function()
            pcall(function() VirtualUser:ButtonUp(code) end)
        end)
        return "vu"
    end
    return nil
end

local function mouseTap()
    if typeof(mouse1click) == "function" then
        local ok = pcall(mouse1click)
        if ok then return "click" end
    end
    local ok2 = pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton1(viewportCenter())
    end)
    if ok2 then return "vu-click" end
    return nil
end

-- ============================== PARRY REMOTE =============================
local Remote = { evt = nil, at = 0, name = "-" }

local function findParryRemote(force)
    local now = os.clock()
    if not force and now - Remote.at < 2 then return Remote.evt end
    Remote.at = now
    local keys = { "parry", "block", "deflect", "clash", "swing", "hit" }
    local best = nil
    local ok = pcall(function()
        for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
            if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
                local n = string.lower(d.Name)
                for _, k in ipairs(keys) do
                    if string.find(n, k, 1, true) then best = d break end
                end
            end
            if best then break end
        end
    end)
    if not ok then best = nil end
    Remote.evt = best
    Remote.name = best and best.Name or "-"
    return best
end

local function remoteTap()
    local r = findParryRemote()
    if not r then return nil end
    local ok = pcall(function()
        if r:IsA("RemoteFunction") then
            r:InvokeServer()
        else
            r:FireServer()
        end
    end)
    if ok then return "remote" end
    return nil
end

-- ============================== CAPTURE ==================================
local Capture = {
    path = "ollie_bb_capture.txt",
    scanPath = "ollie_bb_scan.txt",
    lines = {},
    count = 0,
}
local function capWrite(text, path)
    if typeof(writefile) == "function" then
        local ok = pcall(function() writefile(path, text) end)
        if ok then return true end
    end
    return false
end
local function capLog(line)
    Capture.count = Capture.count + 1
    local stamp = string.format("%d ", Capture.count)
    table.insert(Capture.lines, stamp .. line)
    while #Capture.lines > 100 do table.remove(Capture.lines, 1) end
    local wrote = capWrite(table.concat(Capture.lines, "\n") .. "\n", Capture.path)
    pcall(function() print("[BB] " .. stamp .. line) end)
    return wrote
end
local function capColor(c)
    if not c then return "-" end
    return string.format("%d,%d,%d", math.floor(c.R * 255 + 0.5),
        math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end
local function dumpScan()
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local out = { "blade ball scan  " .. os.date("%Y-%m-%d %H:%M:%S"),
                  "player=" .. LP.Name, "bridge=" .. Bridge.name,
                  "parry remote=" .. Remote.name, "", "remotes:" }
    local ok = pcall(function()
        for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
            if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
                table.insert(out, "  " .. d.ClassName .. " '" .. d.Name .. "'")
            end
            if #out > 260 then break end
        end
    end)
    if not ok then table.insert(out, "  <replicatedstorage read failed>") end
    table.insert(out, "")
    table.insert(out, "ball candidates:")
    local n = 0
    pcall(function()
        for _, d in ipairs(workspace:GetDescendants()) do
            if ballLike(d) then
                local p = ballPos(d)
                local dist = (p and root) and vlen(p - root.Position) or -1
                table.insert(out, string.format("  %s '%s' dist=%.1f",
                    d.ClassName, d.Name, dist))
                n = n + 1
                if n >= 60 then break end
            end
        end
    end)
    if n == 0 then table.insert(out, "  <none found>") end
    table.insert(out, "")
    table.insert(out, "gui hints:")
    local pg = LP:FindFirstChild("PlayerGui")
    if pg then
        local m = 0
        for _, d in ipairs(pg:GetDescendants()) do
            if d:IsA("GuiObject") and not isOwnGui(d) then
                local sz = d.AbsoluteSize
                if sz.X > 60 and sz.Y > 10 and sz.X < 700 then
                    local col = nil
                    if d:IsA("Frame") then col = d.BackgroundColor3
                    elseif d:IsA("ImageLabel") then col = d.ImageColor3 end
                    table.insert(out, string.format("  %s '%s' %.0fx%.0f rgb(%s)%s",
                        d.ClassName, d.Name, sz.X, sz.Y, capColor(col),
                        d.Visible and "" or " hidden"))
                    m = m + 1
                    if m >= 60 then break end
                end
            end
        end
        if m == 0 then table.insert(out, "  <none>") end
    end
    local text = table.concat(out, "\n") .. "\n"
    local wrote = capWrite(text, Capture.scanPath)
    pcall(function() print(text) end)
    return wrote, #out
end

-- ============================== ACTIONS ==================================
local function parryCooldown()
    return Config.ParryCooldown / 1000
end

local fireParry
fireParry = function(reason)
    local now = os.clock()
    if now - State.lastParry < parryCooldown() then return false end
    State.lastParry = now

    local method = Config.ParryMethod
    local used = nil
    if method == "AUTO" or method == "REMOTE" then
        used = remoteTap()
    end
    if not used and (method == "AUTO" or method == "KEY") then
        local code = Enum.KeyCode[Config.ParryKey]
        if code then used = keyTap(code) end
    end
    if not used and (method == "AUTO" or method == "CLICK") then
        used = mouseTap()
    end
    used = used or "none"

    State.parries = State.parries + 1
    State.lastAction = used
    State.lastReason = reason
    if Config.AutoReturn and reason ~= "return" then
        State.returnAt = now + (Config.ReturnMs / 1000)
    end
    if Config.ParryFlash then flash() end
    if Config.Capture then
        local rep = State.target
        local etaMs = (rep and rep.eta < 1000) and math.floor(rep.eta * 1000 + 0.5) or -1
        capLog(string.format(
            "parry reason=%s method=%s eta=%sms dist=%sm speed=%s ball=%s",
            tostring(reason), tostring(used), tostring(etaMs),
            rep and string.format("%.1f", rep.dist) or "-",
            rep and string.format("%.0f", rep.speed) or "-",
            rep and string.sub(rep.ball.Name, 1, 18) or "-"))
    end
    if Config.Verbose then
        notify("parry " .. tostring(reason) .. " // " .. used, 0.9)
    end
    return true
end

local function fireAbility()
    local now = os.clock()
    if now - State.lastAbility < (Config.AbilityCooldown / 1000) then return end
    local code = Enum.KeyCode[Config.AbilityKey]
    if not code then return end
    State.lastAbility = now
    local used = keyTap(code)
    if Config.Verbose then
        notify("ability " .. Config.AbilityKey .. " // " .. tostring(used), 0.8)
    end
end

local function testParry()
    State.lastParry = 0
    local ok = fireParry("test")
    notify(ok and ("test parry // " .. State.lastAction) or "test parry blocked", 1.6)
end

-- ============================== FORWARD DECLS ============================
local Root
local saveConfig, loadConfig, resetConfig, unload, Mount, buildWatermark, updateESP

-- ============================== UI SHELL =================================
local function buildUI()
    State.gen = State.gen + 1
    local gen = State.gen
    Accent.fills, Accent.texts, Accent.strokes, Accent.renders = {}, {}, {}, {}
    Panes = {}

    local pg = LP:WaitForChild("PlayerGui")
    local old = pg:FindFirstChild("PB_Hub")
    if old then old:Destroy() end
    local oldToggle = pg:FindFirstChild("PB_Toggle")
    if oldToggle then oldToggle:Destroy() end
    State.toggleGui = nil

    local W, H = 470, 560
    local HEAD, TABS, FOOT = 46, 34, 26

    local gui = make("ScreenGui", {
        Name = "PB_Hub",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 999,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, pg)

    local root = make("Frame", {
        Name = "root",
        Size = UDim2.fromOffset(W, H),
        Position = State.pos,
        BackgroundColor3 = Config.Bg,
        BorderSizePixel = 0,
        Active = true,
        ClipsDescendants = true,
    }, gui)
    stroke(root, Config.PanelAlt, 1)
    regPane(root, 0)

    local scale = Instance.new("UIScale")
    local fitScale, fitFactor = normalizedScale()
    scale.Scale = fitScale
    scale.Parent = root
    State.scale = scale
    State.fit = fitFactor

    -- header ------------------------------------------------------------
    local head = make("Frame", {
        Name = "head",
        Size = UDim2.new(1, 0, 0, HEAD),
        BackgroundColor3 = Config.Panel,
        BorderSizePixel = 0,
        Active = true,
    }, root)
    stroke(head, Config.PanelAlt, 1)
    regPane(head, 0)

    local mark = make("Frame", {
        Size = UDim2.fromOffset(HEAD, HEAD),
        BackgroundColor3 = Config.Accent,
        BorderSizePixel = 0,
    }, head)
    regFill(mark)
    make("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        TextColor3 = Color3.fromRGB(8, 8, 10),
        Text = "BB",
    }, mark)

    make("TextLabel", {
        Size = UDim2.new(1, -260, 0, 18),
        Position = UDim2.fromOffset(56, 6),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Config.Text,
        Text = "BLADE BALL",
    }, head)
    make("TextLabel", {
        Size = UDim2.new(1, -260, 0, 14),
        Position = UDim2.fromOffset(56, 24),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Config.Dim,
        Text = "SUITE // PARRY ENGINE",
    }, head)

    local dot = make("Frame", {
        Size = UDim2.fromOffset(6, 6),
        Position = UDim2.new(1, -176, 0, 20),
        BackgroundColor3 = Config.Accent,
        BorderSizePixel = 0,
    }, head)
    regFill(dot)
    make("TextLabel", {
        Size = UDim2.fromOffset(44, 14),
        Position = UDim2.new(1, -166, 0, 16),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Config.Dim,
        Text = "LIVE",
    }, head)

    local hideBtn = make("TextButton", {
        Size = UDim2.fromOffset(26, 30),
        Position = UDim2.new(1, -96, 0, 8),
        BackgroundColor3 = Config.PanelAlt,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = Config.Text,
        Text = "H",
        AutoButtonColor = false,
    }, head)
    stroke(hideBtn, Config.PanelAlt, 1)

    local minBtn = make("TextButton", {
        Size = UDim2.fromOffset(26, 30),
        Position = UDim2.new(1, -64, 0, 8),
        BackgroundColor3 = Config.PanelAlt,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        TextColor3 = Config.Text,
        Text = "-",
        AutoButtonColor = false,
    }, head)
    stroke(minBtn, Config.PanelAlt, 1)

    local closeBtn = make("TextButton", {
        Size = UDim2.fromOffset(26, 30),
        Position = UDim2.new(1, -32, 0, 8),
        BackgroundColor3 = Config.PanelAlt,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = Config.Text,
        Text = "X",
        AutoButtonColor = false,
    }, head)
    stroke(closeBtn, Config.PanelAlt, 1)

    -- tabs ---------------------------------------------------------------
    local tabbar = make("Frame", {
        Name = "tabs",
        Size = UDim2.new(1, 0, 0, TABS),
        Position = UDim2.fromOffset(0, HEAD),
        BackgroundColor3 = Config.Panel,
        BorderSizePixel = 0,
    }, root)
    stroke(tabbar, Config.PanelAlt, 1)
    regPane(tabbar, 0)

    local tabNames = { "PARRY", "COMBAT", "MOVE", "VISUAL", "THEME" }
    local tabs = {}

    local underline = make("Frame", {
        Size = UDim2.new(1 / #tabNames, -12, 0, 2),
        Position = UDim2.new(0, 6, 1, -2),
        BackgroundColor3 = Config.Accent,
        BorderSizePixel = 0,
    }, tabbar)
    regFill(underline)

    for i, name in ipairs(tabNames) do
        local btn = make("TextButton", {
            Size = UDim2.new(1 / #tabNames, 0, 1, 0),
            Position = UDim2.new((i - 1) / #tabNames, 0, 0, 0),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            TextColor3 = Config.Dim,
            Text = name,
            AutoButtonColor = false,
        }, tabbar)
        table.insert(tabs, { btn = btn, label = btn })
        btn.MouseButton1Click:Connect(function()
            if gen ~= State.gen then return end
            Config.Tab = i
            if State.paintTabs then State.paintTabs() end
        end)
    end

    -- body ---------------------------------------------------------------
    local body = make("Frame", {
        Name = "body",
        Size = UDim2.new(1, -16, 1, -(HEAD + TABS + FOOT + 8)),
        Position = UDim2.fromOffset(8, HEAD + TABS + 8),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, root)

    local pages = {}
    for i = 1, #tabNames do
        local page = make("ScrollingFrame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Config.Accent,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            Visible = (i == Config.Tab),
        }, body)
        pages[i] = page
    end

    local function paintTabs()
        for i, t in ipairs(tabs) do
            t.label.TextColor3 = (i == Config.Tab) and Config.Accent or Config.Dim
            if pages[i] then pages[i].Visible = (i == Config.Tab) end
        end
        TweenService:Create(underline, TweenInfo.new(0.14), {
            Position = UDim2.new((Config.Tab - 1) / #tabNames, 6, 1, -2),
        }):Play()
    end
    State.paintTabs = paintTabs
    paintTabs()

    -- widgets ------------------------------------------------------------
    local function advance(page, h)
        local cur = page:GetAttribute("cursor") or 0
        page:SetAttribute("cursor", cur + h + 6)
        return cur
    end

    local function section(page, label)
        local pos = advance(page, 20)
        local f = make("Frame", {
            Size = UDim2.new(1, 0, 0, 20),
            Position = UDim2.fromOffset(0, pos),
            BackgroundTransparency = 1,
        }, page)
        regFill(make("Frame", {
            Size = UDim2.fromOffset(2, 11),
            Position = UDim2.fromOffset(0, 5),
            BackgroundColor3 = Config.Accent,
            BorderSizePixel = 0,
        }, f))
        make("TextLabel", {
            Size = UDim2.new(1, -10, 1, 0),
            Position = UDim2.fromOffset(8, 0),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = Config.Dim,
            Text = string.upper(label),
        }, f)
        return f
    end

    local function row(page, h)
        h = h or 34
        local pos = advance(page, h)
        local f = make("Frame", {
            Size = UDim2.new(1, 0, 0, h),
            Position = UDim2.fromOffset(0, pos),
            BackgroundColor3 = Config.Panel,
            BorderSizePixel = 0,
            Active = true,
        }, page)
        stroke(f, Config.PanelAlt, 1)
        f.MouseEnter:Connect(function()
            if f.Parent then tween(f, { BackgroundColor3 = Config.PanelAlt }, 0.1) end
        end)
        f.MouseLeave:Connect(function()
            if f.Parent then tween(f, { BackgroundColor3 = Config.Panel }, 0.1) end
        end)
        return f
    end

    local function rowLabel(r, text, y)
        make("TextLabel", {
            Size = UDim2.new(1, -108, 0, 16),
            Position = UDim2.fromOffset(10, y or 9),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = Config.Text,
            Text = text,
        }, r)
    end

    local function toggleRow(page, label, key, cb)
        local r = row(page, 34)
        rowLabel(r, label)
        local box = make("TextButton", {
            Size = UDim2.fromOffset(40, 18),
            Position = UDim2.new(1, -50, 0.5, -9),
            BackgroundColor3 = Config.PanelAlt,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
        }, r)
        local s = stroke(box, Config.PanelAlt, 1)
        local knob = make("Frame", {
            Size = UDim2.fromOffset(16, 14),
            Position = UDim2.fromOffset(1, 2),
            BackgroundColor3 = Config.Dim,
            BorderSizePixel = 0,
        }, box)
        local function render()
            local on = Config[key]
            box.BackgroundColor3 = on and Config.Accent or Config.PanelAlt
            s.Color = on and Config.Accent or Config.PanelAlt
            knob.Position = on and UDim2.fromOffset(23, 2) or UDim2.fromOffset(1, 2)
            knob.BackgroundColor3 = on and Color3.fromRGB(10, 10, 12) or Config.Dim
        end
        regRender(render)
        render()
        box.MouseButton1Click:Connect(function()
            if gen ~= State.gen then return end
            Config[key] = not Config[key]
            render()
            if cb then cb(Config[key]) end
            notify(label .. ": " .. (Config[key] and "ON" or "OFF"), 1.1)
        end)
    end

    local function sliderRow(page, label, key, min, max, fmt, cb)
        local r = row(page, 46)
        make("TextLabel", {
            Size = UDim2.new(1, -110, 0, 18),
            Position = UDim2.fromOffset(10, 5),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = Config.Text,
            Text = label,
        }, r)
        local val = make("TextLabel", {
            Size = UDim2.fromOffset(96, 18),
            Position = UDim2.new(1, -106, 0, 5),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextColor3 = Config.Accent,
            Text = fmt and fmt(Config[key]) or tostring(Config[key]),
        }, r)
        regText(val)

        local track = make("Frame", {
            Size = UDim2.new(1, -24, 0, 6),
            Position = UDim2.fromOffset(12, 31),
            BackgroundColor3 = Config.PanelAlt,
            BorderSizePixel = 0,
            Active = true,
        }, r)
        local ratio = clamp((Config[key] - min) / (max - min), 0, 1)
        local fill = make("Frame", {
            Size = UDim2.fromScale(ratio, 1),
            BackgroundColor3 = Config.Accent,
            BorderSizePixel = 0,
        }, track)
        regFill(fill)
        local grip = make("Frame", {
            Size = UDim2.fromOffset(4, 14),
            Position = UDim2.new(ratio, -2, 0.5, -7),
            BackgroundColor3 = Config.Text,
            BorderSizePixel = 0,
        }, track)

        local function apply(x)
            if not track.Parent then return end
            local rel = clamp((x - track.AbsolutePosition.X)
                / math.max(1, track.AbsoluteSize.X), 0, 1)
            local v = min + (max - min) * rel
            v = math.floor(v * 100 + 0.5) / 100
            Config[key] = v
            fill.Size = UDim2.fromScale(rel, 1)
            grip.Position = UDim2.new(rel, -2, 0.5, -7)
            val.Text = fmt and fmt(v) or tostring(v)
            if cb then cb(v) end
        end

        track.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1
               or i.UserInputType == Enum.UserInputType.Touch then
                State.dragSlider = apply
                apply(i.Position.X)
            end
        end)
    end

    local function cycleRow(page, label, key, options, cb)
        local r = row(page, 34)
        rowLabel(r, label)
        local btn = make("TextButton", {
            Size = UDim2.fromOffset(112, 22),
            Position = UDim2.new(1, -122, 0.5, -11),
            BackgroundColor3 = Config.PanelAlt,
            BorderSizePixel = 0,
            Font = Enum.Font.GothamBold,
            TextSize = 10,
            TextColor3 = Config.Accent,
            Text = tostring(Config[key]),
            AutoButtonColor = false,
        }, r)
        stroke(btn, Config.PanelAlt, 1)
        regText(btn)
        btn.MouseButton1Click:Connect(function()
            if gen ~= State.gen then return end
            local idx = 1
            for i, o in ipairs(options) do
                if o == Config[key] then idx = i break end
            end
            idx = idx % #options + 1
            Config[key] = options[idx]
            btn.Text = tostring(Config[key])
            if cb then cb(Config[key]) end
        end)
    end

    local function actionRow(page, label, text, cb)
        local r = row(page, 34)
        rowLabel(r, label)
        local btn = make("TextButton", {
            Size = UDim2.fromOffset(112, 22),
            Position = UDim2.new(1, -122, 0.5, -11),
            BackgroundColor3 = Config.PanelAlt,
            BorderSizePixel = 0,
            Font = Enum.Font.GothamBold,
            TextSize = 10,
            TextColor3 = Config.Accent,
            Text = text,
            AutoButtonColor = false,
        }, r)
        stroke(btn, Config.PanelAlt, 1)
        regText(btn)
        btn.MouseButton1Click:Connect(function()
            if gen ~= State.gen then return end
            if cb then cb(btn) end
        end)
        return btn
    end

    -- page 1: parry -------------------------------------------------------
    local p1 = pages[1]
    section(p1, "auto parry")
    toggleRow(p1, "Auto Parry", "AutoParry")
    cycleRow(p1, "Parry Method", "ParryMethod", { "AUTO", "REMOTE", "KEY", "CLICK" })
    cycleRow(p1, "Parry Key", "ParryKey",
        { "Q", "E", "F", "R", "X", "C", "Space" })
    actionRow(p1, "Test parry", "FIRE", function()
        testParry()
    end)
    sliderRow(p1, "Parry Lead", "ParryLead", 0, 250, function(v)
        return string.format("%.0f ms", v)
    end)
    sliderRow(p1, "Parry Range", "ParryRange", 5, 40, function(v)
        return string.format("%.0f m", v)
    end)
    sliderRow(p1, "Parry Cooldown", "ParryCooldown", 50, 1000, function(v)
        return string.format("%.0f ms", v)
    end)
    toggleRow(p1, "Incoming Only", "IncomingOnly")
    toggleRow(p1, "ETA Prediction", "ParryPrediction")
    toggleRow(p1, "Spam Parry", "SpamParry")
    actionRow(p1, "Find remote", "SCAN", function()
        findParryRemote(true)
        notify("parry remote: " .. Remote.name, 2.0)
    end)
    local stRow = row(p1, 40)
    make("TextLabel", {
        Size = UDim2.new(1, -140, 0, 14),
        Position = UDim2.fromOffset(10, 6),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Config.Dim,
        Text = "SIGNAL",
    }, stRow)
    local sig = make("TextLabel", {
        Size = UDim2.fromOffset(130, 14),
        Position = UDim2.new(1, -140, 0, 6),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextColor3 = Config.Accent,
        Text = "--",
    }, stRow)
    regText(sig)
    State.signalLabel = sig
    local ballLab = make("TextLabel", {
        Size = UDim2.new(1, -20, 0, 13),
        Position = UDim2.fromOffset(10, 22),
        BackgroundTransparency = 1,
        Font = Enum.Font.Code,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Config.Dim,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = "d:--  eta:--  v:--",
    }, stRow)
    State.ballLabel = ballLab

    -- page 2: combat ------------------------------------------------------
    local p2 = pages[2]
    section(p2, "aim")
    toggleRow(p2, "Auto Aim", "AutoAim")
    sliderRow(p2, "Aim Strength", "AimStrength", 0.1, 1, function(v)
        return string.format("%.2f", v)
    end)
    toggleRow(p2, "Auto Curve", "AutoCurve")
    sliderRow(p2, "Curve Strength", "CurveStrength", 0.1, 1, function(v)
        return string.format("%.2f", v)
    end)
    section(p2, "defense")
    toggleRow(p2, "Auto Dodge", "AutoDodge")
    sliderRow(p2, "Dodge Range", "DodgeRange", 4, 40, function(v)
        return string.format("%.0f m", v)
    end)
    toggleRow(p2, "Auto Clash", "AutoClash")
    sliderRow(p2, "Clash Range", "ClashRange", 2, 20, function(v)
        return string.format("%.0f m", v)
    end)
    toggleRow(p2, "Auto Return", "AutoReturn")
    sliderRow(p2, "Return Delay", "ReturnMs", 100, 600, function(v)
        return string.format("%.0f ms", v)
    end)
    section(p2, "ability")
    toggleRow(p2, "Auto Ability", "AutoAbility")
    cycleRow(p2, "Ability Key", "AbilityKey",
        { "E", "Q", "F", "R", "X", "C", "V" })
    sliderRow(p2, "Ability CD", "AbilityCooldown", 100, 5000, function(v)
        return string.format("%.0f ms", v)
    end)
    actionRow(p2, "Test ability", "PRESS", function()
        State.lastAbility = 0
        fireAbility()
        notify("ability " .. Config.AbilityKey .. " sent", 1.4)
    end)

    -- page 3: move --------------------------------------------------------
    local p3 = pages[3]
    section(p3, "locomotion")
    toggleRow(p3, "Speed", "SpeedToggle", function(on)
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = on and Config.WalkSpeed or 16 end
    end)
    sliderRow(p3, "Walk Speed", "WalkSpeed", 16, 80, function(v)
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum and Config.SpeedToggle then hum.WalkSpeed = v end
        return string.format("%.0f", v)
    end)
    sliderRow(p3, "Jump Power", "JumpPower", 50, 150, function(v)
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.JumpPower = v
            hum.UseJumpPower = true
        end
        return string.format("%.0f", v)
    end)
    toggleRow(p3, "Infinite Jump", "InfiniteJump")
    actionRow(p3, "Restore defaults", "RESET", function()
        Config.WalkSpeed = 24
        Config.JumpPower = 50
        Config.SpeedToggle = false
        Config.InfiniteJump = false
        Mount()
    end)

    -- page 4: visual ------------------------------------------------------
    local p4 = pages[4]
    section(p4, "overlay")
    toggleRow(p4, "Watermark", "Watermark", function()
        buildWatermark()
    end)
    toggleRow(p4, "Ball ESP", "BallESP", function()
        updateESP()
    end)
    toggleRow(p4, "Parry Flash", "ParryFlash")
    toggleRow(p4, "FPS Counter", "FpsCounter", function(on)
        if State.fpsLabel then State.fpsLabel.Visible = on end
        if State.pingLabel then State.pingLabel.Visible = on end
    end)
    actionRow(p4, "Flash preview", "PULSE", function()
        flash()
    end)
    section(p4, "debug")
    toggleRow(p4, "Capture Log", "Capture", function(on)
        if on then notify("capture: " .. Capture.path, 2.4) end
    end)
    actionRow(p4, "Dump scan", "DUMP", function()
        local wrote, n = dumpScan()
        if wrote then
            notify("wrote " .. Capture.scanPath .. " (" .. n .. " lines)", 2.2)
        else
            notify("scan printed to console (" .. n .. " lines)", 2.2)
        end
    end)
    toggleRow(p4, "Verbose", "Verbose")

    -- page 5: theme -------------------------------------------------------
    local p5 = pages[5]
    section(p5, "accent")
    local swRow = row(p5, 36)
    for i, t in ipairs(THEMES) do
        local sw = make("TextButton", {
            Size = UDim2.fromOffset(36, 20),
            Position = UDim2.fromOffset(10 + (i - 1) * 44, 8),
            BackgroundColor3 = t.Color,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
        }, swRow)
        stroke(sw, Config.PanelAlt, 1)
        sw.MouseButton1Click:Connect(function()
            if gen ~= State.gen then return end
            Config.ThemeName = t.Name
            applyTheme(t.Color)
            notify("theme: " .. t.Name, 1.1)
        end)
    end

    section(p5, "window")
    sliderRow(p5, "UI Scale", "UiScale", 0.8, 1.3, function(v)
        return string.format("%.2f", v)
    end, function()
        if State.scale then
            local fs, fit = normalizedScale()
            State.scale.Scale = fs
            State.fit = fit
        end
    end)
    sliderRow(p5, "Transparency", "UiTransparency", 0, 0.5, function(v)
        return string.format("%.0f%%", v * 100)
    end, function(v)
        applyTransparency(v)
    end)

    section(p5, "input")
    local bindBtn = actionRow(p5, "Menu keybind", Config.Keybind.Name, function(btn)
        State.capturing = true
        btn.Text = "PRESS KEY"
    end)
    State.onKeyCaptured = function(code)
        bindBtn.Text = code.Name
    end

    section(p5, "config")
    actionRow(p5, "Write config", "SAVE", function()
        if saveConfig and saveConfig() then
            notify("config saved", 1.2)
        else
            notify("executor has no file api", 1.6)
        end
    end)
    actionRow(p5, "Read config", "LOAD", function()
        if loadConfig and loadConfig() then
            Mount()
            notify("config loaded", 1.2)
        else
            notify("no saved config", 1.4)
        end
    end)
    actionRow(p5, "Factory reset", "RESET", function()
        if resetConfig then resetConfig() end
        Mount()
        notify("factory reset", 1.2)
    end)

    section(p5, "session")
    actionRow(p5, "Kill suite", "UNLOAD", function()
        if unload then unload() end
    end)

    -- footer --------------------------------------------------------------
    local foot = make("Frame", {
        Name = "foot",
        Size = UDim2.new(1, 0, 0, FOOT),
        Position = UDim2.new(0, 0, 1, -FOOT),
        BackgroundColor3 = Config.Panel,
        BorderSizePixel = 0,
    }, root)
    stroke(foot, Config.PanelAlt, 1)
    regPane(foot, 0)
    make("TextLabel", {
        Size = UDim2.new(1, -150, 1, 0),
        Position = UDim2.fromOffset(10, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Config.Dim,
        Text = "absolute ollie, built by olivia",
    }, foot)
    local fpsLabel = make("TextLabel", {
        Size = UDim2.fromOffset(70, 14),
        Position = UDim2.new(1, -150, 0.5, -7),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextColor3 = Config.Dim,
        Text = "FPS --",
    }, foot)
    local pingLabel = make("TextLabel", {
        Size = UDim2.fromOffset(70, 14),
        Position = UDim2.new(1, -74, 0.5, -7),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextColor3 = Config.Dim,
        Text = "PING --",
    }, foot)
    fpsLabel.Visible = Config.FpsCounter
    pingLabel.Visible = Config.FpsCounter
    State.fpsLabel = fpsLabel
    State.pingLabel = pingLabel

    -- window drag ----------------------------------------------------------
    local dragging, dragStart, startPos = false, nil, nil
    local function beginDrag(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
           or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = i.Position
            startPos = root.Position
        end
    end
    head.InputBegan:Connect(beginDrag)
    tabbar.InputBegan:Connect(beginDrag)
    UserInput.InputChanged:Connect(function(i)
        if gen ~= State.gen then return end
        local moving = i.UserInputType == Enum.UserInputType.MouseMovement
                    or i.UserInputType == Enum.UserInputType.Touch
        if dragging and moving and dragStart then
            local d = i.Position - dragStart
            root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                       startPos.Y.Scale, startPos.Y.Offset + d.Y)
            State.pos = root.Position
        end
    end)
    UserInput.InputEnded:Connect(function(i)
        if gen ~= State.gen then return end
        if i.UserInputType == Enum.UserInputType.MouseButton1
           or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    -- hide / restore (mobile has no keyboard) ------------------------------
    local function showHub()
        State.uiOpen = true
        if root.Parent then root.Visible = true end
        if State.toggleGui then
            pcall(function() State.toggleGui:Destroy() end)
            State.toggleGui = nil
        end
    end

    local function hideHub()
        State.uiOpen = false
        root.Visible = false
        if State.toggleGui then
            pcall(function() State.toggleGui:Destroy() end)
            State.toggleGui = nil
        end
        local pg2 = LP:FindFirstChild("PlayerGui")
        if not pg2 then return end
        local tg = make("ScreenGui", {
            Name = "PB_Toggle",
            ResetOnSpawn = false,
            IgnoreGuiInset = true,
            DisplayOrder = 999,
        }, pg2)
        local tb = make("TextButton", {
            Size = UDim2.fromOffset(36, 36),
            Position = UDim2.new(0, 10, 0.5, -18),
            BackgroundColor3 = Config.Panel,
            BorderSizePixel = 0,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = Config.Accent,
            Text = "BB",
            AutoButtonColor = false,
        }, tg)
        stroke(tb, Config.Accent, 1)
        tb.MouseButton1Click:Connect(function()
            if gen ~= State.gen then return end
            showHub()
        end)
        State.toggleGui = tg
    end
    State.showHub = showHub
    State.hideHub = hideHub

    hideBtn.MouseButton1Click:Connect(function()
        if gen ~= State.gen then return end
        hideHub()
    end)

    -- minimize / close -----------------------------------------------------
    minBtn.MouseButton1Click:Connect(function()
        if gen ~= State.gen then return end
        State.minimized = not State.minimized
        local sh = State.minimized and HEAD or H
        tween(root, { Size = UDim2.fromOffset(W, sh) }, 0.16)
        tabbar.Visible = not State.minimized
        body.Visible = not State.minimized
        foot.Visible = not State.minimized
        minBtn.Text = State.minimized and "+" or "-"
    end)

    closeBtn.MouseButton1Click:Connect(function()
        if gen ~= State.gen then return end
        if unload then unload() end
    end)

    if State.minimized then
        root.Size = UDim2.fromOffset(W, HEAD)
        tabbar.Visible = false
        body.Visible = false
        foot.Visible = false
        minBtn.Text = "+"
    end

    applyTransparency(Config.UiTransparency)
    return root
end

-- ============================== WATERMARK / ESP ==========================
buildWatermark = function()
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return end
    local old = pg:FindFirstChild("PB_Watermark")
    if old then old:Destroy() end
    State.wmBar = nil
    if not Config.Watermark then return end

    local gui = make("ScreenGui", {
        Name = "PB_Watermark",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 999,
    }, pg)
    local f = make("Frame", {
        Size = UDim2.fromOffset(250, 24),
        Position = UDim2.fromOffset(12, 44),
        BackgroundColor3 = Config.Panel,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
    }, gui)
    stroke(f, Config.PanelAlt, 1)
    local bar = make("Frame", {
        Size = UDim2.fromOffset(3, 24),
        BackgroundColor3 = Config.Accent,
        BorderSizePixel = 0,
    }, f)
    regFill(bar)
    State.wmBar = bar
    make("TextLabel", {
        Size = UDim2.new(1, -12, 1, 0),
        Position = UDim2.fromOffset(10, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Config.Dim,
        Text = "OLLIE SUITE  //  BLADE BALL",
    }, f)
end

updateESP = function()
    local pg = LP:FindFirstChild("PlayerGui")
    if not Config.BallESP then
        if State.esp then
            pcall(function() State.esp:Destroy() end)
            State.esp = nil
        end
        if State.tag then
            pcall(function() State.tag:Destroy() end)
            State.tag = nil
        end
        return
    end
    local ball = scanBall(true)
    if not ball then
        if State.esp then
            pcall(function() State.esp:Destroy() end)
            State.esp = nil
        end
        if State.tag then
            pcall(function() State.tag:Destroy() end)
            State.tag = nil
        end
        return
    end
    if not State.esp or not State.esp.Parent then
        local h = Instance.new("Highlight")
        h.Name = "PB_BallESP"
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.FillTransparency = 0.55
        h.OutlineTransparency = 0.1
        h.OutlineColor = Color3.fromRGB(255, 255, 255)
        h.FillColor = Config.Accent
        h.Parent = workspace
        State.esp = h
    end
    State.esp.Adornee = ball
    State.esp.FillColor = Config.Accent

    if pg and (not State.tag or not State.tag.Parent) then
        local bg = Instance.new("BillboardGui")
        bg.Name = "PB_BallTag"
        bg.Size = UDim2.fromOffset(96, 18)
        bg.AlwaysOnTop = true
        bg.StudsOffset = Vector3.new(0, 1.6, 0)
        bg.Adornee = ball
        bg.Parent = pg
        make("TextLabel", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Font = Enum.Font.Code,
            TextSize = 11,
            TextColor3 = Config.Accent,
            Text = "--",
            TextStrokeTransparency = 0.6,
        }, bg)
        State.tag = bg
    end
    if State.tag and State.tag.Parent then
        State.tag.Adornee = ball
        local rep = State.target
        if rep then
            local lab = State.tag:FindFirstChildOfClass("TextLabel")
            if lab then
                lab.Text = string.format("%.1fm", rep.dist)
            end
        end
    end
end

-- ============================== MOUNT ====================================
Mount = function()
    if not State.alive then return end
    Root = buildUI()
    updateESP()
    buildWatermark()
    applyTheme(Config.Accent)
    if State.scale then
        local fs, fit = normalizedScale()
        State.scale.Scale = fs
        State.fit = fit
    end
    applyTransparency(Config.UiTransparency)
    if State.fpsLabel then State.fpsLabel.Visible = Config.FpsCounter end
    if State.pingLabel then State.pingLabel.Visible = Config.FpsCounter end
end

-- ============================== PERSISTENCE ==============================
local SAVE_FILE = "ollie_bb.json"

saveConfig = function()
    if typeof(writefile) ~= "function" then return false end
    local t = {}
    for k, v in pairs(Config) do
        if k == "Accent" then
            t.Accent = {
                math.floor(v.R * 255 + 0.5),
                math.floor(v.G * 255 + 0.5),
                math.floor(v.B * 255 + 0.5),
            }
        elseif k == "Keybind" then
            t.Keybind = v.Name
        elseif type(v) == "number" or type(v) == "boolean" or type(v) == "string" then
            t[k] = v
        end
    end
    local ok = pcall(function()
        writefile(SAVE_FILE, HttpService:JSONEncode(t))
    end)
    return ok
end

loadConfig = function()
    if typeof(isfile) ~= "function" or typeof(readfile) ~= "function" then return false end
    if not isfile(SAVE_FILE) then return false end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(SAVE_FILE))
    end)
    if not ok or type(data) ~= "table" then return false end
    for k, v in pairs(data) do
        if k == "Accent" and type(v) == "table" then
            Config.Accent = Color3.fromRGB(
                tonumber(v[1]) or 0,
                tonumber(v[2]) or 255,
                tonumber(v[3]) or 130
            )
        elseif k == "Keybind" and type(v) == "string" then
            local code = Enum.KeyCode[v]
            if code then Config.Keybind = code end
        elseif Config[k] ~= nil and type(v) == type(Config[k]) then
            Config[k] = v
        end
    end
    Config.Tab = clamp(math.floor(Config.Tab), 1, 5)
    Config.UiTransparency = clamp(Config.UiTransparency, 0, 0.5)
    Config.UiScale = clamp(Config.UiScale, 0.8, 1.3)
    Config.ParryLead = clamp(Config.ParryLead, 0, 250)
    Config.ParryRange = clamp(Config.ParryRange, 5, 40)
    Config.ParryCooldown = clamp(Config.ParryCooldown, 50, 1000)
    Config.AimStrength = clamp(Config.AimStrength, 0.1, 1)
    Config.CurveStrength = clamp(Config.CurveStrength, 0.1, 1)
    Config.DodgeRange = clamp(Config.DodgeRange, 4, 40)
    Config.ClashRange = clamp(Config.ClashRange, 2, 20)
    Config.ReturnMs = clamp(Config.ReturnMs, 100, 600)
    Config.AbilityCooldown = clamp(Config.AbilityCooldown, 100, 5000)
    Config.WalkSpeed = clamp(Config.WalkSpeed, 16, 80)
    Config.JumpPower = clamp(Config.JumpPower, 50, 150)
    local methods = { AUTO = true, REMOTE = true, KEY = true, CLICK = true }
    if not methods[Config.ParryMethod] then Config.ParryMethod = "AUTO" end
    applyTheme(Config.Accent)
    return true
end

resetConfig = function()
    for k, v in pairs(DEFAULTS) do Config[k] = v end
    applyTheme(Config.Accent)
end

-- ============================== UNLOAD ===================================
local Heartbeat
local connKey, connMove, connEnd, connJump

unload = function()
    State.alive = false
    if Heartbeat then
        Heartbeat:Disconnect()
        Heartbeat = nil
    end
    if connKey then connKey:Disconnect() connKey = nil end
    if connMove then connMove:Disconnect() connMove = nil end
    if connEnd then connEnd:Disconnect() connEnd = nil end
    if connJump then connJump:Disconnect() connJump = nil end
    if State.esp then
        pcall(function() State.esp:Destroy() end)
        State.esp = nil
    end
    if State.tag then
        pcall(function() State.tag:Destroy() end)
        State.tag = nil
    end
    local pg = LP:FindFirstChild("PlayerGui")
    if pg then
        for _, n in ipairs({ "PB_Hub", "PB_Notify", "PB_Flash", "PB_Watermark",
                             "PB_Toggle", "PB_BallTag" }) do
            local g = pg:FindFirstChild(n)
            if g then g:Destroy() end
        end
    end
    for _, h in ipairs(workspace:GetChildren()) do
        if h.Name == "PB_BallESP" then h:Destroy() end
    end
end

-- ============================== GLOBAL INPUT =============================
connKey = UserInput.InputBegan:Connect(function(i, gp)
    if gp then return end
    if State.capturing then
        if i.KeyCode ~= Enum.KeyCode.Unknown then
            Config.Keybind = i.KeyCode
            State.capturing = false
            if State.onKeyCaptured then State.onKeyCaptured(i.KeyCode) end
            notify("bind: " .. i.KeyCode.Name, 1.1)
        end
        return
    end
    if i.KeyCode == Config.Keybind then
        if State.uiOpen then
            if State.hideHub then State.hideHub() else State.uiOpen = false end
        else
            if State.showHub then State.showHub() else State.uiOpen = true end
        end
    end
end)

connMove = UserInput.InputChanged:Connect(function(i)
    if not State.dragSlider then return end
    if i.UserInputType == Enum.UserInputType.MouseMovement
       or i.UserInputType == Enum.UserInputType.Touch then
        pcall(State.dragSlider, i.Position.X)
    end
end)

connEnd = UserInput.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
       or i.UserInputType == Enum.UserInputType.Touch then
        State.dragSlider = nil
    end
end)

if UserInput.JumpRequest then
    connJump = UserInput.JumpRequest:Connect(function()
        if not Config.InfiniteJump or not State.alive then return end
        local now = os.clock()
        if now - State.lastJump < 0.12 then return end
        State.lastJump = now
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
        end
    end)
end

-- ============================== DRIVER ===================================
local fpsFrames, fpsClock = 0, 0
local pingClock, espClock = 0, 0

local function driverTick(dt)
    local now = os.clock()
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if Config.SpeedToggle and hum then
        hum.WalkSpeed = Config.WalkSpeed
        hum.JumpPower = Config.JumpPower
        hum.UseJumpPower = true
    end

    local rep = ballReport()
    State.target = rep
    local cam = workspace.CurrentCamera

    -- aim / curve ---------------------------------------------------------
    if cam and rep then
        if Config.AutoAim then
            local goal = CFrame.lookAt(cam.CFrame.Position, rep.pos)
            pcall(function()
                cam.CFrame = cam.CFrame:Lerp(goal, clamp(Config.AimStrength * dt * 8, 0, 1))
            end)
        elseif Config.AutoCurve then
            local lead = rep.pos + (rep.vel or Vector3.new(0, 0, 0)) * 0.15
            local goal = CFrame.lookAt(cam.CFrame.Position, lead)
            pcall(function()
                cam.CFrame = cam.CFrame:Lerp(goal, clamp(Config.CurveStrength * dt * 8, 0, 1))
            end)
        end
    end

    -- dodge ---------------------------------------------------------------
    if Config.AutoDodge and rep and hum and cam and root then
        local incoming = rep.closing > 0.5
        if incoming and rep.dist <= Config.DodgeRange and rep.eta < 0.6 then
            if now - State.lastDodge > 0.4 then
                State.lastDodge = now
                State.dodgeDir = (State.dodgeDir == 1) and -1 or 1
            end
            local right = cam.CFrame.RightVector
            pcall(function() hum:Move(right * State.dodgeDir, false) end)
        end
    end

    -- ability -------------------------------------------------------------
    if Config.AutoAbility and rep then
        local close = rep.dist <= Config.ParryRange
        local soon = rep.eta < 1.0
        if close or soon then fireAbility() end
    end

    -- parry ---------------------------------------------------------------
    if Config.AutoParry and rep then
        local inRange = rep.dist <= Config.ParryRange
        local approaching = rep.closing > 0.5
        local allowed = (not Config.IncomingOnly) or approaching or rep.dist < 6
        local etaMs = rep.eta * 1000
        local trigger
        if Config.ParryPrediction then
            trigger = inRange and allowed and etaMs <= Config.ParryLead
        else
            trigger = inRange and allowed
        end
        if rep.dist < 5 then trigger = true end
        if trigger then fireParry("eta") end
    end

    if Config.SpamParry and rep and rep.dist <= Config.ParryRange then
        fireParry("spam")
    end

    if Config.AutoClash and rep and rep.dist <= Config.ClashRange then
        fireParry("clash")
    end

    if Config.AutoReturn and State.returnAt and now >= State.returnAt then
        State.returnAt = nil
        fireParry("return")
    end

    -- status --------------------------------------------------------------
    if now - State.statusAt > 0.12 then
        State.statusAt = now
        if State.signalLabel and State.signalLabel.Parent then
            local tag
            if not Config.AutoParry then
                tag = "IDLE"
            elseif rep then
                tag = (rep.closing > 0.5) and "INCOMING" or "TRACK"
            else
                tag = "SCAN"
            end
            State.signalLabel.Text = string.format("%s // %s // %d", tag,
                tostring(State.lastAction), State.parries)
        end
        if State.ballLabel and State.ballLabel.Parent then
            if rep then
                State.ballLabel.Text = string.format("d:%.1fm  eta:%sms  v:%.0f  %s",
                    rep.dist,
                    (rep.eta < 1000) and string.format("%.0f", rep.eta * 1000) or "--",
                    rep.speed,
                    Bridge.name)
            else
                State.ballLabel.Text = "no ball // " .. Bridge.name
            end
        end
    end

    fpsFrames = fpsFrames + 1
    fpsClock = fpsClock + dt
    if fpsClock >= 0.5 then
        if State.fpsLabel and State.fpsLabel.Parent then
            State.fpsLabel.Text = string.format("FPS %d", math.floor(fpsFrames / fpsClock + 0.5))
        end
        fpsFrames, fpsClock = 0, 0
    end

    if now - pingClock > 1 then
        pingClock = now
        if State.pingLabel and State.pingLabel.Parent then
            local ping = 0
            pcall(function()
                ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
            end)
            State.pingLabel.Text = string.format("PING %d", ping)
        end
    end

    if Config.BallESP and now - espClock > 0.4 then
        espClock = now
        updateESP()
    end
end

local lastErr, lastErrAt = nil, 0
Heartbeat = RunService.Heartbeat:Connect(function(dt)
    if not State.alive then return end
    local ok, err = pcall(driverTick, dt)
    if ok then return end
    local now = os.clock()
    if now - lastErrAt > 4 or err ~= lastErr then
        lastErr, lastErrAt = err, now
        pcall(function() warn("[BB suite] driver: " .. tostring(err)) end)
        pcall(notify, "driver: " .. tostring(err), 5)
    end
end)

LP.CharacterAdded:Connect(function()
    State.returnAt = nil
    State.lastParry = 0
    State.lastAbility = 0
    BallCache.p = nil
    Track = setmetatable({}, { __mode = "k" })
    task.wait(0.5)
    if Config.SpeedToggle then
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = Config.WalkSpeed
            hum.JumpPower = Config.JumpPower
            hum.UseJumpPower = true
        end
    end
end)

-- ============================== BOOT =====================================
do
    pcall(loadConfig)
    local ok, err = pcall(Mount)
    if ok then
        pcall(notify, "BB suite online // " .. Config.Keybind.Name
            .. " menu // input:" .. Bridge.name, 2.8)
    else
        pcall(function() warn("[BB suite] mount: " .. tostring(err)) end)
        pcall(notify, "mount error: " .. tostring(err), 7)
    end
end
