-- Untitled Wheelie Game — executor script
-- Square UI: Auto Wheelie, Custom Speed, Set TP
-- Targets the real game layout: workspace.Bikes[<player>].Customize.{MaxSpeed,Acceleration,Brake}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Root = Character:WaitForChild("HumanoidRootPart")

local State = {
    AutoWheelie = false,
    Speed = 200,
    Accel = 500,
    Brake = 100,
    SavedTP = nil,
}

local function bikeCustomize()
    local b = workspace:FindFirstChild("Bikes")
    if not b then return nil end
    local mine = b:FindFirstChild(LocalPlayer.Name)
    if not mine then return nil end
    return mine:FindFirstChild("Customize")
end

local function applyStats()
    local c = bikeCustomize()
    if not c then return false end
    for name, val in pairs({ MaxSpeed = State.Speed, Acceleration = State.Accel, Brake = State.Brake }) do
        local v = c:FindFirstChild(name)
        if v and (v:IsA("NumberValue") or v:IsA("IntValue")) then v.Value = val end
    end
    return true
end

local function isRiding()
    local hum = Character:FindFirstChildOfClass("Humanoid")
    return hum and hum.SeatPart ~= nil
end

task.spawn(function()
    while true do
        if State.AutoWheelie and isRiding() then
            local seat = Character:FindFirstChildOfClass("Humanoid").SeatPart
            if seat and seat.Parent then
                local bike = seat.Parent
                local pp = bike.PrimaryPart or seat
                if pp then
                    local cf = pp.CFrame
                    local back = cf * CFrame.Angles(math.rad(-12), 0, 0)
                    pp.CFrame = cf:Lerp(back, 0.25)
                end
            end
        end
        task.wait(0.05)
    end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "OllieWheelieUI"
gui.ResetOnSpawn = false
gui.Parent = game:GetService("CoreGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 280, 0, 300)
frame.Position = UDim2.new(0.5, -140, 0.5, -150)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
frame.BorderSizePixel = 0
frame.Parent = gui
local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 12); corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 32)
title.BackgroundTransparency = 1
title.Text = "wheelie bench — ofx"
title.TextColor3 = Color3.fromRGB(255, 120, 200)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.Parent = frame

local dragging, dragStart, startPos
frame.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true; dragStart = inp.Position; startPos = frame.Position
    end
end)
UserInputService.InputChanged:Connect(function(inp)
    if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
        local d = inp.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                  startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)
UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

local function makeBtn(text, y, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -20, 0, 34)
    b.Position = UDim2.new(0, 10, 0, y)
    b.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
    b.Text = text
    b.TextColor3 = Color3.fromRGB(240, 240, 240)
    b.Font = Enum.Font.Gotham
    b.TextSize = 14
    b.BorderSizePixel = 0
    b.Parent = frame
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = b
    b.MouseButton1Click:Connect(cb)
    return b
end

local function makeLabel(text, y)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -20, 0, 18)
    l.Position = UDim2.new(0, 10, 0, y)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = Color3.fromRGB(200, 200, 200)
    l.Font = Enum.Font.Gotham
    l.TextSize = 13
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = frame
    return l
end

local function makeBox(default, y, cb)
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -20, 0, 30)
    box.Position = UDim2.new(0, 10, 0, y)
    box.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
    box.Text = tostring(default)
    box.TextColor3 = Color3.fromRGB(240, 240, 240)
    box.Font = Enum.Font.Gotham
    box.TextSize = 14
    box.BorderSizePixel = 0
    box.Parent = frame
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = box
    box.FocusLost:Connect(function()
        local n = tonumber(box.Text)
        if n then cb(n) else box.Text = tostring(default) end
    end)
    return box
end

local awBtn = makeBtn("Auto Wheelie: OFF", 40, function()
    State.AutoWheelie = not State.AutoWheelie
    awBtn.Text = "Auto Wheelie: " .. (State.AutoWheelie and "ON" or "OFF")
    awBtn.BackgroundColor3 = State.AutoWheelie and Color3.fromRGB(60, 160, 90) or Color3.fromRGB(40, 40, 48)
end)

makeLabel("Max Speed", 84)
makeBox(State.Speed, 104, function(n)
    State.Speed = math.clamp(n, 1, 10000)
    applyStats()
end)

makeLabel("Acceleration", 144)
makeBox(State.Accel, 164, function(n)
    State.Accel = math.clamp(n, 1, 10000)
    applyStats()
end)

makeLabel("Brake", 204)
makeBox(State.Brake, 224, function(n)
    State.Brake = math.clamp(n, 1, 10000)
    applyStats()
end)

local setTpBtn = makeBtn("Set TP (save pos)", 262, function()
    State.SavedTP = Root.CFrame
    setTpBtn.Text = "TP Target Set"
    task.delay(1.2, function() setTpBtn.Text = "Set TP (save pos)" end)
end)

makeBtn("Teleport to Set TP", 300, function()
    if State.SavedTP then
        Root.CFrame = State.SavedTP
    else
        Root.CFrame = Root.CFrame + Root.CFrame.LookVector * 50
    end
end)

LocalPlayer.CharacterAdded:Connect(function(c)
    Character = c
    Root = c:WaitForChild("HumanoidRootPart")
    task.wait(1)
    applyStats()
end)

task.delay(2, applyStats)

local close = Instance.new("TextButton")
close.Size = UDim2.new(0, 28, 0, 28)
close.Position = UDim2.new(1, -32, 0, 4)
close.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
close.Text = "X"
close.TextColor3 = Color3.fromRGB(255, 255, 255)
close.Font = Enum.Font.GothamBold
close.TextSize = 14
close.BorderSizePixel = 0
close.Parent = frame
local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(0, 6); cc.Parent = close
close.MouseButton1Click:Connect(function() gui:Destroy() end)

print("[ofx] wheelie bench loaded")
