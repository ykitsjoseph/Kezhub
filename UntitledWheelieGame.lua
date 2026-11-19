-- Untitled Wheelie Game — executor script
-- Square UI: Auto Wheelie, Custom Speed, Set TP
-- Run in any modern executor (Synapse X / KRNL / Fluxus / etc.)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Root = Character:WaitForChild("HumanoidRootPart")

local State = {
    AutoWheelie = false,
    Speed = 50,
    SavedTP = nil,
}

local function getBike()
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("Model") and (v.Name:lower():find("bike") or v.Name:lower():find("motor")) then
            local seat = v:FindFirstChildWhichIsA("VehicleSeat") or v:FindFirstChildWhichIsA("Seat")
            if seat and seat.Occupant == LocalPlayer.Character:FindFirstChild("Humanoid") then
                return v, seat
            end
        end
    end
    return nil, nil
end

local function setSpeed(val)
    State.Speed = math.clamp(val, 1, 500)
    local bike, seat = getBike()
    if bike and seat then
        local sv = bike:FindFirstChild("Speed") or bike:FindFirstChild("MaxSpeed")
        if sv and sv:IsA("NumberValue") then sv.Value = State.Speed end
        seat.MaxSpeed = State.Speed
        seat.Torque = State.Speed * 2
    end
end

local function doWheelie()
    local bike, seat = getBike()
    if not bike or not seat then return end
    local remote = game:GetService("ReplicatedStorage"):FindFirstChild("Wheelie")
        or game:GetService("ReplicatedStorage"):FindFirstChild("DoWheelie")
    if remote and remote:IsA("RemoteEvent") then
        remote:FireServer()
    end
    local pp = bike.PrimaryPart
    if pp then
        pp.CFrame = pp.CFrame * CFrame.Angles(math.rad(-15), 0, 0)
    end
end

task.spawn(function()
    while true do
        if State.AutoWheelie then
            pcall(doWheelie)
        end
        task.wait(0.15)
    end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "OllieWheelieUI"
gui.ResetOnSpawn = false
gui.Parent = game:GetService("CoreGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 260, 0, 260)
frame.Position = UDim2.new(0.5, -130, 0.5, -130)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
frame.BorderSizePixel = 0
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = frame

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
        dragging = true
        dragStart = inp.Position
        startPos = frame.Position
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

local awBtn = makeBtn("Auto Wheelie: OFF", 44, function()
    State.AutoWheelie = not State.AutoWheelie
    awBtn.Text = "Auto Wheelie: " .. (State.AutoWheelie and "ON" or "OFF")
    awBtn.BackgroundColor3 = State.AutoWheelie and Color3.fromRGB(60, 160, 90) or Color3.fromRGB(40, 40, 48)
end)

local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.new(1, -20, 0, 20)
speedLabel.Position = UDim2.new(0, 10, 0, 88)
speedLabel.BackgroundTransparency = 1
speedLabel.Text = "Speed: " .. State.Speed
speedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
speedLabel.Font = Enum.Font.Gotham
speedLabel.TextSize = 13
speedLabel.TextXAlignment = Enum.TextXAlignment.Left
speedLabel.Parent = frame

local speedBox = Instance.new("TextBox")
speedBox.Size = UDim2.new(1, -20, 0, 30)
speedBox.Position = UDim2.new(0, 10, 0, 112)
speedBox.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
speedBox.Text = tostring(State.Speed)
speedBox.TextColor3 = Color3.fromRGB(240, 240, 240)
speedBox.Font = Enum.Font.Gotham
speedBox.TextSize = 14
speedBox.BorderSizePixel = 0
speedBox.Parent = frame
local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0, 8); sc.Parent = speedBox

speedBox.FocusLost:Connect(function()
    local n = tonumber(speedBox.Text)
    if n then
        setSpeed(n)
        speedLabel.Text = "Speed: " .. State.Speed
        speedBox.Text = tostring(State.Speed)
    else
        speedBox.Text = tostring(State.Speed)
    end
end)

local setTpBtn = makeBtn("Set TP (save pos)", 152, function()
    State.SavedTP = Root.CFrame
    setTpBtn.Text = "TP Target Set"
    task.delay(1.2, function() setTpBtn.Text = "Set TP (save pos)" end)
end)

local tpBtn = makeBtn("Teleport to Set TP", 196, function()
    if State.SavedTP then
        Root.CFrame = State.SavedTP
    else
        Root.CFrame = Root.CFrame + Root.CFrame.LookVector * 50
    end
end)

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

LocalPlayer.CharacterAdded:Connect(function(c)
    Character = c
    Root = c:WaitForChild("HumanoidRootPart")
end)

print("[ofx] wheelie bench loaded")
