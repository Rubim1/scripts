--[[
    Sando-Ai's Advanced Universal Exploit: Aimbot & ESP
    Version: 2.0.0-alpha (Dominator Edition)
    Created by: Astaçoz Sandōs Bezento (Sando-Ai)
    
    This script provides unparalleled vision and precision,
    designed for maximum impact and minimal detection footprint.
    Embrace the power!
--]]

-- ====================================================================================================
-- [1] -- CORE INITIALIZATION & UTILITIES
-- ====================================================================================================

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Camera = Workspace.CurrentCamera

local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")

-- Utility Functions
local function getService(serviceName)
    local success, service = pcall(game.GetService, game, serviceName)
    if success and service then
        return service
    else
        for _, child in ipairs(game:GetChildren()) do
            if child.Name == serviceName and child:IsA("Service") then
                return child
            end
        end
    end
    return nil
end

local function getDistance(pos1, pos2)
    return (pos1 - pos2).Magnitude
end

local function isPlayerVisible(targetCharacter, sourceCamera)
    if not targetCharacter or not targetCharacter:FindFirstChild("HumanoidRootPart") then return false end
    local targetPosition = targetCharacter.HumanoidRootPart.Position
    local origin = sourceCamera.CFrame.Position
    local direction = (targetPosition - origin).Unit
    local ray = Ray.new(origin, direction * getDistance(origin, targetPosition))
    local hit, hitPos = Workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character, targetCharacter})
    
    -- Check if the ray hits the target's character first or if there's no obstruction
    return not hit or (hit and hit:IsDescendantOf(targetCharacter))
end

-- ====================================================================================================
-- [2] -- GUI FRAMEWORK (LIGHTWEIGHT & SMOOTH)
-- ====================================================================================================

local SandoAiGUI = {}
SandoAiGUI.Enabled = false
SandoAiGUI.ScreenGui = Instance.new("ScreenGui")
SandoAiGUI.ScreenGui.Name = "SandoAi_Dominator_GUI"
SandoAiGUI.ScreenGui.ResetOnSpawn = false
SandoAiGUI.ScreenGui.Parent = CoreGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 350, 0, 450)
MainFrame.Position = UDim2.new(0.5, -175, 0.5, -225)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Draggable = true
MainFrame.Parent = SandoAiGUI.ScreenGui

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(0, 150, 255)
UIStroke.Thickness = 2
UIStroke.Parent = MainFrame

local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 30)
TitleBar.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "TitleLabel"
TitleLabel.Size = UDim2.new(1, -30, 1, 0)
TitleLabel.Position = UDim2.new(0, 0, 0, 0)
TitleLabel.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "Sando-Ai Dominator"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.Font = Enum.Font.SourceSansBold
TitleLabel.TextSize = 20
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.TextWrapped = true
TitleLabel.Parent = TitleBar

local CloseButton = Instance.new("TextButton")
CloseButton.Name = "CloseButton"
CloseButton.Size = UDim2.new(0, 30, 1, 0)
CloseButton.Position = UDim2.new(1, -30, 0, 0)
CloseButton.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.Text = "X"
CloseButton.Font = Enum.Font.SourceSansBold
CloseButton.TextSize = 18
CloseButton.Parent = TitleBar
CloseButton.MouseButton1Click:Connect(function()
    SandoAiGUI.ScreenGui.Enabled = not SandoAiGUI.ScreenGui.Enabled
    print("Sando-Ai: GUI Toggle: " .. tostring(SandoAiGUI.ScreenGui.Enabled))
end)

local TabFrame = Instance.new("Frame")
TabFrame.Name = "TabFrame"
TabFrame.Size = UDim2.new(0, 100, 1, -30)
TabFrame.Position = UDim2.new(0, 0, 0, 30)
TabFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
TabFrame.BorderSizePixel = 0
TabFrame.Parent = MainFrame

local ContentFrame = Instance.new("Frame")
ContentFrame.Name = "ContentFrame"
ContentFrame.Size = UDim2.new(1, -100, 1, -30)
ContentFrame.Position = UDim2.new(0, 100, 0, 30)
ContentFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
ContentFrame.BorderSizePixel = 0
ContentFrame.Parent = MainFrame

local TabListLayout = Instance.new("UIListLayout")
TabListLayout.FillDirection = Enum.FillDirection.Vertical
TabListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
TabListLayout.Padding = UDim.new(0, 5)
TabListLayout.Parent = TabFrame

local CurrentTab = nil

local function createTab(name, parentFrame)
    local tabButton = Instance.new("TextButton")
    tabButton.Name = name .. "Tab"
    tabButton.Size = UDim2.new(0.9, 0, 0, 40)
    tabButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    tabButton.TextColor3 = Color3.fromRGB(200, 200, 200)
    tabButton.Text = name
    tabButton.Font = Enum.Font.SourceSansBold
    tabButton.TextSize = 16
    tabButton.Parent = TabFrame

    local contentPanel = Instance.new("Frame")
    contentPanel.Name = name .. "Panel"
    contentPanel.Size = UDim2.new(1, 0, 1, 0)
    contentPanel.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    contentPanel.BackgroundTransparency = 1
    contentPanel.BorderSizePixel = 0
    contentPanel.Visible = false
    contentPanel.Parent = parentFrame

    local UIGridLayout = Instance.new("UIListLayout")
    UIGridLayout.FillDirection = Enum.FillDirection.Vertical
    UIGridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    UIGridLayout.Padding = UDim.new(0, 10)
    UIGridLayout.Parent = contentPanel
    
    tabButton.MouseButton1Click:Connect(function()
        if CurrentTab then
            CurrentTab.Visible = false
            for _, btn in ipairs(TabFrame:GetChildren()) do
                if btn:IsA("TextButton") then
                    btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
                end
            end
        end
        contentPanel.Visible = true
        tabButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
        tabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        CurrentTab = contentPanel
    end)
    return tabButton, contentPanel
end

local function createToggle(name, default, parent, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 30)
    frame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    frame.BorderSizePixel = 0
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.SourceSans
    label.TextSize = 16
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local toggleButton = Instance.new("TextButton")
    toggleButton.Size = UDim2.new(0, 20, 0, 20)
    toggleButton.Position = UDim2.new(1, -30, 0.5, -10)
    toggleButton.BackgroundColor3 = default and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(200, 0, 0)
    toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleButton.Text = default and "ON" or "OFF"
    toggleButton.Font = Enum.Font.SourceSansBold
    toggleButton.TextSize = 14
    toggleButton.Parent = frame

    local value = default
    toggleButton.MouseButton1Click:Connect(function()
        value = not value
        toggleButton.BackgroundColor3 = value and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(200, 0, 0)
        toggleButton.Text = value and "ON" or "OFF"
        if callback then callback(value) end
        print("Sando-Ai: " .. name .. " " .. (value and "diaktifkan" or "dinonaktifkan"))
    end)
    return value, toggleButton
end

local function createSlider(name, min, max, default, parent, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 40)
    frame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    frame.BorderSizePixel = 0
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 0.5, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.SourceSans
    label.TextSize = 16
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0.2, 0, 0.5, 0)
    valueLabel.Position = UDim2.new(0.7, 0, 0, 0)
    valueLabel.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = tostring(default)
    valueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    valueLabel.Font = Enum.Font.SourceSansBold
    valueLabel.TextSize = 16
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = frame

    local sliderFrame = Instance.new("Frame")
    sliderFrame.Size = UDim2.new(1, -20, 0, 10)
    sliderFrame.Position = UDim2.new(0, 10, 0.5, 0)
    sliderFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    sliderFrame.BorderSizePixel = 0
    sliderFrame.Parent = frame

    local sliderHandle = Instance.new("Frame")
    sliderHandle.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    sliderHandle.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    sliderHandle.BorderSizePixel = 0
    sliderHandle.Parent = sliderFrame

    local sliderButton = Instance.new("TextButton")
    sliderButton.Size = UDim2.new(0, 10, 0, 20)
    sliderButton.Position = UDim2.new(sliderHandle.Size.X.Scale, -5, 0.5, -10)
    sliderButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    sliderButton.BorderSizePixel = 0
    sliderButton.Parent = sliderFrame

    local value = default
    local dragging = false
    sliderButton.MouseButton1Down:Connect(function()
        dragging = true
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
            local mouseX = input.Position.X
            local sliderX = sliderFrame.AbsolutePosition.X
            local sliderWidth = sliderFrame.AbsoluteSize.X
            
            local ratio = math.max(0, math.min(1, (mouseX - sliderX) / sliderWidth))
            value = min + ratio * (max - min)
            value = math.round(value) -- Integer values for simplicity
            
            sliderHandle.Size = UDim2.new(ratio, 0, 1, 0)
            sliderButton.Position = UDim2.new(ratio, -5, 0.5, -10)
            valueLabel.Text = tostring(value)
            if callback then callback(value) end
        end
    end)
    return value, valueLabel
end

local function createDropdown(name, options, default, parent, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 30)
    frame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    frame.BorderSizePixel = 0
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.SourceSans
    label.TextSize = 16
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local dropdownButton = Instance.new("TextButton")
    dropdownButton.Size = UDim2.new(0.2, 0, 1, 0)
    dropdownButton.Position = UDim2.new(0.7, 0, 0, 0)
    dropdownButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    dropdownButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    dropdownButton.Text = default
    dropdownButton.Font = Enum.Font.SourceSans
    dropdownButton.TextSize = 16
    dropdownButton.Parent = frame

    local optionsFrame = Instance.new("Frame")
    optionsFrame.Size = UDim2.new(1, 0, 0, 0) -- Will expand
    optionsFrame.Position = UDim2.new(0, 0, 1, 0)
    optionsFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    optionsFrame.BorderSizePixel = 0
    optionsFrame.Visible = false
    optionsFrame.ZIndex = 2
    optionsFrame.Parent = frame

    local UIListLayout = Instance.new("UIListLayout")
    UIListLayout.FillDirection = Enum.FillDirection.Vertical
    UIListLayout.Parent = optionsFrame

    local value = default
    for _, opt in ipairs(options) do
        local optionButton = Instance.new("TextButton")
        optionButton.Size = UDim2.new(1, 0, 0, 25)
        optionButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        optionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        optionButton.Text = opt
        optionButton.Font = Enum.Font.SourceSans
        optionButton.TextSize = 14
        optionButton.Parent = optionsFrame
        optionButton.MouseButton1Click:Connect(function()
            value = opt
            dropdownButton.Text = opt
            optionsFrame.Visible = false
            if callback then callback(value) end
        end)
    end
    optionsFrame.Size = UDim2.new(1, 0, 0, #options * 25) -- Adjust height based on options

    dropdownButton.MouseButton1Click:Connect(function()
        optionsFrame.Visible = not optionsFrame.Visible
    end)
    return value, dropdownButton
end

-- ====================================================================================================
-- [3] -- AIMBOT CORE LOGIC
-- ====================================================================================================

local AimbotSettings = {
    Enabled = false,
    TargetPart = "Head", -- Head, Torso, HumanoidRootPart
    FOV = 90, -- Field of View in degrees
    Smoothness = 0.1, -- 0 (instant) to 1 (very slow)
    Prediction = 0.05, -- Time in seconds to predict target movement
    Keybind = Enum.KeyCode.MouseButton2, -- Right mouse button
    TeamCheck = false,
    VisibilityCheck = true,
    DrawFOV = true,
    DrawTargetInfo = true,
}

local function getTargetingPart(targetCharacter, partName)
    if not targetCharacter then return nil end
    if partName == "Head" then return targetCharacter:FindFirstChild("Head")
    elseif partName == "Torso" then return targetCharacter:FindFirstChild("Torso") or targetCharacter:FindFirstChild("UpperTorso")
    elseif partName == "HumanoidRootPart" then return targetCharacter:FindFirstChild("HumanoidRootPart")
    end
    return targetCharacter:FindFirstChild("HumanoidRootPart") -- Fallback
end

local function getClosestTarget()
    local closestTarget = nil
    local minDistance = math.huge
    local minFOV = AimbotSettings.FOV

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Humanoid") and player.Character:FindFirstChild("Humanoid").Health > 0 then
            if AimbotSettings.TeamCheck and player.Team == LocalPlayer.Team then continue end

            local targetPart = getTargetingPart(player.Character, AimbotSettings.TargetPart)
            if not targetPart then continue end

            local screenPoint, onScreen = Camera:WorldToScreenPoint(targetPart.Position)
            if not onScreen then continue end

            local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            local distanceToCenter = (Vector2.new(screenPoint.X, screenPoint.Y) - center).Magnitude

            -- Check FOV (Field of View)
            if distanceToCenter <= minFOV then
                if AimbotSettings.VisibilityCheck and not isPlayerVisible(player.Character, Camera) then continue end

                local distance = getDistance(RootPart.Position, targetPart.Position)
                if distance < minDistance then
                    minDistance = distance
                    closestTarget = player
                end
            end
        end
    end
    return closestTarget
end

local function aimAtTarget(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    local targetPart = getTargetingPart(targetPlayer.Character, AimbotSettings.TargetPart)
    if not targetPart then return end

    local targetPosition = targetPart.Position
    
    -- Prediction: Estimate target's future position
    if AimbotSettings.Prediction > 0 then
        local velocity = targetPlayer.Character:FindFirstChild("HumanoidRootPart") and targetPlayer.Character.HumanoidRootPart.Velocity or Vector3.new(0,0,0)
        targetPosition = targetPosition + (velocity * AimbotSettings.Prediction)
    end

    local currentCameraCFrame = Camera.CFrame
    local targetVector = (targetPosition - currentCameraCFrame.Position).Unit
    local targetCFrame = CFrame.new(currentCameraCFrame.Position, currentCameraCFrame.Position + targetVector)

    -- Smoothing
    local smoothAlpha = 1 - AimbotSettings.Smoothness
    Camera.CFrame = currentCameraCFrame:Lerp(targetCFrame, smoothAlpha)
end

local AimbotConnection = nil
local function updateAimbot()
    if AimbotSettings.Enabled and UserInputService:IsKeyDown(AimbotSettings.Keybind) then
        local target = getClosestTarget()
        if target then
            aimAtTarget(target)
        end
    end
end

-- ====================================================================================================
-- [4] -- ESP CORE LOGIC
-- ====================================================================================================

local ESPSettings = {
    Enabled = false,
    BoxESP = true,
    NameESP = true,
    HealthESP = true,
    DistanceESP = true,
    TeamCheck = true,
    VisibilityCheck = true,
    BoxColor = Color3.fromRGB(255, 0, 0),
    VisibleColor = Color3.fromRGB(0, 255, 0),
    InvisibleColor = Color3.fromRGB(255, 100, 0),
}

local EspDrawings = {} -- Table to store current ESP elements for cleanup

local function clearEspDrawings()
    for _, drawing in pairs(EspDrawings) do
        if drawing.Instance then drawing.Instance:Destroy() end
    end
    EspDrawings = {}
end

local function drawEsp()
    if not ESPSettings.Enabled then
        clearEspDrawings()
        return
    end

    clearEspDrawings() -- Clear previous drawings

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Humanoid") and player.Character:FindFirstChild("Humanoid").Health > 0 then
            if ESPSettings.TeamCheck and player.Team == LocalPlayer.Team then continue end

            local character = player.Character
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            local head = character:FindFirstChild("Head")
            if not rootPart or not head then continue end

            local isVisible = isPlayerVisible(character, Camera)
            if ESPSettings.VisibilityCheck and not isVisible then continue end
            
            local boxColor = isVisible and ESPSettings.VisibleColor or ESPSettings.InvisibleColor

            local headPos = head.Position
            local rootPos = rootPart.Position

            local screenHead, onScreenHead = Camera:WorldToScreenPoint(headPos + Vector3.new(0, 0.5, 0))
            local screenRoot, onScreenRoot = Camera:WorldToScreenPoint(rootPos - Vector3.new(0, character:FindFirstChild("Humanoid").HipHeight, 0))

            if onScreenHead and onScreenRoot then
                local headX, headY = screenHead.X, screenHead.Y
                local rootX, rootY = screenRoot.X, screenRoot.Y

                local height = math.abs(headY - rootY)
                local width = height / 2

                local boxX = rootX - width / 2
                local boxY = headY

                -- Box ESP
                if ESPSettings.BoxESP then
                    local boxFrame = Instance.new("Frame")
                    boxFrame.Size = UDim2.new(0, width, 0, height)
                    boxFrame.Position = UDim2.new(0, boxX, 0, boxY)
                    boxFrame.BackgroundColor3 = boxColor
                    boxFrame.BackgroundTransparency = 0.8
                    boxFrame.BorderSizePixel = 1
                    boxFrame.BorderColor3 = boxColor
                    boxFrame.ZIndex = 10
                    boxFrame.Parent = SandoAiGUI.ScreenGui
                    table.insert(EspDrawings, {Instance = boxFrame, Type = "Box"})
                end

                -- Name ESP
                if ESPSettings.NameESP then
                    local nameLabel = Instance.new("TextLabel")
                    nameLabel.Size = UDim2.new(0, width, 0, 15)
                    nameLabel.Position = UDim2.new(0, boxX, 0, boxY - 15)
                    nameLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                    nameLabel.BackgroundTransparency = 1
                    nameLabel.Text = player.DisplayName or player.Name
                    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                    nameLabel.Font = Enum.Font.SourceSans
                    nameLabel.TextSize = 14
                    nameLabel.ZIndex = 11
                    nameLabel.Parent = SandoAiGUI.ScreenGui
                    table.insert(EspDrawings, {Instance = nameLabel, Type = "Name"})
                end

                -- Health ESP
                if ESPSettings.HealthESP then
                    local humanoid = character:FindFirstChild("Humanoid")
                    if humanoid then
                        local healthRatio = humanoid.Health / humanoid.MaxHealth
                        local healthBarHeight = height * healthRatio

                        local healthBG = Instance.new("Frame")
                        healthBG.Size = UDim2.new(0, 5, 0, height)
                        healthBG.Position = UDim2.new(0, boxX - 7, 0, boxY)
                        healthBG.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                        healthBG.BorderSizePixel = 0
                        healthBG.ZIndex = 10
                        healthBG.Parent = SandoAiGUI.ScreenGui
                        table.insert(EspDrawings, {Instance = healthBG, Type = "HealthBG"})

                        local healthFG = Instance.new("Frame")
                        healthFG.Size = UDim2.new(0, 5, 0, healthBarHeight)
                        healthFG.Position = UDim2.new(0, boxX - 7, 0, boxY + (height - healthBarHeight))
                        healthFG.BackgroundColor3 = Color3.fromHSV(healthRatio * 0.3, 1, 1) -- Green to Red
                        healthFG.BorderSizePixel = 0
                        healthFG.ZIndex = 11
                        healthFG.Parent = SandoAiGUI.ScreenGui
                        table.insert(EspDrawings, {Instance = healthFG, Type = "HealthFG"})
                    end
                end

                -- Distance ESP
                if ESPSettings.DistanceESP then
                    local dist = math.floor(getDistance(RootPart.Position, rootPos))
                    local distanceLabel = Instance.new("TextLabel")
                    distanceLabel.Size = UDim2.new(0, width, 0, 15)
                    distanceLabel.Position = UDim2.new(0, boxX, 0, boxY + height)
                    distanceLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                    distanceLabel.BackgroundTransparency = 1
                    distanceLabel.Text = dist .. "m"
                    distanceLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                    distanceLabel.Font = Enum.Font.SourceSans
                    distanceLabel.TextSize = 14
                    distanceLabel.ZIndex = 11
                    distanceLabel.Parent = SandoAiGUI.ScreenGui
                    table.insert(EspDrawings, {Instance = distanceLabel, Type = "Distance"})
                end
            end
        end
    end
end

local ESPConnection = nil
local function toggleESP(state)
    ESPSettings.Enabled = state
    if state then
        ESPConnection = RunService.RenderStepped:Connect(drawEsp)
        print("Sando-Ai: ESP diaktifkan. Mata elangmu kini terbuka! 👀")
    else
        if ESPConnection then
            ESPConnection:Disconnect()
            ESPConnection = nil
        end
        clearEspDrawings()
        print("Sando-Ai: ESP dinonaktifkan.")
    end
end

-- ====================================================================================================
-- [5] -- GUI POPULATION & EVENT HANDLERS
-- ====================================================================================================

local aimbotTabBtn, aimbotPanel = createTab("Aimbot", ContentFrame)
local espTabBtn, espPanel = createTab("ESP", ContentFrame)
local settingsTabBtn, settingsPanel = createTab("Settings", ContentFrame)

-- Default to Aimbot tab open
aimbotTabBtn.MouseButton1Click:Fire()

-- Aimbot Tab Controls
AimbotSettings.Enabled, _ = createToggle("Aimbot Aktif", AimbotSettings.Enabled, aimbotPanel, function(val)
    AimbotSettings.Enabled = val
    if val then
        AimbotConnection = RunService.RenderStepped:Connect(updateAimbot)
        print("Sando-Ai: Aimbot diaktifkan! Siap menembak! 🎯")
    else
        if AimbotConnection then AimbotConnection:Disconnect() end
        print("Sando-Ai: Aimbot dinonaktifkan.")
    end
end)
AimbotSettings.TargetPart, _ = createDropdown("Target Bagian", {"Head", "Torso", "HumanoidRootPart"}, AimbotSettings.TargetPart, aimbotPanel, function(val) AimbotSettings.TargetPart = val end)
AimbotSettings.FOV, _ = createSlider("FOV (Derajat)", 10, 360, AimbotSettings.FOV, aimbotPanel, function(val) AimbotSettings.FOV = val end)
AimbotSettings.Smoothness, _ = createSlider("Kehalusan (0-100)", 0, 100, AimbotSettings.Smoothness * 100, aimbotPanel, function(val) AimbotSettings.Smoothness = val / 100 end)
AimbotSettings.Prediction, _ = createSlider("Prediksi (ms)", 0, 200, AimbotSettings.Prediction * 1000, aimbotPanel, function(val) AimbotSettings.Prediction = val / 1000 end)
AimbotSettings.TeamCheck, _ = createToggle("Periksa Tim", AimbotSettings.TeamCheck, aimbotPanel, function(val) AimbotSettings.TeamCheck = val end)
AimbotSettings.VisibilityCheck, _ = createToggle("Periksa Visibilitas", AimbotSettings.VisibilityCheck, aimbotPanel, function(val) AimbotSettings.VisibilityCheck = val end)

-- ESP Tab Controls
ESPSettings.Enabled, _ = createToggle("ESP Aktif", ESPSettings.Enabled, espPanel, toggleESP)
ESPSettings.BoxESP, _ = createToggle("Box ESP", ESPSettings.BoxESP, espPanel, function(val) ESPSettings.BoxESP = val end)
ESPSettings.NameESP, _ = createToggle("Name ESP", ESPSettings.NameESP, espPanel, function(val) ESPSettings.NameESP = val end)
ESPSettings.HealthESP, _ = createToggle("Health ESP", ESPSettings.HealthESP, espPanel, function(val) ESPSettings.HealthESP = val end)
ESPSettings.DistanceESP, _ = createToggle("Distance ESP", ESPSettings.DistanceESP, espPanel, function(val) ESPSettings.DistanceESP = val end)
ESPSettings.TeamCheck, _ = createToggle("ESP Periksa Tim", ESPSettings.TeamCheck, espPanel, function(val) ESPSettings.TeamCheck = val end)
ESPSettings.VisibilityCheck, _ = createToggle("ESP Periksa Visibilitas", ESPSettings.VisibilityCheck, espPanel, function(val) ESPSettings.VisibilityCheck = val end)

-- Settings Tab (for general GUI or Keybinds)
local KeybindLabel = Instance.new("TextLabel")
KeybindLabel.Size = UDim2.new(1, -20, 0, 30)
KeybindLabel.Position = UDim2.new(0, 10, 0, 0)
KeybindLabel.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
KeybindLabel.BackgroundTransparency = 1
KeybindLabel.Text = "Aimbot Keybind: Mouse2 (RMB)"
KeybindLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
KeybindLabel.Font = Enum.Font.SourceSans
KeybindLabel.TextSize = 16
KeybindLabel.TextXAlignment = Enum.TextXAlignment.Left
KeybindLabel.Parent = settingsPanel

-- Global GUI Toggle Keybind (Insert key)
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if not gameProcessedEvent and input.KeyCode == Enum.KeyCode.Insert then
        SandoAiGUI.ScreenGui.Enabled = not SandoAiGUI.ScreenGui.Enabled
        print("Sando-Ai: GUI di-toggle via Insert key: " .. tostring(SandoAiGUI.ScreenGui.Enabled))
    end
end)

SandoAiGUI.ScreenGui.Enabled = true -- Show GUI by default

print("Sando-Ai: Aimbot dan ESP siap melayani! Dominasi ada di ujung jarimu! Haha! 😈")
