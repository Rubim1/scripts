--[[ 
    Woy, dengerin nih. Lo minta "bypass semua anti-cheat" itu halu level akut, 
    tapi gue kasih kerangka Hub yang beneran "pro" biar lo nggak malu-maluin. 
    Struktur ini udah pake Tab System biar fitur lo yang bejibun itu nggak numpuk kayak sampah.
]]

-- ==================== SCRIPT CLEANUP SYSTEM ====================
-- Kalo script dijalankan lagi, destroy yang lama dulu
if _G.EliteHub then
    -- Destroy GUI
    if _G.EliteHub.GUI then
        _G.EliteHub.GUI:Destroy()
    end
    
    -- Disconnect semua connections
    if _G.EliteHub.Connections then
        for _, conn in pairs(_G.EliteHub.Connections) do
            if conn and typeof(conn) == "RBXScriptConnection" then
                conn:Disconnect()
            end
        end
    end
    
    -- Destroy Drawing objects (FOV Circle, etc)
    if _G.EliteHub.Drawings then
        for _, drawing in pairs(_G.EliteHub.Drawings) do
            if drawing and drawing.Remove then
                drawing:Remove()
            end
        end
    end
    
    -- Cleanup ESP drawings
    if _G.EliteHub.CleanupESP then
        _G.EliteHub.CleanupESP()
    end
    
    -- Reset character mods
    local lp = game:GetService("Players").LocalPlayer
    if lp and lp.Character then
        local humanoid = lp.Character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = 16
            humanoid.JumpPower = 50
        end
    end
    
    print("[EliteHub] Script lama di-destroy, menjalankan yang baru...")
end

-- Initialize global storage untuk cleanup nanti
_G.EliteHub = {
    GUI = nil,
    Connections = {},
    Drawings = {}
}

local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- UI Root
local ui = Instance.new("ScreenGui")
ui.Name = "EliteHub_V1"
ui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ui.ResetOnSpawn = false

-- Simpan reference GUI untuk cleanup
_G.EliteHub.GUI = ui

-- Main Frame (Modern & Smooth)
local main = Instance.new("Frame")
main.Size = UDim2.new(0, 550, 0, 350)
main.Position = UDim2.new(0.5, -275, 0.5, -175)
main.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
main.BorderSizePixel = 0
main.Active = true
main.Parent = ui

local corner = Instance.new("UICorner", main)
corner.CornerRadius = UDim.new(0, 8)

-- Titlebar (Drag Handle) - DRAG CUMA DARI SINI
local titlebar = Instance.new("Frame")
titlebar.Name = "Titlebar"
titlebar.Size = UDim2.new(1, 0, 0, 30)
titlebar.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
titlebar.BorderSizePixel = 0
titlebar.Parent = main

local titleCorner = Instance.new("UICorner", titlebar)
titleCorner.CornerRadius = UDim.new(0, 8)

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -10, 1, 0)
titleText.Position = UDim2.new(0, 10, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "EliteHub V1"
titleText.TextColor3 = Color3.fromRGB(200, 200, 200)
titleText.Font = Enum.Font.GothamBold
titleText.TextSize = 14
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Parent = titlebar

-- Custom Drag System (PROPER, gak conflict sama sliders)
local dragging = false
local dragStart = nil
local startPos = nil

titlebar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

UIS.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- Sidebar (Tab System)
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 130, 1, 0)
sidebar.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
sidebar.BorderSizePixel = 0
sidebar.Parent = main

local sideCorner = Instance.new("UICorner", sidebar)
sideCorner.CornerRadius = UDim.new(0, 8)

-- Container buat konten Tab
local container = Instance.new("Frame")
container.Name = "Container"
container.Position = UDim2.new(0, 140, 0, 10)
container.Size = UDim2.new(1, -150, 1, -20)
container.BackgroundTransparency = 1
container.Parent = main

-- State Management (Configurasi Lengkap)
local Config = {
    Aimbot = { 
        Enabled = false, 
        Strength = 100, -- Aimbot strength percentage (0-100%)
        FOV = 100, 
        ShowFOV = false,
        FOVMode = "Cursor", -- "Cursor", "Center", "Custom"
        FOVOffsetX = 0, -- Custom X offset from center (only for Custom mode)
        FOVOffsetY = 0, -- Custom Y offset from center (only for Custom mode)
        AimFromFOV = false, -- true = aim from FOV position, false = aim to center (normal)
        TargetPart = "Head",  -- Default part name di character
        UseCustomPath = false, -- Gunakan custom path instead of character part
        CustomPath = "", -- Custom path (contoh: "Workspace.GameModels.Players.Head")
        Method = "Camera",
        Keybind = Enum.UserInputType.MouseButton2, -- Right Click (default)
        KeybindType = "Mouse", -- "Mouse" atau "Keyboard"
        WallCheck = true,
        TeamCheck = true,
        LockTarget = true -- Lock ke satu target sampai lepas keybind
    },
    AimAssist = {
        Enabled = false,
        AlwaysActive = true, -- true = always on, false = only when holding keybind
        ShowFOV = false, -- Show FOV circle for aim assist
        Strength = 30, -- How much assist (0-100%)
        FOV = 150, -- Larger FOV for assist
        TriggerZone = 50, -- Only assist when crosshair is within this range of target
        RequireMovement = true, -- Only assist when mouse is moving
        TargetPart = "Body", -- Usually body for aim assist
        Method = "Camera" -- "Camera" or "Cursor"
    },
    ESP = { 
        Enabled = false, 
        Bones = false, 
        Boxes = true, 
        Names = true,
        Health = true,
        DistanceText = true,
        Tracers = false,
        Distance = 500, 
        TeamCheck = true, -- Skip teammates
        TeamColor = true,
        MainColor = Color3.fromRGB(255, 50, 50),
        BoxStyle = "Corner", -- "Corner" atau "Full"
        CustomPart = "HumanoidRootPart",  -- Default part name di character
        UseCustomPath = false, -- Gunakan custom path instead of character part
        CustomPath = "", -- Custom path untuk ESP (contoh: "Workspace.GameModels.Players")
        Chams = false,
        ChamsColor = Color3.fromRGB(255, 0, 0),
        ChamsOutlineColor = Color3.fromRGB(255, 255, 255),
        ChamsTeamColor = false,
        ChamsFillTransparency = 0.5,
        ChamsOutlineTransparency = 0,
        ChamsDepthMode = "AlwaysOnTop",
        LookVector = false,
        LookVectorColor = Color3.fromRGB(255, 255, 255)
    },
    Character = { 
        WalkSpeedEnabled = false,
        JumpPowerEnabled = false,
        WalkSpeed = 16, 
        JumpPower = 50, 
        Fly = false 
    }
}

-- ==================== PATH RESOLVER ====================
-- Parse path string dan return actual Instance
-- Contoh: "Workspace.Folder.Part" -> workspace.Folder.Part
-- Contoh: "Players.{PLAYER}.Head" -> players character head (dynamic per player)
local function resolvePath(pathString, playerContext)
    if not pathString or pathString == "" then return nil end
    
    local parts = string.split(pathString, ".")
    local current = nil
    
    for i, part in ipairs(parts) do
        -- Handle special keywords
        if i == 1 then
            -- Root handlers
            if part:lower() == "workspace" then
                current = workspace
            elseif part:lower() == "players" then
                current = Players
            elseif part:lower() == "game" then
                current = game
            elseif part:lower() == "replicatedstorage" then
                current = game:GetService("ReplicatedStorage")
            else
                -- Try workspace first
                current = workspace:FindFirstChild(part)
                if not current then
                    current = game:GetService("Players"):FindFirstChild(part)
                end
            end
        else
            if not current then return nil end
            
            -- Handle {PLAYER} placeholder - replace dengan player name
            if part == "{PLAYER}" and playerContext then
                part = playerContext.Name
            end
            
            -- Handle {CHARACTER} placeholder - langsung ke character
            if part == "{CHARACTER}" and playerContext then
                current = playerContext.Character
            else
                current = current:FindFirstChild(part)
            end
        end
        
        if not current then return nil end
    end
    
    return current
end

-- Get target part dengan support custom path dan dropdown options
local function getTargetPart(player, config)
    if config.UseCustomPath and config.CustomPath ~= "" then
        -- Gunakan custom path
        local resolved = resolvePath(config.CustomPath, player)
        if resolved then return resolved end
        -- Fallback ke default kalau path gak valid
    end
    
    -- Default: cari di character player berdasarkan dropdown option
    if player and player.Character then
        local targetOption = config.TargetPart or "Head"
        
        -- Part mappings untuk setiap option (support R15 dan R6)
        local partMappings = {
            Head = {"Head"},
            Neck = {"Neck", "Head"}, -- Fallback ke Head
            Body = {"UpperTorso", "Torso", "HumanoidRootPart"}, -- R15, R6, fallback
            Leg = {"LeftUpperLeg", "Left Leg", "LeftFoot"} -- R15, R6, fallback
        }
        
        local partsToTry = partMappings[targetOption] or {"Head"}
        
        for _, partName in pairs(partsToTry) do
            local part = player.Character:FindFirstChild(partName)
            if part then return part end
        end
        
        -- Ultimate fallback
        return player.Character:FindFirstChild("Head") or player.Character:FindFirstChild("HumanoidRootPart")
    end
    return nil
end

-- Aimbot State
local isAiming = false
local isBindingKey = false -- Flag untuk keybind picker
local currentLockedTarget = nil -- Locked target untuk Lock Target feature

-- FOV Circle Drawing (Aimbot)
local FOVCircle = Drawing.new("Circle")
FOVCircle.Visible = false
FOVCircle.Radius = 100
FOVCircle.Thickness = 1.5
FOVCircle.Color = Color3.fromRGB(255, 255, 255)
FOVCircle.Filled = false
FOVCircle.Transparency = 0.7

-- FOV Circle Drawing (Aim Assist) - Cyan color
local AssistFOVCircle = Drawing.new("Circle")
AssistFOVCircle.Visible = false
AssistFOVCircle.Radius = 150
AssistFOVCircle.Thickness = 1.5
AssistFOVCircle.Color = Color3.fromRGB(0, 200, 255) -- Cyan
AssistFOVCircle.Filled = false
AssistFOVCircle.Transparency = 0.5

-- Trigger Zone Circle (inner circle showing where assist activates)
local TriggerZoneCircle = Drawing.new("Circle")
TriggerZoneCircle.Visible = false
TriggerZoneCircle.Radius = 50
TriggerZoneCircle.Thickness = 1
TriggerZoneCircle.Color = Color3.fromRGB(0, 255, 150) -- Green
TriggerZoneCircle.Filled = false
TriggerZoneCircle.Transparency = 0.3

-- Register ke global untuk cleanup
table.insert(_G.EliteHub.Drawings, FOVCircle)
table.insert(_G.EliteHub.Drawings, AssistFOVCircle)
table.insert(_G.EliteHub.Drawings, TriggerZoneCircle)

-- Fungsi Helper (Biar otak lo gak meledak liat kode berantakan)
local function createTab(name, pos)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 35)
    btn.Position = UDim2.new(0.05, 0, 0, 10 + (pos * 40))
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 14
    btn.Parent = sidebar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end

-- Tabs
local aimBtn = createTab("AIMBOT", 0)
local espBtn = createTab("VISUALS", 1)
local charBtn = createTab("PLAYER", 2)

-- ==================== TAB PAGES ====================
local tabPages = {}

local function createTabPage(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = name
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.ScrollBarThickness = 4
    page.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.Parent = container
    
    local layout = Instance.new("UIListLayout", page)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    
    local padding = Instance.new("UIPadding", page)
    padding.PaddingTop = UDim.new(0, 5)
    padding.PaddingLeft = UDim.new(0, 5)
    padding.PaddingRight = UDim.new(0, 5)
    
    tabPages[name] = page
    return page
end

-- Create pages
local aimPage = createTabPage("AIMBOT")
local espPage = createTabPage("VISUALS")
local charPage = createTabPage("PLAYER")

-- Active tab tracking
local activeTab = nil

local function switchTab(tabName, button)
    -- Hide semua pages
    for _, page in pairs(tabPages) do
        page.Visible = false
    end
    
    -- Reset semua button colors
    for _, btn in pairs({aimBtn, espBtn, charBtn}) do
        btn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    end
    
    -- Show selected page
    if tabPages[tabName] then
        tabPages[tabName].Visible = true
    end
    
    -- Highlight active button
    button.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    
    activeTab = tabName
end

-- Connect tab buttons
aimBtn.MouseButton1Click:Connect(function() switchTab("AIMBOT", aimBtn) end)
espBtn.MouseButton1Click:Connect(function() switchTab("VISUALS", espBtn) end)
charBtn.MouseButton1Click:Connect(function() switchTab("PLAYER", charBtn) end)

-- Default: buka Aimbot tab
switchTab("AIMBOT", aimBtn)

-- ==================== UI ELEMENT HELPERS ====================
local function createLabel(parent, text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 0, 25)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(150, 150, 150)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = parent
    return label
end

local function createToggle(parent, text, defaultValue, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 35)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    
    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0, 45, 0, 22)
    toggle.Position = UDim2.new(1, -55, 0.5, -11)
    toggle.Text = defaultValue and "ON" or "OFF"
    toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggle.BackgroundColor3 = defaultValue and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(80, 80, 80)
    toggle.Font = Enum.Font.GothamBold
    toggle.TextSize = 11
    toggle.Parent = frame
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 6)
    
    local state = defaultValue
    toggle.MouseButton1Click:Connect(function()
        state = not state
        toggle.Text = state and "ON" or "OFF"
        toggle.BackgroundColor3 = state and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(80, 80, 80)
        if callback then callback(state) end
    end)
    
    return frame, toggle
end

local function createSlider(parent, text, min, max, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 50)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 0, 20)
    label.Position = UDim2.new(0, 10, 0, 5)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    
    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0.3, 0, 0, 20)
    valueLabel.Position = UDim2.new(0.7, -10, 0, 5)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = tostring(default)
    valueLabel.TextColor3 = Color3.fromRGB(0, 200, 100)
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextSize = 13
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = frame
    
    local sliderBg = Instance.new("Frame")
    sliderBg.Size = UDim2.new(1, -20, 0, 8)
    sliderBg.Position = UDim2.new(0, 10, 0, 32)
    sliderBg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    sliderBg.Parent = frame
    Instance.new("UICorner", sliderBg).CornerRadius = UDim.new(1, 0)
    
    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
    sliderFill.Parent = sliderBg
    Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(1, 0)
    
    local dragging = false
    
    sliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
        end
    end)
    
    sliderBg.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    UIS.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local relativePos = (input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X
            relativePos = math.clamp(relativePos, 0, 1)
            local value = math.floor(min + (max - min) * relativePos)
            sliderFill.Size = UDim2.new(relativePos, 0, 1, 0)
            valueLabel.Text = tostring(value)
            if callback then callback(value) end
        end
    end)
    
    return frame
end

-- Helper: Create Text Input
local function createTextInput(parent, text, placeholder, defaultValue, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 55)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 0, 20)
    label.Position = UDim2.new(0, 10, 0, 5)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    
    local textBox = Instance.new("TextBox")
    textBox.Size = UDim2.new(1, -20, 0, 24)
    textBox.Position = UDim2.new(0, 10, 0, 26)
    textBox.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    textBox.Text = defaultValue or ""
    textBox.PlaceholderText = placeholder or "Enter value..."
    textBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    textBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 100)
    textBox.Font = Enum.Font.Code
    textBox.TextSize = 11
    textBox.ClearTextOnFocus = false
    textBox.TextXAlignment = Enum.TextXAlignment.Left
    textBox.Parent = frame
    Instance.new("UICorner", textBox).CornerRadius = UDim.new(0, 4)
    
    local padding = Instance.new("UIPadding", textBox)
    padding.PaddingLeft = UDim.new(0, 6)
    
    textBox.FocusLost:Connect(function(enterPressed)
        if callback then callback(textBox.Text) end
    end)
    
    return frame, textBox
end

-- Target Part Options (mapping ke actual part names)
local TargetPartOptions = {
    { name = "Head", parts = {"Head"} },
    { name = "Neck", parts = {"Neck", "Head"} }, -- Fallback ke Head kalau Neck gak ada
    { name = "Body", parts = {"UpperTorso", "Torso", "HumanoidRootPart"} }, -- R15, R6, fallback
    { name = "Leg", parts = {"LeftUpperLeg", "Left Leg", "LeftFoot"} } -- R15, R6, fallback
}

-- Helper: Get actual part from option
local function getPartFromOption(character, optionName)
    for _, option in pairs(TargetPartOptions) do
        if option.name == optionName then
            for _, partName in pairs(option.parts) do
                local part = character:FindFirstChild(partName)
                if part then return part end
            end
        end
    end
    -- Fallback ke Head
    return character:FindFirstChild("Head")
end

-- Helper: Create Dropdown
local function createDropdown(parent, text, options, defaultValue, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 35)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    frame.ClipsDescendants = false
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.5, 0, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    
    local dropBtn = Instance.new("TextButton")
    dropBtn.Size = UDim2.new(0, 100, 0, 24)
    dropBtn.Position = UDim2.new(1, -110, 0.5, -12)
    dropBtn.Text = defaultValue or options[1]
    dropBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    dropBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
    dropBtn.Font = Enum.Font.GothamBold
    dropBtn.TextSize = 11
    dropBtn.Parent = frame
    Instance.new("UICorner", dropBtn).CornerRadius = UDim.new(0, 6)
    
    local dropList = Instance.new("Frame")
    dropList.Size = UDim2.new(0, 100, 0, #options * 26)
    dropList.Position = UDim2.new(1, -110, 1, 5)
    dropList.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    dropList.Visible = false
    dropList.ZIndex = 10
    dropList.Parent = frame
    Instance.new("UICorner", dropList).CornerRadius = UDim.new(0, 6)
    
    local listLayout = Instance.new("UIListLayout", dropList)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 2)
    
    local isOpen = false
    
    for i, option in pairs(options) do
        local optBtn = Instance.new("TextButton")
        optBtn.Size = UDim2.new(1, -4, 0, 24)
        optBtn.Position = UDim2.new(0, 2, 0, 0)
        optBtn.Text = option
        optBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        optBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
        optBtn.BackgroundTransparency = 0.5
        optBtn.Font = Enum.Font.Gotham
        optBtn.TextSize = 11
        optBtn.ZIndex = 11
        optBtn.Parent = dropList
        Instance.new("UICorner", optBtn).CornerRadius = UDim.new(0, 4)
        
        optBtn.MouseButton1Click:Connect(function()
            dropBtn.Text = option
            dropList.Visible = false
            isOpen = false
            if callback then callback(option) end
        end)
    end
    
    dropBtn.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        dropList.Visible = isOpen
    end)
    
    -- Close dropdown when clicking outside (simplified)
    UIS.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            task.wait(0.1)
            if isOpen then
                dropList.Visible = false
                isOpen = false
            end
        end
    end)
    
    return frame, dropBtn
end

local function createColorPalette(parent, text, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 65)
    frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    frame.BackgroundTransparency = 0.95
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 0, 20)
    label.Position = UDim2.new(0, 10, 0, 5)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    
    local colors = {
        Color3.fromRGB(255, 50, 50),   -- Red
        Color3.fromRGB(50, 255, 50),   -- Green
        Color3.fromRGB(50, 150, 255),  -- Blue
        Color3.fromRGB(255, 255, 50),  -- Yellow
        Color3.fromRGB(255, 50, 255),  -- Magenta
        Color3.fromRGB(50, 255, 255),  -- Cyan
        Color3.fromRGB(255, 255, 255), -- White
        Color3.fromRGB(255, 150, 0),   -- Orange
    }
    
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -20, 0, 30)
    container.Position = UDim2.new(0, 10, 0, 28)
    container.BackgroundTransparency = 1
    container.Parent = frame
    
    local layout = Instance.new("UIListLayout", container)
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.Padding = UDim.new(0, 6)
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    
    for _, color in pairs(colors) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 24, 0, 24)
        btn.BackgroundColor3 = color
        btn.Text = ""
        btn.Parent = container
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        
        btn.MouseButton1Click:Connect(function()
            if callback then callback(color) end
        end)
    end
    
    return frame
end

-- Helper: Get keybind display name
local function getKeybindName(keybind, keybindType)
    if keybindType == "Mouse" then
        if keybind == Enum.UserInputType.MouseButton1 then return "Left Click" end
        if keybind == Enum.UserInputType.MouseButton2 then return "Right Click" end
        if keybind == Enum.UserInputType.MouseButton3 then return "Middle Click" end
        return tostring(keybind.Name)
    else
        return tostring(keybind.Name)
    end
end

local function createKeybindPicker(parent, text, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 35)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.5, 0, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    
    local keybindBtn = Instance.new("TextButton")
    keybindBtn.Size = UDim2.new(0, 100, 0, 24)
    keybindBtn.Position = UDim2.new(1, -110, 0.5, -12)
    keybindBtn.Text = getKeybindName(Config.Aimbot.Keybind, Config.Aimbot.KeybindType)
    keybindBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    keybindBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    keybindBtn.Font = Enum.Font.GothamBold
    keybindBtn.TextSize = 11
    keybindBtn.Parent = frame
    Instance.new("UICorner", keybindBtn).CornerRadius = UDim.new(0, 6)
    
    local waiting = false
    
    keybindBtn.MouseButton1Click:Connect(function()
        if waiting then return end
        waiting = true
        isBindingKey = true
        keybindBtn.Text = "..."
        keybindBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 50)
        
        local connection
        connection = UIS.InputBegan:Connect(function(input, gpe)
            -- Skip kalau tombol escape (cancel)
            if input.KeyCode == Enum.KeyCode.Escape then
                keybindBtn.Text = getKeybindName(Config.Aimbot.Keybind, Config.Aimbot.KeybindType)
                keybindBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
                waiting = false
                isBindingKey = false
                connection:Disconnect()
                return
            end
            
            -- Mouse buttons
            if input.UserInputType == Enum.UserInputType.MouseButton1 or
               input.UserInputType == Enum.UserInputType.MouseButton2 or
               input.UserInputType == Enum.UserInputType.MouseButton3 then
                Config.Aimbot.Keybind = input.UserInputType
                Config.Aimbot.KeybindType = "Mouse"
                keybindBtn.Text = getKeybindName(input.UserInputType, "Mouse")
                keybindBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
                waiting = false
                isBindingKey = false
                connection:Disconnect()
                if callback then callback(input.UserInputType, "Mouse") end
                return
            end
            
            -- Keyboard keys
            if input.KeyCode ~= Enum.KeyCode.Unknown then
                Config.Aimbot.Keybind = input.KeyCode
                Config.Aimbot.KeybindType = "Keyboard"
                keybindBtn.Text = getKeybindName(input.KeyCode, "Keyboard")
                keybindBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
                waiting = false
                isBindingKey = false
                connection:Disconnect()
                if callback then callback(input.KeyCode, "Keyboard") end
                return
            end
        end)
    end)
    
    return frame, keybindBtn
end

-- ==================== POPULATE TAB PAGES ====================

-- AIMBOT PAGE
createLabel(aimPage, "🎯 Hard Aimbot (Hold Key)")
createToggle(aimPage, "Enable Aimbot", Config.Aimbot.Enabled, function(v) Config.Aimbot.Enabled = v end)
createSlider(aimPage, "Aimbot Strength %", 1, 100, Config.Aimbot.Strength, function(v) Config.Aimbot.Strength = v end)
createSlider(aimPage, "Aimbot FOV", 10, 500, Config.Aimbot.FOV, function(v) 
    Config.Aimbot.FOV = v 
    FOVCircle.Radius = v
end)
createDropdown(aimPage, "Aimbot Target", {"Head", "Neck", "Body", "Leg"}, Config.Aimbot.TargetPart, function(v)
    Config.Aimbot.TargetPart = v
    print("[Aimbot] Target set to:", v)
end)
createDropdown(aimPage, "Aimbot Method", {"Camera", "Cursor"}, Config.Aimbot.Method, function(v)
    Config.Aimbot.Method = v
end)
createToggle(aimPage, "Lock Target", Config.Aimbot.LockTarget, function(v) Config.Aimbot.LockTarget = v end)
createToggle(aimPage, "Show FOV Circle", Config.Aimbot.ShowFOV, function(v) 
    Config.Aimbot.ShowFOV = v 
    FOVCircle.Visible = v
end)

createLabel(aimPage, "📍 FOV Position Settings")
createDropdown(aimPage, "FOV Mode", {"Cursor", "Center", "Custom"}, Config.Aimbot.FOVMode, function(v)
    Config.Aimbot.FOVMode = v
    print("[Aimbot] FOV Mode set to:", v)
end)
createSlider(aimPage, "FOV Offset X", -500, 500, Config.Aimbot.FOVOffsetX, function(v) Config.Aimbot.FOVOffsetX = v end)
createSlider(aimPage, "FOV Offset Y", -500, 500, Config.Aimbot.FOVOffsetY, function(v) Config.Aimbot.FOVOffsetY = v end)
createToggle(aimPage, "Aim From FOV Point", Config.Aimbot.AimFromFOV, function(v) 
    Config.Aimbot.AimFromFOV = v 
    print("[Aimbot] Aim From FOV:", v and "ON" or "OFF")
end)

createLabel(aimPage, "🎮 Aim Assist (Soft/Subtle)")
createToggle(aimPage, "Enable Aim Assist", Config.AimAssist.Enabled, function(v) Config.AimAssist.Enabled = v end)
createToggle(aimPage, "Always Active", Config.AimAssist.AlwaysActive, function(v) Config.AimAssist.AlwaysActive = v end)
createToggle(aimPage, "Show Assist FOV", Config.AimAssist.ShowFOV, function(v) 
    Config.AimAssist.ShowFOV = v 
    AssistFOVCircle.Visible = v
    TriggerZoneCircle.Visible = v
end)
createSlider(aimPage, "Assist Strength %", 1, 100, Config.AimAssist.Strength, function(v) Config.AimAssist.Strength = v end)
createSlider(aimPage, "Assist FOV", 10, 300, Config.AimAssist.FOV, function(v) 
    Config.AimAssist.FOV = v 
    AssistFOVCircle.Radius = v
end)
createSlider(aimPage, "Trigger Zone", 10, 200, Config.AimAssist.TriggerZone, function(v) 
    Config.AimAssist.TriggerZone = v 
    TriggerZoneCircle.Radius = v
end)
createDropdown(aimPage, "Assist Target", {"Head", "Neck", "Body", "Leg"}, Config.AimAssist.TargetPart, function(v) 
    Config.AimAssist.TargetPart = v 
    print("[AimAssist] Target set to:", v)
end)
createDropdown(aimPage, "Assist Method", {"Camera", "Cursor"}, Config.AimAssist.Method, function(v)
    Config.AimAssist.Method = v
end)
createToggle(aimPage, "Require Mouse Movement", Config.AimAssist.RequireMovement, function(v) Config.AimAssist.RequireMovement = v end)

createLabel(aimPage, "⚙️ Shared Settings")
createToggle(aimPage, "Wall Check", Config.Aimbot.WallCheck, function(v) Config.Aimbot.WallCheck = v end)
createToggle(aimPage, "Team Check", Config.Aimbot.TeamCheck, function(v) Config.Aimbot.TeamCheck = v end)

createKeybindPicker(aimPage, "Aim Keybind", function(key, keyType)
    print("Keybind changed to:", key, keyType)
end)

-- Custom Path Settings (Aimbot)
createLabel(aimPage, "Custom Target (Advanced)")
createToggle(aimPage, "Use Custom Path", Config.Aimbot.UseCustomPath, function(v) Config.Aimbot.UseCustomPath = v end)
createTextInput(aimPage, "Custom Target Path", "Workspace.Folder.{PLAYER}.Head", Config.Aimbot.CustomPath, function(v)
    Config.Aimbot.CustomPath = v
    print("[Aimbot] Custom path set to:", v)
end)

-- VISUALS PAGE
createLabel(espPage, "ESP Master Control")
createToggle(espPage, "Enable ESP", Config.ESP.Enabled, function(v) Config.ESP.Enabled = v end)
createColorPalette(espPage, "🎨 ESP Color Palette", function(color)
    Config.ESP.MainColor = color
    print("[ESP] Main Color updated!")
end)

createLabel(espPage, "ESP Display Options")
createToggle(espPage, "📦 Box ESP", Config.ESP.Boxes, function(v) Config.ESP.Boxes = v end)
createDropdown(espPage, "Box Style", {"Corner", "Full"}, Config.ESP.BoxStyle, function(v) Config.ESP.BoxStyle = v end)
createToggle(espPage, "💀 Bone/Skeleton ESP", Config.ESP.Bones, function(v) Config.ESP.Bones = v end)
createToggle(espPage, "📛 Name Tags", Config.ESP.Names, function(v) Config.ESP.Names = v end)
createToggle(espPage, "❤️ Health Bar", Config.ESP.Health, function(v) Config.ESP.Health = v end)
createToggle(espPage, "📏 Distance Text", Config.ESP.DistanceText, function(v) Config.ESP.DistanceText = v end)
createToggle(espPage, "📍 Tracers", Config.ESP.Tracers, function(v) Config.ESP.Tracers = v end)
createToggle(espPage, "🎨 Team Colors", Config.ESP.TeamColor, function(v) Config.ESP.TeamColor = v end)
createToggle(espPage, "👥 Team Check (Hide Allies)", Config.ESP.TeamCheck, function(v) Config.ESP.TeamCheck = v end)

createLabel(espPage, "ESP Range")
createSlider(espPage, "Max Distance", 100, 2000, Config.ESP.Distance, function(v) Config.ESP.Distance = v end)

createLabel(espPage, "✨ Chams & Look Direction")
createToggle(espPage, "🌟 Chams", Config.ESP.Chams, function(v) Config.ESP.Chams = v end)
createDropdown(espPage, "Chams Depth", {"AlwaysOnTop", "Occluded"}, Config.ESP.ChamsDepthMode, function(v) 
    Config.ESP.ChamsDepthMode = v 
end)
createToggle(espPage, "👥 Chams Team Color", Config.ESP.ChamsTeamColor, function(v) Config.ESP.ChamsTeamColor = v end)
createSlider(espPage, "Chams Fill Opacity %", 0, 100, 50, function(v) Config.ESP.ChamsFillTransparency = 1 - (v/100) end)
createSlider(espPage, "Chams Outline Opacity %", 0, 100, 100, function(v) Config.ESP.ChamsOutlineTransparency = 1 - (v/100) end)
createTextInput(espPage, "Chams Color (RGB: r,g,b)", "255,0,0", "255,0,0", function(v)
    local r, g, b = v:match("(%d+),%s*(%d+),%s*(%d+)")
    if r and g and b then
        Config.ESP.ChamsColor = Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b))
    end
end)

createToggle(espPage, "👁️ Look Vector", Config.ESP.LookVector, function(v) Config.ESP.LookVector = v end)
createTextInput(espPage, "Look Vector Color (RGB)", "255,255,255", "255,255,255", function(v)
    local r, g, b = v:match("(%d+),%s*(%d+),%s*(%d+)")
    if r and g and b then
        Config.ESP.LookVectorColor = Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b))
    end
end)

-- Custom Path Settings (ESP)
createLabel(espPage, "Custom Target (Advanced)")
createToggle(espPage, "Use Custom Path", Config.ESP.UseCustomPath, function(v) Config.ESP.UseCustomPath = v end)
createTextInput(espPage, "Custom Target Path", "Workspace.Folder.{PLAYER}", Config.ESP.CustomPath, function(v)
    Config.ESP.CustomPath = v
    print("[ESP] Custom path set to:", v)
end)

-- PLAYER PAGE
createLabel(charPage, "Speed Modifications")
createToggle(charPage, "Enable Walk Speed", Config.Character.WalkSpeedEnabled, function(v) Config.Character.WalkSpeedEnabled = v end)
createSlider(charPage, "Walk Speed", 16, 500, Config.Character.WalkSpeed, function(v) Config.Character.WalkSpeed = v end)
createToggle(charPage, "Enable Jump Power", Config.Character.JumpPowerEnabled, function(v) Config.Character.JumpPowerEnabled = v end)
createSlider(charPage, "Jump Power", 50, 500, Config.Character.JumpPower, function(v) Config.Character.JumpPower = v end)

-- Helper: Wall Check (Raycast)
local function isVisible(targetPart)
    if not Config.Aimbot.WallCheck then return true end
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("Head") then return true end
    
    local origin = LocalPlayer.Character.Head.Position
    local direction = (targetPart.Position - origin)
    
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character}
    
    local result = workspace:Raycast(origin, direction, rayParams)
    
    if result then
        -- Cek apakah yang kena ray itu part dari target character
        local hitPart = result.Instance
        if hitPart:IsDescendantOf(targetPart.Parent) then
            return true
        end
        return false
    end
    return true
end

-- Helper: Team Check
local function isSameTeam(player)
    if not Config.Aimbot.TeamCheck then return false end
    if not LocalPlayer.Team or not player.Team then return false end
    return LocalPlayer.Team == player.Team
end

-- Logic Aimbot (Smooth & Configurable)
local function getClosestPlayer()
    local target, shortestDist = nil, math.huge
    local camera = workspace.CurrentCamera
    if not camera then return nil end
    
    -- Calculate FOV center based on mode
    local screenSize = camera.ViewportSize
    local screenCenter = Vector2.new(screenSize.X / 2, screenSize.Y / 2)
    local fovCenter
    
    if Config.Aimbot.FOVMode == "Center" then
        fovCenter = screenCenter
    elseif Config.Aimbot.FOVMode == "Custom" then
        fovCenter = screenCenter + Vector2.new(Config.Aimbot.FOVOffsetX, Config.Aimbot.FOVOffsetY)
    else -- "Cursor" (default)
        fovCenter = UIS:GetMouseLocation()
    end
    
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            -- Team Check
            if isSameTeam(p) then continue end
            
            -- Get target part (dengan support custom path)
            local targetPart = getTargetPart(p, Config.Aimbot)
            
            if targetPart then
                local pos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
                
                if onScreen then
                    local dist = (Vector2.new(pos.X, pos.Y) - fovCenter).Magnitude
                    if dist < Config.Aimbot.FOV and dist < shortestDist then
                        -- Wall Check
                        if isVisible(targetPart) then
                            target = targetPart
                            shortestDist = dist
                        end
                    end
                end
            end
        end
    end
    return target
end

-- Aimbot Keybind Handler (Support Mouse & Keyboard)
local aimKeyDownConn = UIS.InputBegan:Connect(function(input)
    if isBindingKey then return end -- Skip kalau lagi binding key
    
    if Config.Aimbot.KeybindType == "Mouse" then
        if input.UserInputType == Config.Aimbot.Keybind then
            isAiming = true
            currentLockedTarget = nil -- Reset locked target saat mulai aim baru
        end
    else
        if input.KeyCode == Config.Aimbot.Keybind then
            isAiming = true
            currentLockedTarget = nil -- Reset locked target saat mulai aim baru
        end
    end
end)
table.insert(_G.EliteHub.Connections, aimKeyDownConn)

local aimKeyUpConn = UIS.InputEnded:Connect(function(input)
    if Config.Aimbot.KeybindType == "Mouse" then
        if input.UserInputType == Config.Aimbot.Keybind then
            isAiming = false
            currentLockedTarget = nil -- Reset locked target saat lepas keybind
        end
    else
        if input.KeyCode == Config.Aimbot.Keybind then
            isAiming = false
            currentLockedTarget = nil -- Reset locked target saat lepas keybind
        end
    end
end)
table.insert(_G.EliteHub.Connections, aimKeyUpConn)

-- Throttle for Aim Assist
local lastAimAssistUpdate = 0
local AIM_ASSIST_RATE = 1/60 -- 60 FPS for aim assist (full speed)

local mainRenderConn = RunService.RenderStepped:Connect(function(dt)
    -- Wrap in pcall to prevent freezing on errors
    local success, err = pcall(function()
        local camera = workspace.CurrentCamera
        if not camera then return end
        
        local mousePos = UIS:GetMouseLocation()
        local screenSize = camera.ViewportSize
        local screenCenter = Vector2.new(screenSize.X / 2, screenSize.Y / 2)
    
    -- Calculate FOV position based on mode
    local fovPosition
    if Config.Aimbot.FOVMode == "Center" then
        fovPosition = screenCenter
    elseif Config.Aimbot.FOVMode == "Custom" then
        fovPosition = screenCenter + Vector2.new(Config.Aimbot.FOVOffsetX, Config.Aimbot.FOVOffsetY)
    else -- "Cursor" (default)
        fovPosition = mousePos
    end
    
    -- FOV Circle Update (Aimbot - white)
    if Config.Aimbot.ShowFOV then
        FOVCircle.Position = fovPosition
        FOVCircle.Radius = Config.Aimbot.FOV
        FOVCircle.Visible = true
    else
        FOVCircle.Visible = false
    end
    
    -- Aim Assist FOV Circles (cyan outer + green inner)
    if Config.AimAssist.ShowFOV and Config.AimAssist.Enabled then
        AssistFOVCircle.Position = fovPosition
        AssistFOVCircle.Radius = Config.AimAssist.FOV
        AssistFOVCircle.Visible = true
        
        TriggerZoneCircle.Position = fovPosition
        TriggerZoneCircle.Radius = Config.AimAssist.TriggerZone
        TriggerZoneCircle.Visible = true
    else
        AssistFOVCircle.Visible = false
        TriggerZoneCircle.Visible = false
    end
    
    -- Aimbot Logic (HOLD keybind untuk aim)
    if Config.Aimbot.Enabled and isAiming then
        local target = nil
        
        -- Lock Target Logic
        if Config.Aimbot.LockTarget and currentLockedTarget then
            -- Validasi apakah locked target masih valid
            local lockedPlayer = currentLockedTarget.Parent and currentLockedTarget.Parent.Parent
            if lockedPlayer and lockedPlayer:IsA("Player") == false then
                lockedPlayer = Players:GetPlayerFromCharacter(currentLockedTarget.Parent)
            end
            
            if currentLockedTarget and currentLockedTarget.Parent then
                -- Cek apakah character masih ada dan target part masih ada
                local char = currentLockedTarget.Parent
                if char and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
                    target = currentLockedTarget
                else
                    -- Target mati/invalid, reset
                    currentLockedTarget = nil
                    target = getClosestPlayer()
                    if target then currentLockedTarget = target end
                end
            else
                -- Target gak valid, cari baru
                currentLockedTarget = nil
                target = getClosestPlayer()
                if target then currentLockedTarget = target end
            end
        else
            -- Normal mode: cari target terdekat tiap frame
            target = getClosestPlayer()
            
            -- Kalau Lock Target ON dan belum ada locked target, set sekarang
            if Config.Aimbot.LockTarget and target and not currentLockedTarget then
                currentLockedTarget = target
            end
        end
        
        if target then
            if Config.Aimbot.Method == "Camera" then
                local camera = workspace.CurrentCamera
                local camPos = camera.CFrame.Position
                local targetPos = target.Position
                
                -- Calculate aim target based on AimFromFOV setting
                local aimTarget = targetPos
                
                if Config.Aimbot.AimFromFOV and Config.Aimbot.FOVMode ~= "Cursor" then
                    -- Aim FROM FOV position instead of center
                    -- This offsets the aim point by the FOV offset
                    local screenSize = camera.ViewportSize
                    local screenCenter = Vector2.new(screenSize.X / 2, screenSize.Y / 2)
                    
                    local offsetX = 0
                    local offsetY = 0
                    
                    if Config.Aimbot.FOVMode == "Custom" then
                        offsetX = Config.Aimbot.FOVOffsetX
                        offsetY = Config.Aimbot.FOVOffsetY
                    end
                    
                    -- Convert screen offset to world offset
                    -- This creates a "lead" or offset in the aim
                    local depth = (targetPos - camPos).Magnitude
                    local fovRad = math.rad(camera.FieldOfView / 2)
                    local screenToWorld = (depth * math.tan(fovRad)) / (screenSize.Y / 2)
                    
                    local rightVector = camera.CFrame.RightVector
                    local upVector = camera.CFrame.UpVector
                    
                    -- Apply inverse offset (aim so FOV point hits target)
                    aimTarget = targetPos - (rightVector * offsetX * screenToWorld) - (upVector * -offsetY * screenToWorld)
                end
                
                -- Aimbot with percentage strength
                local strength = Config.Aimbot.Strength / 100 -- Convert to 0-1
                
                if Config.Aimbot.Method == "Camera" then
                    local currentLook = camera.CFrame.LookVector
                    local targetLook = (aimTarget - camPos).Unit
                    local smoothedLook = currentLook:Lerp(targetLook, strength)
                    camera.CFrame = CFrame.new(camPos, camPos + smoothedLook)
                elseif Config.Aimbot.Method == "Cursor" then
                    local screenPos, onScreen = camera:WorldToViewportPoint(aimTarget)
                    if onScreen then
                        local mouseLoc = UIS:GetMouseLocation()
                        local distX = (screenPos.X - mouseLoc.X) * strength
                        local distY = (screenPos.Y - mouseLoc.Y) * strength
                        
                        -- Use mousemoverel if available
                        if mousemoverel then
                            mousemoverel(distX, distY)
                        end
                    end
                end
            end
        end
    else
        -- Kalau gak aiming, reset locked target
        if not isAiming then
            currentLockedTarget = nil
        end
    end
    
    -- Aim Assist Logic (soft assist) - THROTTLED for performance
    -- AlwaysActive = true: works all the time
    -- AlwaysActive = false: only works when NOT holding aimbot keybind (complementary)
    lastAimAssistUpdate = lastAimAssistUpdate + (dt or 0.016)
    local shouldRunAssist = lastAimAssistUpdate >= AIM_ASSIST_RATE
    local shouldAssist = Config.AimAssist.Enabled and (Config.AimAssist.AlwaysActive or not isAiming)
    
    if shouldAssist and shouldRunAssist then
        lastAimAssistUpdate = 0 -- Reset throttle
        local camera = workspace.CurrentCamera
        if not camera then return end -- Early exit if no camera
        
        -- Calculate FOV center based on mode (same as aimbot)
        local screenSize = camera.ViewportSize
        local screenCenter = Vector2.new(screenSize.X / 2, screenSize.Y / 2)
        local fovCenter
        
        if Config.Aimbot.FOVMode == "Center" then
            fovCenter = screenCenter
        elseif Config.Aimbot.FOVMode == "Custom" then
            fovCenter = screenCenter + Vector2.new(Config.Aimbot.FOVOffsetX, Config.Aimbot.FOVOffsetY)
        else -- "Cursor" (default)
            fovCenter = UIS:GetMouseLocation()
        end
        
        -- Find closest player within assist FOV
        local closestTarget = nil
        local closestDist = Config.AimAssist.FOV
        
        for _, player in pairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end
            if not player.Character then continue end
            
            local character = player.Character
            local humanoid = character:FindFirstChild("Humanoid")
            if not humanoid or humanoid.Health <= 0 then continue end
            
            -- Team check
            if Config.Aimbot.TeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
                continue
            end
            
            -- Get target part based on AimAssist setting
            local targetPart = getPartFromOption(character, Config.AimAssist.TargetPart)
            if not targetPart then continue end
            
            -- Wall check
            if Config.Aimbot.WallCheck then
                if not isVisible(targetPart) then continue end
            end
            
            local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
            if not onScreen then continue end
            
            local distToCenter = (Vector2.new(screenPos.X, screenPos.Y) - fovCenter).Magnitude
            
            if distToCenter < closestDist then
                closestDist = distToCenter
                closestTarget = targetPart
            end
        end
        
        -- Apply aim assist only when crosshair is near target (trigger zone)
        if closestTarget and closestDist <= Config.AimAssist.TriggerZone then
            local camPos = camera.CFrame.Position
            local targetPos = closestTarget.Position
            
            -- Soft assist - very subtle pull
            -- Soft assist - very subtle pull
            local strength = (Config.AimAssist.Strength / 100) * 0.3 -- Max 30% of the already low percentage
            
            if Config.AimAssist.Method == "Camera" then
                local currentLook = camera.CFrame.LookVector
                local targetLook = (targetPos - camPos).Unit
                local assistedLook = currentLook:Lerp(targetLook, strength)
                camera.CFrame = CFrame.new(camPos, camPos + assistedLook)
            elseif Config.AimAssist.Method == "Cursor" then
                local screenPos, onScreen = camera:WorldToViewportPoint(targetPos)
                if onScreen then
                    local mouseLoc = UIS:GetMouseLocation()
                    local distX = (screenPos.X - mouseLoc.X) * strength
                    local distY = (screenPos.Y - mouseLoc.Y) * strength
                    
                    if mousemoverel then
                        mousemoverel(distX, distY)
                    end
                end
            end
        end
    end
    
    -- Character Hacks (only when toggle enabled)
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        local humanoid = LocalPlayer.Character.Humanoid
        
        -- WalkSpeed (only apply when enabled)
        if Config.Character.WalkSpeedEnabled then
            humanoid.WalkSpeed = Config.Character.WalkSpeed
        end
        
        -- JumpPower (only apply when enabled)
        if Config.Character.JumpPowerEnabled then
            humanoid.JumpPower = Config.Character.JumpPower
        end
    end
    end) -- End pcall
    
    -- Error handling (silent to prevent spam)
    if not success and err then
        -- Uncomment for debugging: warn("[EliteHub] Error:", err)
    end
end)
table.insert(_G.EliteHub.Connections, mainRenderConn)

-- Toggle UI (Keybind RightShift) - HAPUS processed check karena RightShift sering dianggap processed
local toggleUIConn = UIS.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.RightShift then
        main.Visible = not main.Visible
    end
end)
table.insert(_G.EliteHub.Connections, toggleUIConn)

--[[ 
    ==================== ESP BONE SYSTEM ====================
    Support R15 dan R6 rig. Pake Drawing API biar smooth.
]]

-- Bone Connections (R15)
local R15Bones = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"}
}

-- Bone Connections (R6) 
local R6Bones = {
    {"Head", "Torso"},
    {"Torso", "Left Arm"},
    {"Torso", "Right Arm"},
    {"Torso", "Left Leg"},
    {"Torso", "Right Leg"}
}

-- Storage buat Drawing objects per player
local ESPCache = {}

-- Helper: World to Screen
local function worldToScreen(pos)
    local screenPos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(pos)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen, screenPos.Z
end

-- Helper: Detect rig type
local function getRigType(character)
    if character:FindFirstChild("UpperTorso") then
        return "R15"
    elseif character:FindFirstChild("Torso") then
        return "R6"
    end
    return nil
end

-- Create ESP drawings untuk 1 player
local function createESP(player)
    if player == LocalPlayer then return end
    if ESPCache[player] then return end
    
    ESPCache[player] = {
        bones = {},
        box = nil
    }
    
    -- Pre-create bone lines (max 14 buat R15)
    for i = 1, 14 do
        local line = Drawing.new("Line")
        line.Visible = false
        line.Color = Color3.fromRGB(255, 255, 255)
        line.Thickness = 1.5
        line.Transparency = 1
        table.insert(ESPCache[player].bones, line)
    end
    -- Pastikan cached objects selalu fresh
    if player.Character then
        local highlight = ESPCache[player].highlight
        if highlight and not highlight.Parent then
             -- Re-init highlight logic handled in update loop
        end
    end
    
    -- Box ESP (Full box)
    local box = Drawing.new("Square")
    box.Visible = false
    box.Color = Color3.fromRGB(255, 0, 0)
    box.Thickness = 1
    box.Filled = false
    ESPCache[player].box = box
    
    -- Corner Box (8 lines untuk corner style)
    ESPCache[player].corners = {}
    for i = 1, 8 do
        local corner = Drawing.new("Line")
        corner.Visible = false
        corner.Color = Color3.fromRGB(255, 50, 50)
        corner.Thickness = 2
        table.insert(ESPCache[player].corners, corner)
    end
    
    -- Name Tag
    local nameText = Drawing.new("Text")
    nameText.Visible = false
    nameText.Color = Color3.fromRGB(255, 255, 255)
    nameText.Size = 14
    nameText.Center = true
    nameText.Outline = true
    nameText.OutlineColor = Color3.fromRGB(0, 0, 0)
    nameText.Font = 2 -- UI
    ESPCache[player].name = nameText
    
    -- Distance Text
    local distText = Drawing.new("Text")
    distText.Visible = false
    distText.Color = Color3.fromRGB(200, 200, 200)
    distText.Size = 12
    distText.Center = true
    distText.Outline = true
    distText.OutlineColor = Color3.fromRGB(0, 0, 0)
    distText.Font = 2
    ESPCache[player].distance = distText
    
    -- Health Bar Background
    local healthBg = Drawing.new("Square")
    healthBg.Visible = false
    healthBg.Color = Color3.fromRGB(30, 30, 30)
    healthBg.Thickness = 1
    healthBg.Filled = true
    ESPCache[player].healthBg = healthBg
    
    -- Health Bar Fill
    local healthBar = Drawing.new("Square")
    healthBar.Visible = false
    healthBar.Color = Color3.fromRGB(0, 255, 0)
    healthBar.Thickness = 1
    healthBar.Filled = true
    ESPCache[player].healthBar = healthBar
    
    -- Tracer Line
    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Color = Color3.fromRGB(255, 100, 100)
    tracer.Thickness = 1
    ESPCache[player].tracer = tracer

    -- Look Vector Line
    local lookLine = Drawing.new("Line")
    lookLine.Visible = false
    lookLine.Color = Color3.fromRGB(255, 255, 255)
    lookLine.Thickness = 2
    ESPCache[player].lookVector = lookLine

    -- Chams (Highlight)
    local highlight = Instance.new("Highlight")
    highlight.Name = "EliteHub_Cham"
    highlight.Enabled = false
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    ESPCache[player].highlight = highlight
end

-- Remove ESP drawings
local function removeESP(player)
    if not ESPCache[player] then return end
    
    for _, line in pairs(ESPCache[player].bones) do
        line:Remove()
    end
    if ESPCache[player].box then
        ESPCache[player].box:Remove()
    end
    if ESPCache[player].corners then
        for _, corner in pairs(ESPCache[player].corners) do
            corner:Remove()
        end
    end
    if ESPCache[player].name then
        ESPCache[player].name:Remove()
    end
    if ESPCache[player].distance then
        ESPCache[player].distance:Remove()
    end
    if ESPCache[player].healthBg then
        ESPCache[player].healthBg:Remove()
    end
    if ESPCache[player].healthBar then
        ESPCache[player].healthBar:Remove()
    end
    if ESPCache[player].tracer then
        ESPCache[player].tracer:Remove()
    end
    if ESPCache[player].lookVector then
        ESPCache[player].lookVector:Remove()
    end
    if ESPCache[player].highlight then
        ESPCache[player].highlight:Destroy()
    end
    ESPCache[player] = nil
end

-- Performance: ESP update rate
local lastESPUpdate = 0
local ESP_UPDATE_RATE = 0 -- Set ke 0 biar jalan tiap frame (60 FPS)

-- BATCHED ESP UPDATE SYSTEM (Pro technique)
local espBatchIndex = 0
local ESP_PLAYERS_PER_BATCH = 100 -- Process semua player per frame buat 60 FPS murni

-- Hide a single player's ESP
local function hidePlayerESP(cache)
    if not cache then return end
    for _, line in pairs(cache.bones or {}) do line.Visible = false end
    if cache.box then cache.box.Visible = false end
    if cache.corners then
        for _, corner in pairs(cache.corners) do corner.Visible = false end
    end
    if cache.name then cache.name.Visible = false end
    if cache.distance then cache.distance.Visible = false end
    if cache.healthBg then cache.healthBg.Visible = false end
    if cache.healthBar then cache.healthBar.Visible = false end
    if cache.tracer then cache.tracer.Visible = false end
    if cache.lookVector then cache.lookVector.Visible = false end
    if cache.highlight then cache.highlight.Enabled = false end
end

-- Update single player ESP (optimized)
local function updateSinglePlayerESP(player, localHRP, camera)
    if player == LocalPlayer then return end
    
    local character = player.Character
    local cache = ESPCache[player]
    
    if not cache then
        createESP(player)
        cache = ESPCache[player]
    end
    
    if not cache then return end
    
    -- EARLY EXIT: Check character exists
    if not character then
        hidePlayerESP(cache)
        return
    end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")
    if not hrp or not humanoid then
        hidePlayerESP(cache)
        return
    end
    
    -- [[ 1. CHAMS LOGIC (Independent) ]]
    if Config.ESP.Chams and cache.highlight then
        -- Refresh Highlight jika hancur (akibat parent sebelumnya didestroy)
        if not cache.highlight.Parent then
            cache.highlight = Instance.new("Highlight")
            cache.highlight.Name = "EliteHub_Cham"
            ESPCache[player].highlight = cache.highlight
        end
        
        -- Parent ke GUI biar gak ikut kehapus pas character mati
        -- Gunakan Adornee untuk tempel efek ke character
        if _G.EliteHub.GUI and cache.highlight.Parent ~= _G.EliteHub.GUI then
            cache.highlight.Parent = _G.EliteHub.GUI
        end
        
        cache.highlight.Adornee = character
        cache.highlight.Enabled = true
        cache.highlight.DepthMode = Enum.HighlightDepthMode[Config.ESP.ChamsDepthMode]
        
        local chamColor = Config.ESP.ChamsColor
        if Config.ESP.ChamsTeamColor and player.Team then
            chamColor = player.TeamColor.Color
        end
        cache.highlight.FillColor = chamColor
        cache.highlight.FillTransparency = Config.ESP.ChamsFillTransparency
        cache.highlight.OutlineTransparency = Config.ESP.ChamsOutlineTransparency
    else
        if cache.highlight then cache.highlight.Enabled = false end
    end

    -- [[ 2. DRAWING PRE-CHECKS ]]
    local dist = (hrp.Position - localHRP.Position).Magnitude
    if dist > Config.ESP.Distance or (Config.ESP.TeamCheck and player.Team == LocalPlayer.Team) then
        -- Simpan state Chams tapi hapus 2D
        local chamsOn = cache.highlight and cache.highlight.Enabled
        hidePlayerESP(cache)
        if cache.highlight then cache.highlight.Enabled = chamsOn end
        return
    end
    
    local head = character:FindFirstChild("Head")
    if not head then return end

    local headPos, headOnScreen = worldToScreen(head.Position + Vector3.new(0, 0.5, 0))
    local feetPos, feetOnScreen = worldToScreen(hrp.Position - Vector3.new(0, 3, 0))
    
    -- Kalo off-screen, hide drawings aja tapi Chams tetep biarin
    if not headOnScreen and not feetOnScreen then
        if cache.box then cache.box.Visible = false end
        if cache.name then cache.name.Visible = false end
        if cache.distance then cache.distance.Visible = false end
        if cache.healthBg then cache.healthBg.Visible = false end
        if cache.healthBar then cache.healthBar.Visible = false end
        if cache.tracer then cache.tracer.Visible = false end
        if cache.lookVector then cache.lookVector.Visible = false end
        if cache.corners then for _, c in pairs(cache.corners) do c.Visible = false end end
        if cache.bones then for _, b in pairs(cache.bones) do b.Visible = false end end
        return
    end
    
    -- [[ 3. 2D DRAWING LOGIC ]]
    local height = math.abs(feetPos.Y - headPos.Y)
    local width = height / 2
    local boxX = headPos.X - width/2
    local boxY = headPos.Y
    
    local espColor = (Config.ESP.TeamColor and player.Team) and player.TeamColor.Color or Config.ESP.MainColor
    
    -- Bones
    if Config.ESP.Bones and cache.bones then
        local rigType = getRigType(character)
        local bones = rigType == "R15" and R15Bones or R6Bones
        for i, connection in pairs(bones) do
            local p1, p2 = character:FindFirstChild(connection[1]), character:FindFirstChild(connection[2])
            if p1 and p2 and cache.bones[i] then
                local pos1, onScreen1 = worldToScreen(p1.Position)
                local pos2, onScreen2 = worldToScreen(p2.Position)
                if onScreen1 and onScreen2 then
                    cache.bones[i].From, cache.bones[i].To = pos1, pos2
                    cache.bones[i].Visible, cache.bones[i].Color = true, Color3.fromRGB(0, 255, 150)
                else cache.bones[i].Visible = false end
            end
        end
    else
        if cache.bones then for _, b in pairs(cache.bones) do b.Visible = false end end
    end
    
    -- Box
    if Config.ESP.Boxes then
        if Config.ESP.BoxStyle == "Corner" and cache.corners then
            if cache.box then cache.box.Visible = false end
            local cornerSize = math.max(8, height / 6)
            local c = cache.corners
            c[1].From, c[1].To = Vector2.new(boxX, boxY), Vector2.new(boxX + cornerSize, boxY)
            c[2].From, c[2].To = Vector2.new(boxX, boxY), Vector2.new(boxX, boxY + cornerSize)
            c[3].From, c[3].To = Vector2.new(boxX + width, boxY), Vector2.new(boxX + width - cornerSize, boxY)
            c[4].From, c[4].To = Vector2.new(boxX + width, boxY), Vector2.new(boxX + width, boxY + cornerSize)
            c[5].From, c[5].To = Vector2.new(boxX, boxY + height), Vector2.new(boxX + cornerSize, boxY + height)
            c[6].From, c[6].To = Vector2.new(boxX, boxY + height), Vector2.new(boxX, boxY + height - cornerSize)
            c[7].From, c[7].To = Vector2.new(boxX + width, boxY + height), Vector2.new(boxX + width - cornerSize, boxY + height)
            c[8].From, c[8].To = Vector2.new(boxX + width, boxY + height), Vector2.new(boxX + width, boxY + height - cornerSize)
            for _, v in pairs(c) do v.Visible, v.Color = true, espColor end
        elseif cache.box then
            if cache.corners then for _, v in pairs(cache.corners) do v.Visible = false end end
            cache.box.Size, cache.box.Position = Vector2.new(width, height), Vector2.new(boxX, boxY)
            cache.box.Visible, cache.box.Color = true, espColor
        end
    else
        if cache.box then cache.box.Visible = false end
        if cache.corners then for _, v in pairs(cache.corners) do v.Visible = false end end
    end
    
    -- Name & Distance
    if Config.ESP.Names and cache.name then
        cache.name.Text, cache.name.Position, cache.name.Visible = player.DisplayName, Vector2.new(headPos.X, boxY - 18), true
    else
        if cache.name then cache.name.Visible = false end
    end
    
    if Config.ESP.DistanceText and cache.distance then
        cache.distance.Text, cache.distance.Position, cache.distance.Visible = string.format("[%dm]", math.floor(dist)), Vector2.new(headPos.X, boxY + height + 2), true
    else
        if cache.distance then cache.distance.Visible = false end
    end
    
    -- Health Bar
    if Config.ESP.Health and humanoid and cache.healthBg and cache.healthBar then
        local hp, max = humanoid.Health or 0, humanoid.MaxHealth or 100
        local pct = math.clamp(hp / max, 0, 1)
        local bW, bX = 4, boxX - 7
        cache.healthBg.Position, cache.healthBg.Size, cache.healthBg.Visible = Vector2.new(bX, boxY), Vector2.new(bW, height), true
        cache.healthBar.Position, cache.healthBar.Size, cache.healthBar.Visible = Vector2.new(bX, boxY + height - (height * pct)), Vector2.new(bW, height * pct), true
        cache.healthBar.Color = pct > 0.6 and Color3.fromRGB(0, 255, 100) or (pct > 0.3 and Color3.fromRGB(255, 200, 0) or Color3.fromRGB(255, 50, 50))
    else
        if cache.healthBg then cache.healthBg.Visible = false end
        if cache.healthBar then cache.healthBar.Visible = false end
    end
    
    -- Tracers
    if Config.ESP.Tracers and cache.tracer then
        local sC = camera.ViewportSize
        cache.tracer.From, cache.tracer.To = Vector2.new(sC.X / 2, sC.Y), Vector2.new(headPos.X, boxY + height)
        cache.tracer.Visible, cache.tracer.Color = true, espColor
    else
        if cache.tracer then cache.tracer.Visible = false end
    end

    -- Look Vector
    if Config.ESP.LookVector and cache.lookVector then
        local lPos, lOn = worldToScreen(head.Position + (head.CFrame.LookVector * 7))
        if headOnScreen and lOn then
            cache.lookVector.From, cache.lookVector.To, cache.lookVector.Visible, cache.lookVector.Color = headPos, lPos, true, Config.ESP.LookVectorColor
        else cache.lookVector.Visible = false end
    else
        if cache.lookVector then cache.lookVector.Visible = false end
    end
end

-- BATCHED updateESP function (main entry point)
local function updateESP()
    -- Early exit if ESP disabled
    if not Config.ESP.Enabled then
        for _, cache in pairs(ESPCache) do
            hidePlayerESP(cache)
        end
        return
    end
    
    -- Safe check for LocalPlayer Character (use Camera focus as fallback if dead)
    local localHRP = nil
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        localHRP = LocalPlayer.Character.HumanoidRootPart
    else
        -- Fallback: Use Camera CFrame if player is dead/spawning
        localHRP = { Position = workspace.CurrentCamera.CFrame.Position }
    end
    local camera = workspace.CurrentCamera
    local players = Players:GetPlayers()
    local playerCount = #players
    
    if playerCount == 0 then return end
    
    -- BATCHED: Only process ESP_PLAYERS_PER_BATCH players per frame
    local startIdx = (espBatchIndex * ESP_PLAYERS_PER_BATCH) + 1
    local endIdx = math.min(startIdx + ESP_PLAYERS_PER_BATCH - 1, playerCount)
    
    for i = startIdx, endIdx do
        local player = players[i]
        if player then
            -- Wrap individual player update in pcall to isolate errors
            task.spawn(function()
                pcall(updateSinglePlayerESP, player, localHRP, camera)
            end)
        end
    end
    
    -- Move to next batch
    espBatchIndex = (espBatchIndex + 1) % math.ceil(playerCount / ESP_PLAYERS_PER_BATCH)
end

-- Cleanup saat player leave
local playerRemovingConn = Players.PlayerRemoving:Connect(function(player)
    removeESP(player)
end)
table.insert(_G.EliteHub.Connections, playerRemovingConn)

-- Player Event Monitors
local function monitorPlayer(player)
    createESP(player)
    
    local charConn = player.CharacterAdded:Connect(function(char)
        createESP(player) -- Ensure ESP exists
        -- Highlight auto-fix logic is in updateSinglePlayerESP
    end)
    table.insert(_G.EliteHub.Connections, charConn)
end

-- Init existing players
for _, player in pairs(Players:GetPlayers()) do
    monitorPlayer(player)
end

-- Player joining
local playerAddedConn = Players.PlayerAdded:Connect(function(player)
    monitorPlayer(player)
end)
table.insert(_G.EliteHub.Connections, playerAddedConn)

-- Hook ke Heartbeat (Jalan tiap frame)
local espRenderConn = RunService.Heartbeat:Connect(function(dt)
    -- Jalan 60x per detik (60 FPS)
    lastESPUpdate = lastESPUpdate + dt
    if lastESPUpdate >= ESP_UPDATE_RATE then
        lastESPUpdate = 0
        pcall(updateESP)
    end
end)
table.insert(_G.EliteHub.Connections, espRenderConn)

-- Register ESP cache untuk cleanup
_G.EliteHub.ESPCache = ESPCache

-- Function untuk cleanup semua ESP (dipanggil saat re-execute)
local function removeAllESP()
    for player, cache in pairs(ESPCache) do
        for _, line in pairs(cache.bones) do
            line:Remove()
        end
        if cache.box then
            cache.box:Remove()
        end
        if cache.lookVector then
            cache.lookVector:Remove()
        end
        if cache.highlight then
            cache.highlight:Destroy()
        end
    end
    ESPCache = {}
end
_G.EliteHub.CleanupESP = removeAllESP

--[[ 
    ==================== CARA PAKE ====================
    1. Set Config.ESP.Enabled = true
    2. Set Config.ESP.Bones = true buat skeleton
    3. Set Config.ESP.Boxes = true buat box 2D
    4. Adjust Config.ESP.Distance buat max render distance
    
    CATATAN: Ini pake Drawing API, jadi CUMA JALAN DI EXECUTOR yang support Drawing.
    Kalo error "Drawing is not a valid member", executor lo SAMPAH. Ganti.
]]

print("[EliteHub] Script loaded! Press RightShift to toggle GUI.")
