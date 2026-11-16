--[[
    Practical Basketball -- executor suite
    Loader: any Lua executor (Wave, Solara, Delta, Synapse-class).
    UI: sharp-cornered rectangle panel, draggable, RightShift to hide.
    Auto Green: polls the release window, fires mouse1 the frame the zone turns.
    Untested against live build -- see bench notes.
]]

if not game:IsLoaded() then game.Loaded:Wait() end

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local UserInput    = game:GetService("UserInputService")
local VirtualUser  = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")

local LP = Players.LocalPlayer
local Cam = workspace.CurrentCamera

-- ============================== CONFIG BLOCK ==============================
local Config = {
    Keybind        = Enum.KeyCode.RightShift,
    Accent         = Color3.fromRGB(0, 255, 130),
    Bg             = Color3.fromRGB(14, 14, 17),
    Panel          = Color3.fromRGB(22, 22, 27),
    PanelAlt       = Color3.fromRGB(30, 30, 36),
    Text           = Color3.fromRGB(235, 235, 240),
    Dim            = Color3.fromRGB(140, 140, 150),

    -- SHOT
    AutoGreen        = false,
    GreenBiasMs      = 0,     -- negative = earlier release, positive = later
    HumanizeMs       = 8,     -- randomized jitter ceiling, ms
    AutoGreenVerbose = false,

    -- DEFENSE
    AutoSteal      = false,
    StealRange     = 11,      -- studs, player root to ball
    StealCooldown  = 0.55,    -- seconds between attempts
    AutoRebound    = false,

    -- MOVEMENT
    WalkSpeed      = 16,
    JumpPower      = 50,
    SpeedUnlock    = false,

    -- MISC
    AutoPass       = false,
    PassRange      = 20,
}
-- ======================== END CONFIG BLOCK (edit here) ====================

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

local function notify(text, dur)
    local pg = LP:WaitForChild("PlayerGui")
    local gui = LP:FindFirstChild("PB_Notify")
    if not gui then
        gui = make("ScreenGui", {
            Name = "PB_Notify",
            ResetOnSpawn = false,
            IgnoreGuiInset = true,
        }, pg)
    end
    local old = gui:FindFirstChild("toast")
    if old then old:Destroy() end
    local f = make("Frame", {
        Name = "toast",
        Size = UDim2.fromOffset(280, 34),
        Position = UDim2.new(0.5, -140, 1, -70),
        BackgroundColor3 = Config.Panel,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
    }, gui)
    stroke(f, Config.Accent, 1)
    make("Frame", {
        Size = UDim2.fromOffset(3, 34),
        BackgroundColor3 = Config.Accent,
        BorderSizePixel = 0,
    }, f)
    make("TextLabel", {
        Size = UDim2.new(1, -14, 1, 0),
        Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Config.Text,
        Text = text,
    }, f)
    task.delay(dur or 2.2, function()
        if not f.Parent then return end
        local t = TweenService:Create(f, TweenInfo.new(0.25), {
            BackgroundTransparency = 1,
            Position = UDim2.new(0.5, -140, 1, -54),
        })
        t:Play()
        t.Completed:Wait()
        f:Destroy()
        if #gui:GetChildren() == 0 then gui:Destroy() end
    end)
end

-- ============================== RUNTIME STATE ============================
local State = {
    greenArmed = false,
    lastRelease = 0,
    lastSteal = 0,
    uiOpen = true,
    meterCache = nil,
    meterCacheAt = 0,
}

-- ============================== UI SHELL =================================
local function buildUI()
    local old = LP:FindFirstChild("PB_Hub")
    if old then old:Destroy() end
    local pg = LP:WaitForChild("PlayerGui")

    local gui = make("ScreenGui", {
        Name = "PB_Hub",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, pg)

    local root = make("Frame", {
        Name = "root",
        Size = UDim2.fromOffset(340, 452),
        Position = UDim2.new(0, 40, 0.5, -226),
        BackgroundColor3 = Config.Bg,
        BorderSizePixel = 0,
        Active = true,
    }, gui)
    stroke(root, Config.PanelAlt, 1)

    local bar = make("Frame", {
        Name = "bar",
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = Config.Panel,
        BorderSizePixel = 0,
    }, root)
    stroke(bar, Config.PanelAlt, 1)
    make("Frame", {
        Size = UDim2.fromOffset(4, 38),
        BackgroundColor3 = Config.Accent,
        BorderSizePixel = 0,
    }, bar)
    make("TextLabel", {
        Size = UDim2.new(1, -120, 1, 0),
        Position = UDim2.fromOffset(14, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Config.Text,
        Text = "PRACTICAL BASKETBALL // HUB",
    }, bar)
    make("TextLabel", {
        Size = UDim2.fromOffset(80, 38),
        Position = UDim2.new(1, -112, 0, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextColor3 = Config.Dim,
        Text = "[RightShift]",
    }, bar)

    local close = make("TextButton", {
        Size = UDim2.fromOffset(30, 38),
        Position = UDim2.new(1, -32, 0, 0),
        BackgroundColor3 = Config.PanelAlt,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        TextColor3 = Config.Text,
        Text = "X",
        AutoButtonColor = false,
    }, bar)
    stroke(close, Config.PanelAlt, 1)

    local scroll = make("ScrollingFrame", {
        Size = UDim2.new(1, -16, 1, -50),
        Position = UDim2.fromOffset(8, 44),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Config.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
    }, root)

    local y = 0

    local function section(label)
        local h = make("TextLabel", {
            Size = UDim2.new(1, 0, 0, 22),
            Position = UDim2.fromOffset(0, y),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = Config.Accent,
            Text = string.upper(label),
        }, scroll)
        y = y + 26
        return h
    end

    local function toggle(label, key, callback)
        local row = make("Frame", {
            Size = UDim2.new(1, 0, 0, 32),
            Position = UDim2.fromOffset(0, y),
            BackgroundColor3 = Config.Panel,
            BorderSizePixel = 0,
        }, scroll)
        stroke(row, Config.PanelAlt, 1)
        make("TextLabel", {
            Size = UDim2.new(1, -70, 1, 0),
            Position = UDim2.fromOffset(10, 0),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = Config.Text,
            Text = label,
        }, row)

        local box = make("TextButton", {
            Size = UDim2.fromOffset(44, 20),
            Position = UDim2.new(1, -54, 0.5, -10),
            BackgroundColor3 = Config.PanelAlt,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
        }, row)
        stroke(box, Config.PanelAlt, 1)
        local knob = make("Frame", {
            Size = UDim2.fromOffset(18, 16),
            Position = UDim2.fromOffset(1, 2),
            BackgroundColor3 = Config.Dim,
            BorderSizePixel = 0,
        }, box)

        local function render()
            local on = Config[key]
            TweenService:Create(box, TweenInfo.new(0.12), {
                BackgroundColor3 = on and Config.Accent or Config.PanelAlt,
            }):Play()
            TweenService:Create(knob, TweenInfo.new(0.12), {
                Position = on and UDim2.fromOffset(25, 2) or UDim2.fromOffset(1, 2),
                BackgroundColor3 = on and Color3.fromRGB(10, 10, 12) or Config.Dim,
            }):Play()
        end
        render()

        box.MouseButton1Click:Connect(function()
            Config[key] = not Config[key]
            render()
            if callback then callback(Config[key]) end
            notify(label .. ": " .. (Config[key] and "ON" or "OFF"), 1.4)
        end)
        y = y + 36
        return row
    end

    local function slider(label, key, min, max, fmt)
        local row = make("Frame", {
            Size = UDim2.new(1, 0, 0, 44),
            Position = UDim2.fromOffset(0, y),
            BackgroundColor3 = Config.Panel,
            BorderSizePixel = 0,
        }, scroll)
        stroke(row, Config.PanelAlt, 1)
        make("TextLabel", {
            Size = UDim2.new(1, -90, 0, 20),
            Position = UDim2.fromOffset(10, 4),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = Config.Text,
            Text = label,
        }, row)
        local val = make("TextLabel", {
            Size = UDim2.fromOffset(80, 20),
            Position = UDim2.new(1, -90, 0, 4),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextColor3 = Config.Accent,
            Text = fmt and fmt(Config[key]) or tostring(Config[key]),
        }, row)
        local track = make("Frame", {
            Size = UDim2.new(1, -24, 0, 6),
            Position = UDim2.fromOffset(12, 30),
            BackgroundColor3 = Config.PanelAlt,
            BorderSizePixel = 0,
        }, row)
        local fill = make("Frame", {
            Size = UDim2.fromScale((Config[key] - min) / (max - min), 1),
            BackgroundColor3 = Config.Accent,
            BorderSizePixel = 0,
        }, track)
        local grip = make("Frame", {
            Size = UDim2.fromOffset(4, 14),
            Position = UDim2.new((Config[key] - min) / (max - min), -2, 0.5, -7),
            BackgroundColor3 = Config.Text,
            BorderSizePixel = 0,
        }, track)

        local dragging = false
        local function apply(x)
            if track.AbsoluteSize.X <= 0 then return end
            local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            local v = min + (max - min) * rel
            v = math.floor(v * 100 + 0.5) / 100
            Config[key] = v
            fill.Size = UDim2.fromScale(rel, 1)
            grip.Position = UDim2.new(rel, -2, 0.5, -7)
            val.Text = fmt and fmt(v) or tostring(v)
        end
        track.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                apply(i.Position.X)
            end
        end)
        UserInput.InputChanged:Connect(function(i)
            if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
                apply(i.Position.X)
            end
        end)
        UserInput.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
        end)
        y = y + 48
    end

    section("Shot")
    toggle("Auto Green", "AutoGreen")
    slider("Green Bias (ms)", "GreenBiasMs", -80, 80, function(v)
        return string.format("%+.0fms", v)
    end)
    slider("Humanize Jitter (ms)", "HumanizeMs", 0, 40, function(v)
        return string.format("%.0fms", v)
    end)

    section("Defense")
    toggle("Auto Steal", "AutoSteal")
    slider("Steal Range", "StealRange", 4, 30, function(v)
        return string.format("%.0f", v)
    end)
    toggle("Auto Rebound", "AutoRebound")

    section("Offense")
    toggle("Auto Pass", "AutoPass")

    section("Movement")
    toggle("Speed Unlock", "SpeedUnlock", function(on)
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = on and Config.WalkSpeed or 16 end
    end)
    slider("WalkSpeed", "WalkSpeed", 16, 80, function(v)
        return string.format("%.0f", v)
    end)
    slider("JumpPower", "JumpPower", 50, 120, function(v)
        return string.format("%.0f", v)
    end)

    section("Build")
    make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 30),
        Position = UDim2.fromOffset(0, y),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Config.Dim,
        Text = "absolute ollie, built by olivia",
    }, scroll)

    local dragging, dragStart, startPos
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = i.Position
            startPos = root.Position
        end
    end)
    UserInput.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - dragStart
            root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                      startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UserInput.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)

    close.MouseButton1Click:Connect(function()
        State.uiOpen = false
        root.Visible = false
    end)

    UserInput.InputBegan:Connect(function(i, gp)
        if gp then return end
        if i.KeyCode == Config.Keybind then
            State.uiOpen = not State.uiOpen
            root.Visible = State.uiOpen
        end
    end)

    return root
end

local Root = buildUI()

-- ============================== SHOT RELEASE =============================
local function releaseShot()
    local now = os.clock()
    if now - State.lastRelease < 0.12 then return end
    State.lastRelease = now

    local jitter = Config.HumanizeMs > 0 and (math.random() * Config.HumanizeMs) / 1000 or 0
    local bias = Config.GreenBiasMs / 1000
    local wait = jitter + bias
    if wait > 0 then task.wait(wait) end

    if typeof(mouse1click) == "function" then
        pcall(mouse1click)
    elseif typeof(mouse1press) == "function" and typeof(mouse1release) == "function" then
        pcall(mouse1press)
        task.wait(0.01)
        pcall(mouse1release)
    else
        pcall(function()
            VirtualUser:ClickButton1(Vector2.new(Cam.ViewportSize.X / 2, Cam.ViewportSize.Y / 2))
        end)
    end
end

local function keyPress(code)
    if typeof(keypress) == "function" then
        pcall(keypress, code)
        return
    end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ButtonDown(code)
        task.delay(0.04, function() VirtualUser:ButtonUp(code) end)
    end)
end

-- ============================== METER SCAN ===============================
local function isGreenish(color)
    local r, g, b = rgb(color)
    return g > 0.40 and g > r * 1.35 and g > b * 1.15
end

local function meterActive()
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return false end
    local now = os.clock()
    local cached = State.meterCache

    if cached and now - State.meterCacheAt < 0.5 and cached.Parent then
        for _, d in ipairs(cached:GetDescendants()) do
            if d:IsA("GuiObject") and d.Visible and d.AbsoluteSize.Magnitude > 2 then
                if d:IsA("Frame") and isGreenish(d.BackgroundColor3) then return true end
                if d:IsA("TextLabel") and string.find(string.lower(d.Text), "perfect") then
                    return true
                end
            end
        end
        return false
    end

    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("GuiObject") then
            local n = string.lower(d.Name)
            if string.find(n, "meter") or string.find(n, "shot")
               or string.find(n, "release") or string.find(n, "timing")
               or string.find(n, "green") then
                State.meterCache = d
                State.meterCacheAt = now
                local scanRoot = d:IsA("Frame") and d.Parent or d
                for _, c in ipairs(scanRoot:GetDescendants()) do
                    if c:IsA("Frame") and c.Visible and isGreenish(c.BackgroundColor3) then
                        return true
                    end
                    if c:IsA("TextLabel") and string.find(string.lower(c.Text), "perfect") then
                        return true
                    end
                end
                return false
            end
        end
    end
    return false
end

-- ============================== STEAL / REBOUND ==========================
local function findBall()
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("BasePart") then
            local n = string.lower(d.Name)
            if n == "ball" or n == "basketball" or string.find(n, "^ball_") then
                return d
            end
        end
    end
    return nil
end

local function trySteal()
    local now = os.clock()
    if now - State.lastSteal < Config.StealCooldown then return end
    local ball = findBall()
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not (ball and root) then return end
    if (ball.Position - root.Position).Magnitude <= Config.StealRange then
        State.lastSteal = now
        keyPress(Enum.KeyCode.E)
        releaseShot()
    end
end

local function autoRebound()
    local ball = findBall()
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not (ball and root and hum) then return end
    if (ball.Position - root.Position).Magnitude < 60 then
        local dir = (ball.Position - root.Position).Unit
        hum:Move(dir, false)
        if ball.Position.Y > root.Position.Y + 6
           and hum:GetState() ~= Enum.HumanoidStateType.Jumping then
            hum.Jump = true
        end
    end
end

local function autoPass()
    local now = os.clock()
    if now - State.lastSteal < 0.4 then return end
    local ball = findBall()
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not (ball and root) then return end
    if (ball.Position - root.Position).Magnitude > 4 then return end
    local mate = nil
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Team == LP.Team then
            local oc = p.Character
            local oroot = oc and oc:FindFirstChild("HumanoidRootPart")
            if oroot and (oroot.Position - root.Position).Magnitude < Config.PassRange then
                mate = p
                break
            end
        end
    end
    if mate then
        State.lastSteal = now
        keyPress(Enum.KeyCode.F)
    end
end

local function applyMovement()
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if Config.SpeedUnlock then
        hum.WalkSpeed = Config.WalkSpeed
        hum.JumpPower = Config.JumpPower
        hum.UseJumpPower = true
    end
end

-- ============================== DRIVERS ==================================
local heartbeat = RunService.Heartbeat:Connect(function()
    if Config.SpeedUnlock then applyMovement() end

    if Config.AutoGreen then
        local armed = meterActive()
        if armed and not State.greenArmed then
            State.greenArmed = true
            releaseShot()
            if Config.AutoGreenVerbose then notify("green -- released", 0.8) end
        elseif not armed then
            State.greenArmed = false
        end
    end

    if Config.AutoSteal then trySteal() end
    if Config.AutoRebound then autoRebound() end
    if Config.AutoPass then autoPass() end
end)

LP.CharacterAdded:Connect(function()
    State.greenArmed = false
    State.meterCache = nil
    task.wait(0.5)
    applyMovement()
end)

notify("hub loaded -- RightShift to toggle", 2.4)
