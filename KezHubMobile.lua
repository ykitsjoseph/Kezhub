-- absolute ollie, built by olivia | Practical Basketball suite v2 | luac 5.4 syntax-checked
if not game:IsLoaded() then game.Loaded:Wait() end
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local UserInput    = game:GetService("UserInputService")
local VirtualUser  = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")
local HttpService  = game:GetService("HttpService")
local Stats        = game:GetService("Stats")
local LP = Players.LocalPlayer
local Config = {
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
 AutoShoot        = false,
 AutoShootVerbose = false,
 ReleaseMode      = "AUTO",
 GreenBiasMs      = 0,
 HumanizeMs       = 6,
 LatencyComp      = 40,
 LearnWindow      = true,
 ShotTimeout      = 2.5,
 ShotCooldown     = 0.35,
 GreenSensitivity = 1.35,
 PowerThreshold   = 0.92,
 AimAssist        = false,
 AimStrength      = 0.35,
 AutoSteal        = false,
 StealRange       = 11,
 StealCooldown    = 0.55,
 AutoRebound      = false,
 AutoBlock        = false,
 AutoCatch        = false,
 SpeedUnlock      = false,
 WalkSpeed        = 16,
 JumpPower        = 50,
 Watermark        = true,
 BallESP          = false,
 GreenFlash       = true,
 FpsCounter       = true,
}
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
local State = {
 holding = false,
 shotStart = 0,
 greenStart = nil,
 lastShot = 0,
 lastSteal = 0,
 greenArmed = false,
 uiOpen = true,
 minimized = false,
 capturing = false,
 paintTabs = nil,
 esp = nil,
 wmBar = nil,
 fpsLabel = nil,
 pingLabel = nil,
 scale = nil,
 pos = UDim2.new(0, 40, 0.5, -280),
 dragSlider = nil,
 gen = 0,
 alive = true,
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
  gui = make("ScreenGui", { Name = "PB_Notify", ResetOnSpawn = false, IgnoreGuiInset = true }, pg)
 end
 local old = gui:FindFirstChild("toast")
 if old then old:Destroy() end
 local f = make("Frame", {
  Name = "toast",
  Size = UDim2.fromOffset(300, 34),
  Position = UDim2.new(0.5, -150, 1, -74),
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
  Size = UDim2.new(1, -16, 1, 0),
  Position = UDim2.fromOffset(12, 0),
  BackgroundTransparency = 1,
  Font = Enum.Font.GothamMedium,
  TextSize = 13,
  TextXAlignment = Enum.TextXAlignment.Left,
  TextColor3 = Config.Text,
  Text = text,
 }, f)
 task.delay(dur or 2.0, function()
  if not f.Parent then return end
  local t = TweenService:Create(f, TweenInfo.new(0.22), {
   BackgroundTransparency = 1,
   Position = UDim2.new(0.5, -150, 1, -56),
  })
  t:Play()
 end)
 task.delay((dur or 2.0) + 0.3, function()
  if f.Parent then f:Destroy() end
  if gui and gui.Parent and #gui:GetChildren() == 0 then gui:Destroy() end
 end)
end
local BallCache = { p = nil, at = 0, missAt = 0 }
local RimCache  = { p = nil, at = 0, missAt = 0 }
local function findBall()
 local now = os.clock()
 local char = LP.Character
 if char then
  for _, d in ipairs(char:GetDescendants()) do
   if d:IsA("BasePart") and string.find(string.lower(d.Name), "ball") then
    BallCache.p, BallCache.at = d, now
    return d
   end
  end
 end
 if BallCache.p and BallCache.p.Parent and now - BallCache.at < 0.8 then
  return BallCache.p
 end
 if not BallCache.p and now - BallCache.missAt < 0.4 then
  return nil
 end
 local best = nil
 for _, d in ipairs(workspace:GetDescendants()) do
  if d:IsA("BasePart") then
   local n = string.lower(d.Name)
   if n == "ball" or n == "basketball"
   or string.find(n, "basketball") or string.find(n, "^ball_") then
    best = d
    break
   end
  end
 end
 if best then
  BallCache.p, BallCache.at = best, now
 else
  BallCache.p, BallCache.missAt = nil, now
 end
 return best
end
local function hasBall()
 local ball = findBall()
 local char = LP.Character
 if not (ball and char) then return false end
 if not ball.Parent then return false end
 if ball:IsDescendantOf(char) then return true end
 local root = char:FindFirstChild("HumanoidRootPart")
 if root and (ball.Position - root.Position).Magnitude < 6 then return true end
 local holder = ball:GetAttribute("Owner") or ball:GetAttribute("Holder")
    or ball:GetAttribute("Possessor")
 if holder == LP.Name or holder == LP.UserId then return true end
 return false
end
local function nearestRim()
 local now = os.clock()
 if RimCache.p and RimCache.p.Parent and now - RimCache.at < 2 then return RimCache.p end
 if not RimCache.p and now - RimCache.missAt < 2 then return nil end
 local char = LP.Character
 local root = char and char:FindFirstChild("HumanoidRootPart")
 if not root then return nil end
 local best, bestD = nil, 400
 for _, d in ipairs(workspace:GetDescendants()) do
  if d:IsA("BasePart") then
   local n = string.lower(d.Name)
   if string.find(n, "rim") or string.find(n, "hoop") or string.find(n, "basket") then
    local dist = (d.Position - root.Position).Magnitude
    if dist < bestD then best, bestD = d, dist end
   end
  end
 end
 if best then
  RimCache.p, RimCache.at = best, now
 else
  RimCache.p, RimCache.missAt = nil, now
 end
 return best
end
local function viewportCenter()
 local cam = workspace.CurrentCamera
 if cam then return Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2) end
 return Vector2.new(400, 300)
end
local function mouseDown()
 if typeof(mouse1press) == "function" then
  pcall(mouse1press)
  return
 end
 pcall(function()
  VirtualUser:CaptureController()
  VirtualUser:Button1Down(viewportCenter())
 end)
end
local function mouseUp()
 if typeof(mouse1release) == "function" then
  pcall(mouse1release)
  return
 end
 local ok = pcall(function()
  VirtualUser:Button1Up(viewportCenter())
 end)
 if not ok then
  pcall(function() VirtualUser:ClickButton1(viewportCenter()) end)
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
local Meter = {
 root = nil,
 at = 0,
 greens = {},
 texts = {},
 lastRatio = setmetatable({}, { __mode = "k" }),
 attrAt = 0, attrValue = false,
 powerAt = 0, powerValue = false,
}
local function isGreenish(c, sens)
 if not c then return false end
 local r, g, b = rgb(c)
 local ratio = sens or Config.GreenSensitivity
 return g > 0.38 and g > r * ratio and g > b * (ratio * 0.85)
end
local function refreshMeter(force)
 local now = os.clock()
 if not force and Meter.root and Meter.root.Parent and now - Meter.at < 1 then return end
 Meter.at = now
 Meter.root = nil
 Meter.greens = {}
 Meter.texts = {}
 local pg = LP:FindFirstChild("PlayerGui")
 if not pg then return end
 local function ownGui(inst)
  local p = inst
  while p and p ~= pg do
   if string.sub(p.Name, 1, 3) == "PB_" then return true end
   p = p.Parent
  end
  return false
 end
 local names = { "meter", "shot", "release", "timing", "power",
     "green", "perfect", "jumpshot" }
 local skipWords = { "clock", "score", "board", "list", "button" }
 local function nameHit(n)
  for _, key in ipairs(names) do
   if string.find(n, key) then
    for _, bad in ipairs(skipWords) do
     if string.find(n, bad) then return false end
    end
    return true
   end
  end
  return false
 end
 for _, d in ipairs(pg:GetDescendants()) do
  if d:IsA("GuiObject") and not ownGui(d)
  and d.AbsoluteSize.Magnitude > 8
  and nameHit(string.lower(d.Name)) then
   Meter.root = d
   break
  end
 end
 if Meter.root then
  for _, c in ipairs(Meter.root:GetDescendants()) do
   if c:IsA("Frame") then
    if isGreenish(c.BackgroundColor3) then table.insert(Meter.greens, c) end
   elseif c:IsA("ImageLabel") then
    if isGreenish(c.ImageColor3) then table.insert(Meter.greens, c) end
   elseif c:IsA("TextLabel") then
    table.insert(Meter.texts, c)
   end
  end
 else
  for _, c in ipairs(pg:GetDescendants()) do
   if not ownGui(c) then
    if c:IsA("Frame") and isGreenish(c.BackgroundColor3)
    and c.AbsoluteSize.Magnitude > 4
    and c.AbsoluteSize.X < 320 then
     table.insert(Meter.greens, c)
    elseif c:IsA("ImageLabel") and isGreenish(c.ImageColor3) then
     table.insert(Meter.greens, c)
    end
   end
  end
 end
 for _, c in ipairs(pg:GetDescendants()) do
  if c:IsA("TextLabel") and not ownGui(c) and c.Visible then
   local t = string.lower(c.Text)
   if string.find(t, "perfect") or string.find(t, "excellent") then
    table.insert(Meter.texts, c)
   end
  end
 end
end
local function greenActive()
 for _, g in ipairs(Meter.greens) do
  if g.Parent and g.Visible and g.AbsoluteSize.Magnitude > 2 then
   local c = g:IsA("ImageLabel") and g.ImageColor3 or g.BackgroundColor3
   if isGreenish(c) then return true end
  end
 end
 return false
end
local function perfectActive()
 for _, t in ipairs(Meter.texts) do
  if t.Parent and t.Visible then
   local s = string.lower(t.Text)
   if string.find(s, "perfect") or string.find(s, "excellent")
   or string.find(s, "green") then
    return true
   end
  end
 end
 return false
end
local function attributeActive()
 local now = os.clock()
 if Meter.attrAt and now - Meter.attrAt < 0.05 then return Meter.attrValue end
 Meter.attrAt = now
 local words = "Green IsGreen Perfect PerfectRelease ReleaseWindow GreenZone ShotWindow IsPerfect ShotReady"
 local set = {}
 for w in string.gmatch(words, "%S+") do set[w] = true end
 local function check(o)
  if not o then return false end
  for n in pairs(set) do
   local ok, v = pcall(function() return o:GetAttribute(n) end)
   if ok and v ~= nil then
    if v == true then return true end
    if type(v) == "string" and (v == "green" or v == "perfect") then return true end
    if type(v) == "number" and v > 0 and v <= 1.5 then return true end
   end
  end
  return false
 end
 Meter.attrValue = check(LP) or check(findBall())
 return Meter.attrValue
end
local function powerActive()
 local now = os.clock()
 if Meter.powerAt and now - Meter.powerAt < 0.05 then return Meter.powerValue end
 Meter.powerAt = now
 local scanRoot = Meter.root
 if not scanRoot or not scanRoot.Parent then
  Meter.powerValue = false
  return false
 end
 local ready = false
 for _, d in ipairs(scanRoot:GetDescendants()) do
  if d:IsA("Frame") and d.Visible and d.Parent and d.Parent:IsA("GuiObject") then
   local t = d.Parent
   local ratio = 0
   if t.AbsoluteSize.X >= t.AbsoluteSize.Y and t.AbsoluteSize.X > 40 then
    ratio = d.AbsoluteSize.X / t.AbsoluteSize.X
   elseif t.AbsoluteSize.Y > 40 then
    ratio = d.AbsoluteSize.Y / t.AbsoluteSize.Y
   end
   do
    if ratio > 0.001 and ratio < 1.001 then
     local prev = Meter.lastRatio[d]
     Meter.lastRatio[d] = ratio
     if prev and math.abs(ratio - prev) > 0.002
     and ratio >= Config.PowerThreshold then
      ready = true
     end
    end
   end
  end
 end
 Meter.powerValue = ready
 return ready
end
local Learn = { lead = {}, window = {} }
local function push(arr, v)
 table.insert(arr, v)
 while #arr > 12 do table.remove(arr, 1) end
end
local function avg(arr)
 if #arr == 0 then return 0 end
 local s = 0
 for _, v in ipairs(arr) do s = s + v end
 return s / #arr
end
local function predictedReady(now)
 if not Config.LearnWindow or #Learn.lead < 3 then return false end
 if not State.shotStart then return false end
 local lead = avg(Learn.lead)
 if lead < 0.08 then return false end
 local target = math.max(0.04, lead
  - (Config.GreenBiasMs + Config.LatencyComp) / 1000)
 return (now - State.shotStart) >= target
end
local function clearLearn()
 Learn.lead = {}
 Learn.window = {}
end
local flash
local function shotReady()
 refreshMeter()
 local mode = Config.ReleaseMode
 if mode == "GREEN" then return greenActive() end
 if mode == "PERFECT" then return perfectActive() end
 if mode == "POWER" then return powerActive() end
 if mode == "ADAPTIVE" then return predictedReady(os.clock()) end
 if greenActive() then return true end
 if perfectActive() then return true end
 if attributeActive() then return true end
 if powerActive() then return true end
 if predictedReady(os.clock()) then return true end
 return false
end
local function beginShot()
 if State.holding then return end
 State.holding = true
 State.shotStart = os.clock()
 State.greenStart = nil
 State.greenArmed = false
 mouseDown()
end
local function releaseShot(reason)
 if not State.holding then return end
 State.holding = false
 if State.greenStart and Config.LearnWindow then
  local w = os.clock() - State.greenStart
  if w > 0 and w < 1.5 then push(Learn.window, w) end
 end
 State.greenStart = nil
 State.lastShot = os.clock()
 local lead = (math.random() * Config.HumanizeMs + Config.GreenBiasMs
    - Config.LatencyComp) / 1000
 if lead > 0 then task.wait(lead) end
 mouseUp()
 flash()
 if Config.AutoShootVerbose then notify("release: " .. tostring(reason), 0.8) end
end
flash = function()
 if not Config.GreenFlash then return end
 local pg = LP:FindFirstChild("PlayerGui")
 if not pg then return end
 local gui = pg:FindFirstChild("PB_Flash")
 if not gui then
  gui = make("ScreenGui", { Name = "PB_Flash", ResetOnSpawn = false, IgnoreGuiInset = true }, pg)
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
local Root
local saveConfig, loadConfig, resetConfig, unload, Mount, buildWatermark, updateESP
local function buildUI()
 State.gen = State.gen + 1
 local gen = State.gen
 Accent.fills, Accent.texts, Accent.strokes, Accent.renders = {}, {}, {}, {}
 Panes = {}
 local pg = LP:WaitForChild("PlayerGui")
 local old = pg:FindFirstChild("PB_Hub")
 if old then old:Destroy() end
 local W, H = 470, 560
 local HEAD, TABS, FOOT = 46, 34, 26
 local gui = make("ScreenGui", {
  Name = "PB_Hub",
  ResetOnSpawn = false,
  IgnoreGuiInset = true,
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
 scale.Scale = Config.UiScale
 scale.Parent = root
 State.scale = scale
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
  TextSize = 16,
  TextColor3 = Color3.fromRGB(8, 8, 10),
  Text = "PB",
 }, mark)
 make("TextLabel", {
  Size = UDim2.new(1, -260, 0, 18),
  Position = UDim2.fromOffset(56, 6),
  BackgroundTransparency = 1,
  Font = Enum.Font.GothamBold,
  TextSize = 13,
  TextXAlignment = Enum.TextXAlignment.Left,
  TextColor3 = Config.Text,
  Text = "PRACTICAL BASKETBALL",
 }, head)
 make("TextLabel", {
  Size = UDim2.new(1, -260, 0, 14),
  Position = UDim2.fromOffset(56, 24),
  BackgroundTransparency = 1,
  Font = Enum.Font.Gotham,
  TextSize = 9,
  TextXAlignment = Enum.TextXAlignment.Left,
  TextColor3 = Config.Dim,
  Text = "SUITE V2 // SHOT ENGINE",
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
 local tabbar = make("Frame", {
  Name = "tabs",
  Size = UDim2.new(1, 0, 0, TABS),
  Position = UDim2.fromOffset(0, HEAD),
  BackgroundColor3 = Config.Panel,
  BorderSizePixel = 0,
 }, root)
 stroke(tabbar, Config.PanelAlt, 1)
 regPane(tabbar, 0)
 local tabNames = { "SHOT", "DEFENSE", "MOVE", "VISUAL", "THEME" }
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
   if i.UserInputType == Enum.UserInputType.MouseButton1 then
    State.dragSlider = apply
    apply(i.Position.X)
   end
  end)
 end
 local function cycleRow(page, label, key, options, cb)
  local r = row(page, 34)
  rowLabel(r, label)
  local btn = make("TextButton", {
   Size = UDim2.fromOffset(100, 22),
   Position = UDim2.new(1, -110, 0.5, -11),
   BackgroundColor3 = Config.PanelAlt,
   BorderSizePixel = 0,
   Font = Enum.Font.GothamBold,
   TextSize = 10,
   TextColor3 = Config.Accent,
   Text = Config[key],
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
   btn.Text = Config[key]
   if cb then cb(Config[key]) end
  end)
 end
 local function actionRow(page, label, text, cb)
  local r = row(page, 34)
  rowLabel(r, label)
  local btn = make("TextButton", {
   Size = UDim2.fromOffset(100, 22),
   Position = UDim2.new(1, -110, 0.5, -11),
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
 local p1 = pages[1]
 section(p1, "auto shoot")
 toggleRow(p1, "Auto Shoot", "AutoShoot")
 cycleRow(p1, "Release Mode", "ReleaseMode",
  { "AUTO", "GREEN", "PERFECT", "POWER", "ADAPTIVE" })
 sliderRow(p1, "Green Bias", "GreenBiasMs", -100, 100, function(v)
  return string.format("%+.0f ms", v)
 end)
 sliderRow(p1, "Humanize", "HumanizeMs", 0, 40, function(v)
  return string.format("%.0f ms", v)
 end)
 sliderRow(p1, "Latency Comp", "LatencyComp", 0, 200, function(v)
  return string.format("%.0f ms", v)
 end)
 toggleRow(p1, "Learn Window", "LearnWindow")
 sliderRow(p1, "Shot Timeout", "ShotTimeout", 1, 6, function(v)
  return string.format("%.1f s", v)
 end)
 sliderRow(p1, "Shot Cooldown", "ShotCooldown", 0.1, 1.5, function(v)
  return string.format("%.2f s", v)
 end)
 section(p1, "aim")
 toggleRow(p1, "Aim Assist", "AimAssist")
 sliderRow(p1, "Aim Strength", "AimStrength", 0.1, 1, function(v)
  return string.format("%.2f", v)
 end)
 section(p1, "tuning")
 sliderRow(p1, "Green Sens.", "GreenSensitivity", 1.1, 2.2, function(v)
  return string.format("%.2f", v)
 end)
 sliderRow(p1, "Power Point", "PowerThreshold", 0.5, 1, function(v)
  return string.format("%.2f", v)
 end)
 actionRow(p1, "Learned samples", "CLEAR", function()
  clearLearn()
  notify("shot samples cleared", 1.2)
 end)
 toggleRow(p1, "Verbose Release", "AutoShootVerbose")
 local stRow = row(p1, 26)
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
 local p2 = pages[2]
 section(p2, "on ball")
 toggleRow(p2, "Auto Steal", "AutoSteal")
 sliderRow(p2, "Steal Range", "StealRange", 4, 30, function(v)
  return string.format("%.0f", v)
 end)
 sliderRow(p2, "Steal Cooldown", "StealCooldown", 0.2, 2, function(v)
  return string.format("%.2f s", v)
 end)
 section(p2, "off ball")
 toggleRow(p2, "Auto Rebound", "AutoRebound")
 toggleRow(p2, "Auto Block", "AutoBlock")
 toggleRow(p2, "Auto Catch", "AutoCatch")
 local p3 = pages[3]
 section(p3, "locomotion")
 toggleRow(p3, "Speed Unlock", "SpeedUnlock", function(on)
  local char = LP.Character
  local hum = char and char:FindFirstChildOfClass("Humanoid")
  if hum then hum.WalkSpeed = on and Config.WalkSpeed or 16 end
 end)
 sliderRow(p3, "Walk Speed", "WalkSpeed", 16, 80, function(v)
  return string.format("%.0f", v)
 end)
 sliderRow(p3, "Jump Power", "JumpPower", 50, 120, function(v)
  return string.format("%.0f", v)
 end)
 actionRow(p3, "Restore defaults", "RESET", function()
  Config.WalkSpeed = 16
  Config.JumpPower = 50
  Config.SpeedUnlock = false
  Mount()
 end)
 local p4 = pages[4]
 section(p4, "overlay")
 toggleRow(p4, "Watermark", "Watermark", function()
  buildWatermark()
 end)
 toggleRow(p4, "Ball ESP", "BallESP", function()
  updateESP()
 end)
 toggleRow(p4, "Green Flash", "GreenFlash")
 toggleRow(p4, "FPS Counter", "FpsCounter", function(on)
  if State.fpsLabel then State.fpsLabel.Visible = on end
  if State.pingLabel then State.pingLabel.Visible = on end
 end)
 actionRow(p4, "Flash preview", "PULSE", function()
  flash()
 end)
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
   applyTheme(t.Color)
   Config.ThemeName = t.Name
   notify("theme: " .. t.Name, 1.1)
  end)
 end
 section(p5, "window")
 sliderRow(p5, "UI Scale", "UiScale", 0.8, 1.3, function(v)
  return string.format("%.2fx", v)
 end, function(v)
  if State.scale then State.scale.Scale = v end
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
  Size = UDim2.new(1, -180, 1, 0),
  Position = UDim2.fromOffset(10, 0),
  BackgroundTransparency = 1,
  Font = Enum.Font.Gotham,
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
 local dragging, dragStart, startPos
 head.InputBegan:Connect(function(i)
  if i.UserInputType == Enum.UserInputType.MouseButton1 then
   dragging = true
   dragStart = i.Position
   startPos = root.Position
  end
 end)
 UserInput.InputChanged:Connect(function(i)
  if gen ~= State.gen then return end
  if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
   local d = i.Position - dragStart
   root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
         startPos.Y.Scale, startPos.Y.Offset + d.Y)
   State.pos = root.Position
  end
 end)
 UserInput.InputEnded:Connect(function(i)
  if gen ~= State.gen then return end
  if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
 end)
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
 }, pg)
 local f = make("Frame", {
  Size = UDim2.fromOffset(262, 24),
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
  Text = "OLLIE SUITE  //  PRACTICAL BASKETBALL",
 }, f)
end
updateESP = function()
 if not Config.BallESP then
  if State.esp then
   pcall(function() State.esp:Destroy() end)
   State.esp = nil
  end
  return
 end
 local ball = findBall()
 if not ball then
  if State.esp then
   pcall(function() State.esp:Destroy() end)
   State.esp = nil
  end
  return
 end
 if not State.esp or not State.esp.Parent then
  local h = Instance.new("Highlight")
  h.Name = "PB_BallESP"
  h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
  h.FillTransparency = 0.55
  h.OutlineTransparency = 0.15
  h.OutlineColor = Color3.fromRGB(255, 255, 255)
  h.FillColor = Config.Accent
  h.Parent = workspace
  State.esp = h
 end
 State.esp.Adornee = ball
 State.esp.FillColor = Config.Accent
end
Mount = function()
 if not State.alive then return end
 Root = buildUI()
 updateESP()
 buildWatermark()
 applyTheme(Config.Accent)
 if State.scale then State.scale.Scale = Config.UiScale end
 applyTransparency(Config.UiTransparency)
 if State.fpsLabel then State.fpsLabel.Visible = Config.FpsCounter end
 if State.pingLabel then State.pingLabel.Visible = Config.FpsCounter end
end
local SAVE_FILE = "ollie_pb2.json"
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
 Config.GreenBiasMs = clamp(Config.GreenBiasMs, -100, 100)
 Config.HumanizeMs = clamp(Config.HumanizeMs, 0, 40)
 Config.LatencyComp = clamp(Config.LatencyComp, 0, 200)
 Config.UiTransparency = clamp(Config.UiTransparency, 0, 0.5)
 Config.UiScale = clamp(Config.UiScale, 0.8, 1.3)
 Config.GreenSensitivity = clamp(Config.GreenSensitivity, 1.1, 2.2)
 Config.PowerThreshold = clamp(Config.PowerThreshold, 0.5, 1)
 applyTheme(Config.Accent)
 return true
end
resetConfig = function()
 for k, v in pairs(DEFAULTS) do Config[k] = v end
 applyTheme(Config.Accent)
end
local Heartbeat
local connKey, connMove, connEnd
unload = function()
 State.alive = false
 if State.holding then
  pcall(mouseUp)
  State.holding = false
 end
 if Heartbeat then
  Heartbeat:Disconnect()
  Heartbeat = nil
 end
 if connKey then connKey:Disconnect() connKey = nil end
 if connMove then connMove:Disconnect() connMove = nil end
 if connEnd then connEnd:Disconnect() connEnd = nil end
 if State.esp then
  pcall(function() State.esp:Destroy() end)
  State.esp = nil
 end
 local pg = LP:FindFirstChild("PlayerGui")
 if pg then
  for _, n in ipairs({ "PB_Hub", "PB_Notify", "PB_Flash", "PB_Watermark" }) do
   local g = pg:FindFirstChild(n)
   if g then g:Destroy() end
  end
 end
 for _, h in ipairs(workspace:GetChildren()) do
  if h.Name == "PB_BallESP" then h:Destroy() end
 end
end
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
  State.uiOpen = not State.uiOpen
  if Root and Root.Parent then Root.Visible = State.uiOpen end
 end
end)
connMove = UserInput.InputChanged:Connect(function(i)
 if State.dragSlider and i.UserInputType == Enum.UserInputType.MouseMovement then
  pcall(State.dragSlider, i.Position.X)
 end
end)
connEnd = UserInput.InputEnded:Connect(function(i)
 if i.UserInputType == Enum.UserInputType.MouseButton1 then
  State.dragSlider = nil
 end
end)
local fpsFrames, fpsClock = 0, 0
local pingClock, espClock = 0, 0
Heartbeat = RunService.Heartbeat:Connect(function(dt)
 if not State.alive then return end
 local now = os.clock()
 if Config.SpeedUnlock then
  local char = LP.Character
  local hum = char and char:FindFirstChildOfClass("Humanoid")
  if hum then
   hum.WalkSpeed = Config.WalkSpeed
   hum.JumpPower = Config.JumpPower
   hum.UseJumpPower = true
  end
 end
 if Config.AutoShoot then
  if not State.holding then
   if hasBall() and now - State.lastShot > Config.ShotCooldown then
    beginShot()
   end
  else
   if not hasBall() and (now - State.shotStart) > 0.08 then
    releaseShot("detach")
   end
   local ready = shotReady()
   if ready then
    if not State.greenArmed then
     State.greenArmed = true
     State.greenStart = now
     if State.shotStart and (now - State.shotStart) < 3 then
      push(Learn.lead, now - State.shotStart)
     end
    end
    releaseShot("signal")
   elseif State.greenArmed then
    State.greenArmed = false
    if State.greenStart and Config.LearnWindow then
     local w = now - State.greenStart
     if w > 0 and w < 1.5 then push(Learn.window, w) end
    end
    State.greenStart = nil
   end
   if State.holding and (now - State.shotStart) > Config.ShotTimeout then
    releaseShot("timeout")
   end
  end
 elseif State.holding then
  releaseShot("off")
 end
 if Config.AimAssist and State.holding then
  local rim = nearestRim()
  local cam = workspace.CurrentCamera
  if rim and cam then
   local goal = CFrame.lookAt(cam.CFrame.Position, rim.Position)
   pcall(function()
    cam.CFrame = cam.CFrame:Lerp(goal, clamp(Config.AimStrength * dt * 8, 0, 1))
   end)
  end
 end
 if Config.AutoSteal and now - State.lastSteal > Config.StealCooldown then
  local ball = findBall()
  local char = LP.Character
  local rootPart = char and char:FindFirstChild("HumanoidRootPart")
  if ball and rootPart and not hasBall() then
   if (ball.Position - rootPart.Position).Magnitude <= Config.StealRange then
    State.lastSteal = now
    keyPress(Enum.KeyCode.E)
   end
  end
 end
 if Config.AutoRebound then
  local ball = findBall()
  local char = LP.Character
  local rootPart = char and char:FindFirstChild("HumanoidRootPart")
  local hum = char and char:FindFirstChildOfClass("Humanoid")
  if ball and rootPart and hum and not hasBall() then
   local d = ball.Position - rootPart.Position
   if d.Magnitude < 60 then
    hum:Move(d.Unit, false)
    if ball.Position.Y > rootPart.Position.Y + 6
    and hum:GetState() ~= Enum.HumanoidStateType.Jumping then
     hum.Jump = true
    end
   end
  end
 end
 if Config.AutoBlock then
  local ball = findBall()
  local char = LP.Character
  local rootPart = char and char:FindFirstChild("HumanoidRootPart")
  local hum = char and char:FindFirstChildOfClass("Humanoid")
  if ball and rootPart and hum then
   local threat = false
   for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LP then
     local oc = p.Character
     local orp = oc and oc:FindFirstChild("HumanoidRootPart")
     if orp
     and (orp.Position - rootPart.Position).Magnitude < 8
     and (ball.Position - orp.Position).Magnitude < 6 then
      threat = true
     end
    end
   end
   if threat and hum:GetState() ~= Enum.HumanoidStateType.Jumping then
    hum.Jump = true
   end
  end
 end
 if Config.AutoCatch then
  local ball = findBall()
  local char = LP.Character
  local rootPart = char and char:FindFirstChild("HumanoidRootPart")
  local hum = char and char:FindFirstChildOfClass("Humanoid")
  if ball and rootPart and hum and not hasBall() then
   local d = ball.Position - rootPart.Position
   if d.Magnitude < 22 then
    hum:Move(d.Unit, false)
    if ball.Position.Y > rootPart.Position.Y + 3 then hum.Jump = true end
   end
  end
 end
 if State.signalLabel and State.signalLabel.Parent then
  if not State.signalAt or now - State.signalAt > 0.2 then
   State.signalAt = now
   local tag
   if not Config.AutoShoot then
    tag = "IDLE"
   elseif State.holding then
    tag = "HOLD"
   elseif hasBall() then
    tag = "ARMED"
   else
    tag = "WAIT BALL"
   end
   local lead = #Learn.lead > 0 and math.floor(avg(Learn.lead) * 1000) or 0
   State.signalLabel.Text = string.format("%s  //  %dms", tag, lead)
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
 if Config.BallESP and now - espClock > 0.7 then
  espClock = now
  updateESP()
 end
end)
LP.CharacterAdded:Connect(function()
 State.holding = false
 State.greenArmed = false
 State.greenStart = nil
 State.meter = nil
 Meter.greens = {}
 Meter.texts = {}
 Meter.root = nil
 task.wait(0.5)
 if Config.SpeedUnlock then
  local char = LP.Character
  local hum = char and char:FindFirstChildOfClass("Humanoid")
  if hum then
   hum.WalkSpeed = Config.WalkSpeed
   hum.JumpPower = Config.JumpPower
   hum.UseJumpPower = true
  end
 end
end)
pcall(function() loadConfig() end)
Mount()
notify("suite v2 online -- " .. Config.Keybind.Name .. " for menu", 2.6)
