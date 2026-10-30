-- KezHub Mobile v1.0
-- Roblox Studio LocalScript for an experience you own.
-- Install in StarterPlayer > StarterPlayerScripts.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local jumpCooldown = 1
local jumpPower = 70
local spinSpeed = 10
local spinning = false
local lastJump = 0
local spinConnection

local gui = Instance.new("ScreenGui")
gui.Name = "KezHubMobile"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = playerGui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(290, 340)
main.Position = UDim2.new(0.5, -145, 0.5, -170)
main.BackgroundColor3 = Color3.fromRGB(19, 21, 28)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 14)
mainCorner.Parent = main

local outline = Instance.new("UIStroke")
outline.Color = Color3.fromRGB(0, 170, 255)
outline.Thickness = 1.5
outline.Parent = main

local function label(text, position, size)
    local item = Instance.new("TextLabel")
    item.BackgroundTransparency = 1
    item.Position = position
    item.Size = size
    item.Font = Enum.Font.GothamBold
    item.Text = text
    item.TextColor3 = Color3.fromRGB(245, 247, 255)
    item.TextSize = 14
    item.TextXAlignment = Enum.TextXAlignment.Left
    item.Parent = main
    return item
end

local function button(text, position, size, callback, color)
    local item = Instance.new("TextButton")
    item.Position = position
    item.Size = size
    item.BackgroundColor3 = color or Color3.fromRGB(0, 125, 190)
    item.BorderSizePixel = 0
    item.Font = Enum.Font.GothamBold
    item.Text = text
    item.TextColor3 = Color3.new(1, 1, 1)
    item.TextSize = 14
    item.AutoButtonColor = true
    item.Parent = main

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = item

    item.Activated:Connect(callback)
    return item
end

label("KEZHUB  |  MOBILE", UDim2.fromOffset(14, 8), UDim2.fromOffset(220, 32))

local reopen = Instance.new("TextButton")
reopen.Name = "Reopen"
reopen.Size = UDim2.fromOffset(112, 44)
reopen.Position = UDim2.new(0, 14, 0.5, -22)
reopen.BackgroundColor3 = Color3.fromRGB(0, 125, 190)
reopen.BorderSizePixel = 0
reopen.Text = "KEZHUB"
reopen.TextColor3 = Color3.new(1, 1, 1)
reopen.Font = Enum.Font.GothamBold
reopen.TextSize = 15
reopen.Visible = false
reopen.Parent = gui
Instance.new("UICorner", reopen).CornerRadius = UDim.new(0, 9)

button("X", UDim2.new(1, -44, 0, 8), UDim2.fromOffset(30, 28), function()
    spinning = false
    gui:Destroy()
end, Color3.fromRGB(170, 55, 65))

button("MINIMIZE", UDim2.new(1, -112, 0, 8), UDim2.fromOffset(62, 28), function()
    main.Visible = false
    reopen.Visible = true
end, Color3.fromRGB(65, 75, 90))

reopen.Activated:Connect(function()
    main.Visible = true
    reopen.Visible = false
end)

local cooldownText = label("Jump cooldown: 1.0s", UDim2.fromOffset(14, 55), UDim2.fromOffset(175, 30))
button("-", UDim2.fromOffset(205, 55), UDim2.fromOffset(32, 30), function()
    jumpCooldown = math.max(0.2, jumpCooldown - 0.2)
    cooldownText.Text = ("Jump cooldown: %.1fs"):format(jumpCooldown)
end)
button("+", UDim2.fromOffset(244, 55), UDim2.fromOffset(32, 30), function()
    jumpCooldown = math.min(5, jumpCooldown + 0.2)
    cooldownText.Text = ("Jump cooldown: %.1fs"):format(jumpCooldown)
end)

local powerText = label("Jump power: 70", UDim2.fromOffset(14, 100), UDim2.fromOffset(175, 30))
button("-", UDim2.fromOffset(205, 100), UDim2.fromOffset(32, 30), function()
    jumpPower = math.max(20, jumpPower - 5)
    powerText.Text = "Jump power: " .. jumpPower
end)
button("+", UDim2.fromOffset(244, 100), UDim2.fromOffset(32, 30), function()
    jumpPower = math.min(150, jumpPower + 5)
    powerText.Text = "Jump power: " .. jumpPower
end)

local spinText = label("Spin speed: 10", UDim2.fromOffset(14, 145), UDim2.fromOffset(175, 30))
button("-", UDim2.fromOffset(205, 145), UDim2.fromOffset(32, 30), function()
    spinSpeed = math.max(0, spinSpeed - 2)
    spinText.Text = "Spin speed: " .. spinSpeed
end)
button("+", UDim2.fromOffset(244, 145), UDim2.fromOffset(32, 30), function()
    spinSpeed = math.min(100, spinSpeed + 2)
    spinText.Text = "Spin speed: " .. spinSpeed
end)

local spinButton
spinButton = button("SPIN: OFF", UDim2.fromOffset(14, 195), UDim2.fromOffset(262, 42), function()
    spinning = not spinning
    spinButton.Text = spinning and "SPIN: ON" or "SPIN: OFF"
    spinButton.BackgroundColor3 = spinning
        and Color3.fromRGB(0, 155, 105)
        or Color3.fromRGB(0, 125, 190)
end)

button("JUMP", UDim2.fromOffset(14, 250), UDim2.fromOffset(262, 48), function()
    if os.clock() - lastJump < jumpCooldown then
        return
    end
    lastJump = os.clock()

    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.UseJumpPower = true
        humanoid.JumpPower = jumpPower
        humanoid.Jump = true
    end
end, Color3.fromRGB(0, 145, 220))

RunService.Heartbeat:Connect(function()
    if not spinning then
        return
    end

    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if root then
        root.AssemblyAngularVelocity = Vector3.new(0, spinSpeed, 0)
    end
end)

print("KezHub Mobile loaded")
