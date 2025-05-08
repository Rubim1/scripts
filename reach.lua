--[[
    Reach Modifier Script for Roblox Universal Swords and Tools
    
    This script creates a GUI that allows players to modify the reach of their equipped tools/swords
    by adjusting position offsets (X, Y, Z) and size parameters.
    
    Place this script in StarterPlayerScripts or StarterGui to ensure it runs for each player.
]]

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- Variables
local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local ModifyingEnabled = false
local CurrentTool = nil
local OriginalGripData = {}
local VisibleReachMode = false -- New variable to control if the tool visually changes size
local Settings = {
    XOffset = 0,
    YOffset = 0,
    ZOffset = 0,
    XSize = 1,
    YSize = 1,
    ZSize = 1,
    Size = 1
}

-- Visualizer variables
local HitboxVisualizer = nil
local VisualizerEnabled = false
local VisualizerSettings = {
    Color = Color3.fromRGB(255, 0, 0), -- Red by default
    Transparency = 0.8,               -- 80% transparent
    Style = "Full"                    -- "Full", "Outline", or "Wireframe"
}

-- Flag to remember visualizer state when weapons are switched
local VisualizeOnEquip = false

-- Constants
local MIN_OFFSET = -1000
local MAX_OFFSET = 1000
local MIN_SIZE = 0.1
local MAX_SIZE = 1000
local DEFAULT_SETTINGS = {
    XOffset = 0,
    YOffset = 0,
    ZOffset = 0,
    XSize = 1,
    YSize = 1,
    ZSize = 1,
    Size = 1
}

-- Presets
local PRESETS = {
    Default = {XOffset = 0, YOffset = 0, ZOffset = 0, XSize = 1, YSize = 1, ZSize = 1, Size = 1},
    LongReach = {XOffset = 0, YOffset = 0, ZOffset = 5, XSize = 1, YSize = 1, ZSize = 2, Size = 1.5},
    MegaReach = {XOffset = 0, YOffset = 0, ZOffset = 8, XSize = 1.5, YSize = 1.5, ZSize = 3, Size = 2},
    Wide = {XOffset = 5, YOffset = 0, ZOffset = 0, XSize = 2, YSize = 1, ZSize = 1, Size = 2}
}

-- Function to update slider UI
function UpdateSliderUI(slider, valueBox, label, displayName, value, minVal, maxVal)
    local relativeX = (value - minVal) / (maxVal - minVal)
    slider.Position = UDim2.new(relativeX, -5, 0, -5)
    
    local fillBar = slider.Parent:FindFirstChild("SliderFill")
    if fillBar then
        fillBar.Size = UDim2.new(relativeX, 0, 1, 0)
    end
    
    valueBox.Text = tostring(value)
    label.Text = displayName .. ": " .. tostring(value)
end

-- Store the original tool properties
function StoreToolOriginalProperties(tool)
    if not tool then return end
    
    -- Reset OriginalGripData to avoid keeping old data
    OriginalGripData = {}
    
    -- Store the original grip properties
    OriginalGripData.GripPos = tool:FindFirstChild("GripPos") and tool.GripPos.Value or nil
    OriginalGripData.GripForward = tool:FindFirstChild("GripForward") and tool.GripForward.Value or nil
    OriginalGripData.GripRight = tool:FindFirstChild("GripRight") and tool.GripRight.Value or nil
    OriginalGripData.GripUp = tool:FindFirstChild("GripUp") and tool.GripUp.Value or nil
    
    -- Store handle size if it exists
    local handle = tool:FindFirstChild("Handle")
    if handle and handle:IsA("BasePart") then
        OriginalGripData.HandleSize = handle.Size
    end
end

-- Restore tool's original properties
function RestoreToolOriginalProperties()
    if not CurrentTool or not OriginalGripData then return end
    
    -- Restore grip position
    if OriginalGripData.GripPos then
        local gripPos = CurrentTool:FindFirstChild("GripPos")
        if gripPos and gripPos:IsA("Vector3Value") then
            gripPos.Value = OriginalGripData.GripPos
        end
    end
    
    -- Restore grip orientations
    if OriginalGripData.GripForward then
        local gripForward = CurrentTool:FindFirstChild("GripForward")
        if gripForward and gripForward:IsA("Vector3Value") then
            gripForward.Value = OriginalGripData.GripForward
        end
    end
    
    if OriginalGripData.GripRight then
        local gripRight = CurrentTool:FindFirstChild("GripRight")
        if gripRight and gripRight:IsA("Vector3Value") then
            gripRight.Value = OriginalGripData.GripRight
        end
    end
    
    if OriginalGripData.GripUp then
        local gripUp = CurrentTool:FindFirstChild("GripUp")
        if gripUp and gripUp:IsA("Vector3Value") then
            gripUp.Value = OriginalGripData.GripUp
        end
    end
    
    -- Remove the invisible hitbox when disabling
    local hitbox = CurrentTool:FindFirstChild("ReachModifierHitbox")
    if hitbox then
        hitbox:Destroy()
    end
    
    -- Make sure the handle size is restored to original
    local handle = CurrentTool:FindFirstChild("Handle")
    if handle and handle:IsA("BasePart") and OriginalGripData.HandleSize then
        handle.Size = OriginalGripData.HandleSize
    end
    
    -- Remove visualizer instance, but don't reset visualizer state flags
    -- so we can restore the visualizer when a new tool is equipped
    if HitboxVisualizer then
        HitboxVisualizer:Destroy()
        HitboxVisualizer = nil
        -- We don't reset VisualizerEnabled anymore to persist visualization state
        -- VisualizerEnabled = false
    end
end

-- Helper function to configure a part as non-interfering visualizer
local function ConfigureVisualizerPart(part)
    -- Disable all collision properties
    part.CanCollide = false
    part.CanTouch = false 
    part.CanQuery = false
    -- Set collision group to a special visualizer group
    -- This should ensure it doesn't interfere with hit detection
    part.CollisionGroup = "VisualizerParts"
    return part
end

-- Create or update the hitbox visualizer
function UpdateHitboxVisualizer()
    if not CurrentTool then return end
    
    local handle = CurrentTool:FindFirstChild("Handle")
    if not handle or not handle:IsA("BasePart") then return end
    
    -- Clean up any existing visualizer parts
    if HitboxVisualizer then
        HitboxVisualizer:Destroy()
        HitboxVisualizer = nil
    end
    
    -- Try to create a collision group for visualizer parts if it doesn't exist
    pcall(function()
        if not game.PhysicsService:CollisionGroupExists("VisualizerParts") then
            game.PhysicsService:CreateCollisionGroup("VisualizerParts")
            -- Make visualizer parts not collide with anything
            game.PhysicsService:CollisionGroupSetCollidable("VisualizerParts", "Default", false)
        end
    end)
    
    -- Calculate the effective reach size - this is what will be visualized
    local originalSize = OriginalGripData.HandleSize
    if not originalSize then return end
    
    local effectiveSize = Vector3.new(
        originalSize.X * Settings.XSize,
        originalSize.Y * Settings.YSize,
        originalSize.Z * Settings.ZSize
    )
    
    -- Apply overall scaling factor
    if Settings.Size ~= 1 then
        effectiveSize = effectiveSize * Settings.Size
    end
    
    -- Get the offset values
    local xOffset = Settings.XOffset
    local yOffset = Settings.YOffset
    local zOffset = Settings.ZOffset
    local offsetVector = Vector3.new(xOffset, yOffset, zOffset)
    
    -- Create visualizer based on selected style
    if VisualizerSettings.Style == "Full" then
        -- Create a solid part with transparency
        HitboxVisualizer = Instance.new("Part")
        HitboxVisualizer.Name = "ReachVisualizer"
        HitboxVisualizer.Anchored = false
        HitboxVisualizer.CanCollide = false
        -- CRITICAL: These properties ensure it won't interfere with hit detection
        HitboxVisualizer.CanTouch = false -- Disable touch detection
        HitboxVisualizer.CanQuery = false -- Can't be detected by raycasting
        HitboxVisualizer.Transparency = VisualizerSettings.Transparency
        HitboxVisualizer.Material = Enum.Material.ForceField
        HitboxVisualizer.Color = VisualizerSettings.Color
        HitboxVisualizer.Size = effectiveSize
        -- Set collision group to make sure it doesn't interfere
        HitboxVisualizer.CollisionGroup = "Visualizer"
        HitboxVisualizer.Parent = CurrentTool
        
        -- Create weld to attach visualizer to the handle
        local weld = Instance.new("Weld")
        weld.Part0 = handle
        weld.Part1 = HitboxVisualizer
        weld.C0 = CFrame.new(0, 0, 0)
        weld.C1 = CFrame.new(offsetVector/2)
        weld.Parent = HitboxVisualizer
    
    elseif VisualizerSettings.Style == "Outline" then
        -- Create a hollow box using multiple parts for the edges
        HitboxVisualizer = Instance.new("Model")
        HitboxVisualizer.Name = "ReachVisualizerOutline"
        HitboxVisualizer.Parent = CurrentTool
        
        -- Create a center anchor part that will be welded to the handle
        local centerPart = Instance.new("Part")
        centerPart.Name = "VisualizerAnchor"
        centerPart.Anchored = false
        centerPart.Transparency = 1
        centerPart.Size = Vector3.new(0.1, 0.1, 0.1)
        -- Configure part to not interfere with hit detection
        ConfigureVisualizerPart(centerPart)
        centerPart.Parent = HitboxVisualizer
        
        -- Weld the anchor to the handle
        local mainWeld = Instance.new("Weld")
        mainWeld.Part0 = handle
        mainWeld.Part1 = centerPart
        mainWeld.C0 = CFrame.new(0, 0, 0)
        mainWeld.C1 = CFrame.new(offsetVector)
        mainWeld.Parent = centerPart
        
        -- Create edge parts for the outline
        local thickness = 0.15 -- thickness of the outline edges
        local edges = {}
        
        -- Define the 12 edges of a box (3 dimensions × 4 edges each)
        local halfSize = effectiveSize / 2
        
        -- X-direction edges (4)
        for i = 1, 4 do
            local edge = Instance.new("Part")
            edge.Size = Vector3.new(effectiveSize.X, thickness, thickness)
            edge.Transparency = 0.2
            edge.Color = VisualizerSettings.Color
            edge.Material = Enum.Material.Neon
            -- Configure part to not interfere with hit detection
            ConfigureVisualizerPart(edge)
            edge.Parent = HitboxVisualizer
            
            -- Position edge based on index
            local yPos = (i <= 2) and -halfSize.Y or halfSize.Y
            local zPos = ((i % 2) == 1) and -halfSize.Z or halfSize.Z
            
            -- Create weld to attach to the center
            local weld = Instance.new("Weld")
            weld.Part0 = centerPart
            weld.Part1 = edge
            weld.C0 = CFrame.new(0, 0, 0)
            weld.C1 = CFrame.new(0, yPos, zPos)
            weld.Parent = edge
            
            table.insert(edges, edge)
        end
        
        -- Y-direction edges (4)
        for i = 1, 4 do
            local edge = Instance.new("Part")
            edge.Size = Vector3.new(thickness, effectiveSize.Y, thickness)
            edge.Transparency = 0.2
            edge.Color = VisualizerSettings.Color
            edge.Material = Enum.Material.Neon
            -- Configure part to not interfere with hit detection
            ConfigureVisualizerPart(edge)
            edge.Parent = HitboxVisualizer
            
            -- Position edge based on index
            local xPos = (i <= 2) and -halfSize.X or halfSize.X
            local zPos = ((i % 2) == 1) and -halfSize.Z or halfSize.Z
            
            -- Create weld to attach to the center
            local weld = Instance.new("Weld")
            weld.Part0 = centerPart
            weld.Part1 = edge
            weld.C0 = CFrame.new(0, 0, 0)
            weld.C1 = CFrame.new(xPos, 0, zPos)
            weld.Parent = edge
            
            table.insert(edges, edge)
        end
        
        -- Z-direction edges (4)
        for i = 1, 4 do
            local edge = Instance.new("Part")
            edge.Size = Vector3.new(thickness, thickness, effectiveSize.Z)
            edge.Transparency = 0.2
            edge.Color = VisualizerSettings.Color
            edge.Material = Enum.Material.Neon
            -- Configure part to not interfere with hit detection
            ConfigureVisualizerPart(edge)
            edge.Parent = HitboxVisualizer
            
            -- Position edge based on index
            local xPos = (i <= 2) and -halfSize.X or halfSize.X
            local yPos = ((i % 2) == 1) and -halfSize.Y or halfSize.Y
            
            -- Create weld to attach to the center
            local weld = Instance.new("Weld")
            weld.Part0 = centerPart
            weld.Part1 = edge
            weld.C0 = CFrame.new(0, 0, 0)
            weld.C1 = CFrame.new(xPos, yPos, 0)
            weld.Parent = edge
            
            table.insert(edges, edge)
        end
        
    else -- Default to "Wireframe" - simpler outline with just corners
        HitboxVisualizer = Instance.new("Model")
        HitboxVisualizer.Name = "ReachVisualizerWireframe"
        HitboxVisualizer.Parent = CurrentTool
        
        -- Create a center anchor part that will be welded to the handle
        local centerPart = Instance.new("Part")
        centerPart.Name = "VisualizerAnchor"
        centerPart.Anchored = false
        centerPart.Transparency = 1
        centerPart.Size = Vector3.new(0.1, 0.1, 0.1)
        -- Configure part to not interfere with hit detection
        ConfigureVisualizerPart(centerPart)
        centerPart.Parent = HitboxVisualizer
        
        -- Weld the anchor to the handle
        local mainWeld = Instance.new("Weld")
        mainWeld.Part0 = handle
        mainWeld.Part1 = centerPart
        mainWeld.C0 = CFrame.new(0, 0, 0)
        mainWeld.C1 = CFrame.new(offsetVector)
        mainWeld.Parent = centerPart
        
        -- Create corner parts for the wireframe
        local cornerSize = 0.25 -- size of corner indicators
        local corners = {}
        
        -- Create 8 corners for the box
        local halfSize = effectiveSize / 2
        for x = -1, 1, 2 do
            for y = -1, 1, 2 do
                for z = -1, 1, 2 do
                    local corner = Instance.new("Part")
                    corner.Shape = Enum.PartType.Ball
                    corner.Size = Vector3.new(cornerSize, cornerSize, cornerSize)
                    corner.Transparency = 0.2
                    corner.Color = VisualizerSettings.Color
                    corner.Material = Enum.Material.Neon
                    -- Configure part to not interfere with hit detection
                    ConfigureVisualizerPart(corner)
                    corner.Parent = HitboxVisualizer
                    
                    -- Create weld to attach to the center
                    local weld = Instance.new("Weld")
                    weld.Part0 = centerPart
                    weld.Part1 = corner
                    weld.C0 = CFrame.new(0, 0, 0)
                    weld.C1 = CFrame.new(
                        halfSize.X * x, 
                        halfSize.Y * y, 
                        halfSize.Z * z
                    )
                    weld.Parent = corner
                    
                    table.insert(corners, corner)
                end
            end
        end
    end
end

-- Toggle the hitbox visualizer on/off
function ToggleHitboxVisualizer()
    VisualizerEnabled = not VisualizerEnabled
    
    -- Update the global flag for when weapons are switched
    VisualizeOnEquip = VisualizerEnabled
    
    if VisualizerEnabled then
        UpdateHitboxVisualizer()
    elseif HitboxVisualizer then
        HitboxVisualizer:Destroy()
        HitboxVisualizer = nil
    end
    
    return VisualizerEnabled
end

-- Remove the hitbox visualizer
function RemoveHitboxVisualizer()
    if HitboxVisualizer then
        HitboxVisualizer:Destroy()
        HitboxVisualizer = nil
    end
    VisualizerEnabled = false
end

-- Apply modifications to the tool based on current settings
function ApplyToolModifications()
    if not CurrentTool then return end
    
    -- Modify grip position for reach
    local gripPos = CurrentTool:FindFirstChild("GripPos")
    if gripPos and gripPos:IsA("Vector3Value") then
        local basePos = OriginalGripData.GripPos or Vector3.new(0, 0, 0)
        gripPos.Value = Vector3.new(
            basePos.X + Settings.XOffset,
            basePos.Y + Settings.YOffset,
            basePos.Z + Settings.ZOffset
        )
    end
    
    local handle = CurrentTool:FindFirstChild("Handle")
    if handle and handle:IsA("BasePart") and OriginalGripData.HandleSize then
        -- Calculate the effective size
        local effectiveSize = Vector3.new(
            OriginalGripData.HandleSize.X * Settings.XSize,
            OriginalGripData.HandleSize.Y * Settings.YSize,
            OriginalGripData.HandleSize.Z * Settings.ZSize
        )
        
        -- Apply overall scaling factor
        if Settings.Size ~= 1 then
            effectiveSize = effectiveSize * Settings.Size
        end
        
        -- Get the offset values
        local xOffset = Settings.XOffset
        local yOffset = Settings.YOffset
        local zOffset = Settings.ZOffset
        
        -- VISIBLE REACH MODE: If enabled, modify the actual handle
        if VisibleReachMode then
            -- Resize the actual handle to match the hitbox dimensions
            handle.Size = effectiveSize
            
            -- No invisible hitbox needed in this mode since the handle itself is modified
            -- Remove any existing hitbox
            local existingHitbox = CurrentTool:FindFirstChild("ReachModifierHitbox")
            if existingHitbox then
                existingHitbox:Destroy()
            end
        else
            -- INVISIBLE REACH MODE: Create or update invisible hitbox without changing tool appearance
            local hitboxName = "ReachModifierHitbox"
            local hitbox = CurrentTool:FindFirstChild(hitboxName)
            
            if not hitbox then
                -- Create new hitbox part
                hitbox = Instance.new("Part")
                hitbox.Name = hitboxName
                hitbox.Transparency = 1 -- Completely invisible
                hitbox.CanCollide = false -- Don't physically collide with objects
                hitbox.Massless = true -- Don't affect physics
                hitbox.CastShadow = false
                
                -- CRITICAL: These properties ensure the hitbox properly interacts with game mechanics
                hitbox.CanTouch = true -- Enable touch events (critical for hit detection)
                hitbox.CanQuery = true -- Allow raycasting to hit this part
                
                -- Inherit network ownership from the tool (important for server-side hit detection)
                if game:GetService("RunService"):IsServer() then
                    hitbox:SetNetworkOwner(nil) -- Server owns it
                end
                
                -- Copy collision groups from the handle to ensure proper interaction
                hitbox.CollisionGroup = handle.CollisionGroup
                
                -- Allow this part to handle interactions without being visible
                hitbox.Parent = CurrentTool
                
                -- Weld hitbox to handle
                local weld = Instance.new("Weld")
                weld.Part0 = handle
                weld.Part1 = hitbox
                weld.C0 = CFrame.new(0, 0, 0)
                weld.Parent = hitbox
                
                -- Copy all Touch events from handle to hitbox
                local connections = {}
                
                -- Check if TouchInterest exists on handle and replicate it
                local touchInterest = handle:FindFirstChildOfClass("TouchTransmitter")
                if touchInterest then
                    local newTouchInterest = Instance.new("TouchTransmitter")
                    newTouchInterest.Parent = hitbox
                end
            end
            
            -- Update the hitbox size
            hitbox.Size = effectiveSize
            
            -- Update weld offset
            local weld = hitbox:FindFirstChildOfClass("Weld")
            if weld then
                weld.C1 = CFrame.new(Vector3.new(xOffset, yOffset, zOffset) / 2)
            end
            
            -- Make sure the hitbox inherits material properties from handle
            -- This is important for sword detection in many Roblox games
            hitbox.CustomPhysicalProperties = handle.CustomPhysicalProperties
            
            -- Make sure the handle size remains at its original size
            handle.Size = OriginalGripData.HandleSize
        end
    end
    
    -- Update hitbox visualizer if it's enabled (only in invisible mode)
    if VisualizerEnabled and not VisibleReachMode then
        UpdateHitboxVisualizer()
    elseif VisualizerEnabled and VisibleReachMode then
        -- Can't use visualizer in visible mode since the tool itself is changed
        RemoveHitboxVisualizer()
        VisualizerEnabled = false
    end
end

-- Handle Tool Equipped event
local function OnToolEquipped(tool)
    CurrentTool = tool
    StoreToolOriginalProperties(tool)
    
    -- Apply modifications if enabled
    if ModifyingEnabled then
        -- Always set visualizer state based on remembered preference
        VisualizerEnabled = VisualizeOnEquip and not VisibleReachMode
        
        -- Apply modifications first
        ApplyToolModifications()
        
        -- Then update visualizer if needed
        if VisualizerEnabled then
            UpdateHitboxVisualizer()
        end
    end
end

-- Handle Tool Unequipped event
local function OnToolUnequipped()
    -- Save visualizer state for when a new tool is equipped
    if VisualizerEnabled then
        VisualizeOnEquip = true
    end
    
    -- Restore the tool properties
    if ModifyingEnabled and CurrentTool then
        RestoreToolOriginalProperties()
    end
    
    -- Remove visual elements but keep flags
    if HitboxVisualizer then
        HitboxVisualizer:Destroy()
        HitboxVisualizer = nil
    end
    
    CurrentTool = nil
end

-- Create the GUI with enhanced visuals
local function CreateGUI()
    -- Main ScreenGui
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "ReachModifierGUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = Player.PlayerGui
    
    -- Main Frame with rounded corners and shadow effect
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 45) -- Darker, more premium background
    MainFrame.BorderSizePixel = 0
    MainFrame.Position = UDim2.new(0.75, 0, 0.5, -325)
    MainFrame.Size = UDim2.new(0, 260, 0, 675) -- Slightly wider
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.Parent = ScreenGui
    
    -- Add a UICorner for rounded edges
    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 8)
    frameCorner.Parent = MainFrame
    
    -- Add a drop shadow effect
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.BackgroundTransparency = 1
    shadow.Position = UDim2.new(0, -15, 0, -15)
    shadow.Size = UDim2.new(1, 30, 1, 30)
    shadow.ZIndex = -1
    shadow.Image = "rbxassetid://5554236805" -- Shadow image
    shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    shadow.ImageTransparency = 0.6
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(23, 23, 277, 277)
    shadow.Parent = MainFrame
    
    -- Gradient background
    local uiGradient = Instance.new("UIGradient")
    uiGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 40, 60)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(25, 25, 35))
    })
    uiGradient.Rotation = 45
    uiGradient.Parent = MainFrame
    
    -- Title with fancy styling
    local TitleFrame = Instance.new("Frame")
    TitleFrame.Name = "TitleFrame"
    TitleFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    TitleFrame.BorderSizePixel = 0
    TitleFrame.Size = UDim2.new(1, 0, 0, 40) -- Taller title bar
    TitleFrame.Parent = MainFrame
    
    -- Title frame corner
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = TitleFrame
    
    -- Bottom frame to fix corner radius
    local titleBottomFrame = Instance.new("Frame")
    titleBottomFrame.Name = "BottomFix"
    titleBottomFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    titleBottomFrame.BorderSizePixel = 0
    titleBottomFrame.Position = UDim2.new(0, 0, 0.5, 0)
    titleBottomFrame.Size = UDim2.new(1, 0, 0.5, 0)
    titleBottomFrame.Parent = TitleFrame
    
    -- Title with icon
    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Name = "TitleLabel"
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Position = UDim2.new(0, 40, 0, 0)
    TitleLabel.Size = UDim2.new(1, -100, 1, 0)
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.Text = "Reach Modifier"
    TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleLabel.TextSize = 20
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = TitleFrame
    
    -- Icon for the title
    local titleIcon = Instance.new("ImageLabel")
    titleIcon.Name = "Icon"
    titleIcon.BackgroundTransparency = 1
    titleIcon.Position = UDim2.new(0, 8, 0.5, -12)
    titleIcon.Size = UDim2.new(0, 24, 0, 24)
    titleIcon.Image = "rbxassetid://7733715400" -- Sword icon
    titleIcon.Parent = TitleFrame
    
    -- Close Button with hover effect
    local CloseButton = Instance.new("TextButton")
    CloseButton.Name = "CloseButton"
    CloseButton.BackgroundColor3 = Color3.fromRGB(192, 57, 43)
    CloseButton.BorderSizePixel = 0
    CloseButton.Position = UDim2.new(1, -35, 0.5, -12)
    CloseButton.Size = UDim2.new(0, 25, 0, 25)
    CloseButton.Font = Enum.Font.GothamBold
    CloseButton.Text = "X"
    CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseButton.TextSize = 14
    CloseButton.Parent = TitleFrame
    
    -- Button corner radius
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 4)
    closeCorner.Parent = CloseButton
    
    -- Minimize Button with hover effect
    local MinimizeButton = Instance.new("TextButton")
    MinimizeButton.Name = "MinimizeButton"
    MinimizeButton.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
    MinimizeButton.BorderSizePixel = 0
    MinimizeButton.Position = UDim2.new(1, -65, 0.5, -12)
    MinimizeButton.Size = UDim2.new(0, 25, 0, 25)
    MinimizeButton.Font = Enum.Font.GothamBold
    MinimizeButton.Text = "-"
    MinimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    MinimizeButton.TextSize = 18
    MinimizeButton.Parent = TitleFrame
    
    -- Button corner radius
    local minimizeCorner = Instance.new("UICorner")
    minimizeCorner.CornerRadius = UDim.new(0, 4)
    minimizeCorner.Parent = MinimizeButton
    
    -- Content Frame with padding
    local ContentFrame = Instance.new("Frame")
    ContentFrame.Name = "ContentFrame"
    ContentFrame.BackgroundTransparency = 1
    ContentFrame.Position = UDim2.new(0, 0, 0, 45)
    ContentFrame.Size = UDim2.new(1, 0, 1, -45)
    ContentFrame.Parent = MainFrame
    
    -- Add padding to content
    local contentPadding = Instance.new("UIPadding")
    contentPadding.PaddingLeft = UDim.new(0, 15)
    contentPadding.PaddingRight = UDim.new(0, 15)
    contentPadding.PaddingTop = UDim.new(0, 10)
    contentPadding.PaddingBottom = UDim.new(0, 10)
    contentPadding.Parent = ContentFrame
    
    -- Enable Button with cool gradient and animation
    local EnableButton = Instance.new("TextButton")
    EnableButton.Name = "EnableButton"
    EnableButton.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
    EnableButton.BorderSizePixel = 0
    EnableButton.Position = UDim2.new(0.5, -100, 0, 10)
    EnableButton.Size = UDim2.new(0, 200, 0, 35) -- Taller button
    EnableButton.Font = Enum.Font.GothamBold
    EnableButton.Text = "Enable Reach Modifier"
    EnableButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    EnableButton.TextSize = 16
    EnableButton.Parent = ContentFrame
    
    -- Button rounded corners
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 6)
    buttonCorner.Parent = EnableButton
    
    -- Button gradient
    local buttonGradient = Instance.new("UIGradient")
    buttonGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(231, 76, 60)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(192, 57, 43))
    })
    buttonGradient.Rotation = 90
    buttonGradient.Parent = EnableButton
    
    -- Status Label with icon
    local StatusFrame = Instance.new("Frame")
    StatusFrame.Name = "StatusFrame"
    StatusFrame.BackgroundTransparency = 1
    StatusFrame.Position = UDim2.new(0, 0, 0, 55)
    StatusFrame.Size = UDim2.new(1, 0, 0, 25)
    StatusFrame.Parent = ContentFrame
    
    local statusIcon = Instance.new("ImageLabel")
    statusIcon.Name = "StatusIcon"
    statusIcon.BackgroundTransparency = 1
    statusIcon.Position = UDim2.new(0, 0, 0, 0)
    statusIcon.Size = UDim2.new(0, 20, 0, 20)
    statusIcon.Image = "rbxassetid://6031075931" -- Status icon
    statusIcon.ImageColor3 = Color3.fromRGB(231, 76, 60)
    statusIcon.Parent = StatusFrame
    
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Name = "StatusLabel"
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Position = UDim2.new(0, 30, 0, 0)
    StatusLabel.Size = UDim2.new(1, -30, 1, 0)
    StatusLabel.Font = Enum.Font.Gotham
    StatusLabel.Text = "Status: Disabled"
    StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    StatusLabel.TextSize = 14
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    StatusLabel.Parent = StatusFrame
    
    -- Helper Function to Create Modern Slider with better visuals
    local function CreateSlider(name, displayName, defaultValue, yPos)
        local SliderFrame = Instance.new("Frame")
        SliderFrame.Name = name .. "Frame"
        SliderFrame.BackgroundTransparency = 1
        SliderFrame.Position = UDim2.new(0, 0, 0, yPos)
        SliderFrame.Size = UDim2.new(1, -0, 0, 50) -- Taller for better spacing
        SliderFrame.Parent = ContentFrame
        
        -- Section background with rounded corners
        local sectionBg = Instance.new("Frame")
        sectionBg.Name = "SectionBackground"
        sectionBg.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
        sectionBg.BorderSizePixel = 0
        sectionBg.Position = UDim2.new(0, 0, 0, 0)
        sectionBg.Size = UDim2.new(1, 0, 1, 0)
        sectionBg.ZIndex = 0
        sectionBg.Parent = SliderFrame
        
        -- Section corner radius
        local sectionCorner = Instance.new("UICorner")
        sectionCorner.CornerRadius = UDim.new(0, 6)
        sectionCorner.Parent = sectionBg
        
        -- Slider header with icon
        local headerIcon = Instance.new("ImageLabel")
        headerIcon.Name = "Icon"
        headerIcon.BackgroundTransparency = 1
        headerIcon.Position = UDim2.new(0, 8, 0, 6)
        headerIcon.Size = UDim2.new(0, 16, 0, 16)
        headerIcon.ZIndex = 2
        headerIcon.Image = "rbxassetid://6022668885" -- Slider icon
        headerIcon.ImageColor3 = Color3.fromRGB(200, 200, 200)
        headerIcon.Parent = SliderFrame
        
        -- Stylish label with modern font
        local SliderLabel = Instance.new("TextLabel")
        SliderLabel.Name = "Label"
        SliderLabel.BackgroundTransparency = 1
        SliderLabel.Position = UDim2.new(0, 30, 0, 4)
        SliderLabel.Size = UDim2.new(1, -90, 0, 20)
        SliderLabel.Font = Enum.Font.GothamSemibold
        SliderLabel.Text = displayName
        SliderLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
        SliderLabel.TextSize = 14
        SliderLabel.TextXAlignment = Enum.TextXAlignment.Left
        SliderLabel.ZIndex = 2
        SliderLabel.Parent = SliderFrame
        
        -- Value display label with modern look
        local valueDisplay = Instance.new("TextLabel")
        valueDisplay.Name = "ValueDisplay"
        valueDisplay.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
        valueDisplay.BorderSizePixel = 0
        valueDisplay.Position = UDim2.new(1, -55, 0, 4)
        valueDisplay.Size = UDim2.new(0, 45, 0, 20)
        valueDisplay.Font = Enum.Font.GothamBold
        valueDisplay.Text = tostring(defaultValue)
        valueDisplay.TextColor3 = Color3.fromRGB(255, 255, 255)
        valueDisplay.TextSize = 12
        valueDisplay.ZIndex = 2
        valueDisplay.Parent = SliderFrame
        
        -- Value display corner radius
        local valueCorner = Instance.new("UICorner")
        valueCorner.CornerRadius = UDim.new(0, 4)
        valueCorner.Parent = valueDisplay
        
        -- Modern slider bar with rounded corners
        local SliderBar = Instance.new("Frame")
        SliderBar.Name = "SliderBar"
        SliderBar.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
        SliderBar.BorderSizePixel = 0
        SliderBar.Position = UDim2.new(0, 8, 0, 30)
        SliderBar.Size = UDim2.new(1, -16, 0, 8)
        SliderBar.ZIndex = 2
        SliderBar.Parent = SliderFrame
        
        -- Slider bar corner radius
        local barCorner = Instance.new("UICorner")
        barCorner.CornerRadius = UDim.new(0, 4)
        barCorner.Parent = SliderBar
        
        -- Colorful slider fill with gradient
        local SliderFill = Instance.new("Frame")
        SliderFill.Name = "SliderFill"
        SliderFill.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
        SliderFill.BorderSizePixel = 0
        SliderFill.Size = UDim2.new(0.5, 0, 1, 0)
        SliderFill.ZIndex = 3
        SliderFill.Parent = SliderBar
        
        -- Slider fill corner radius
        local fillCorner = Instance.new("UICorner")
        fillCorner.CornerRadius = UDim.new(0, 4)
        fillCorner.Parent = SliderFill
        
        -- Fancy gradient for slider fill
        local fillGradient = Instance.new("UIGradient")
        fillGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(52, 152, 219)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(41, 128, 185))
        })
        fillGradient.Rotation = 90
        fillGradient.Parent = SliderFill
        
        -- Modern slider button/knob
        local SliderButton = Instance.new("TextButton")
        SliderButton.Name = "SliderButton"
        SliderButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        SliderButton.BorderSizePixel = 0
        SliderButton.Position = UDim2.new(0.5, -6, 0.5, -6)
        SliderButton.Size = UDim2.new(0, 12, 0, 12)
        SliderButton.Text = ""
        SliderButton.ZIndex = 4
        SliderButton.Parent = SliderFill
        
        -- Button corner radius (circular)
        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(1, 0) -- Makes it a perfect circle
        buttonCorner.Parent = SliderButton
        
        -- Slider glow effect
        local buttonGlow = Instance.new("ImageLabel")
        buttonGlow.Name = "Glow"
        buttonGlow.BackgroundTransparency = 1
        buttonGlow.Position = UDim2.new(0.5, -12, 0.5, -12)
        buttonGlow.Size = UDim2.new(0, 24, 0, 24)
        buttonGlow.ZIndex = 3
        buttonGlow.Image = "rbxassetid://1316045217" -- Radial gradient for glow
        buttonGlow.ImageColor3 = Color3.fromRGB(52, 152, 219)
        buttonGlow.ImageTransparency = 0.4
        buttonGlow.Parent = SliderButton
        
        -- Hidden text box for direct input
        local SliderValue = Instance.new("TextBox")
        SliderValue.Name = "Value"
        SliderValue.BackgroundTransparency = 1
        SliderValue.BorderSizePixel = 0
        SliderValue.Position = UDim2.new(0, 0, 0, 0)
        SliderValue.Size = UDim2.new(0, 0, 0, 0) -- Hidden, but accessible in code
        SliderValue.Text = tostring(defaultValue)
        SliderValue.TextTransparency = 1
        SliderValue.Parent = SliderFrame
        
        return SliderFrame, SliderLabel, SliderButton, SliderValue, valueDisplay
    end
    
    -- X Offset Slider
    local XFrame, XLabel, XButton, XValue = CreateSlider("XOffset", "X Offset", Settings.XOffset, 70)
    
    -- Y Offset Slider
    local YFrame, YLabel, YButton, YValue = CreateSlider("YOffset", "Y Offset", Settings.YOffset, 120)
    
    -- Z Offset Slider
    local ZFrame, ZLabel, ZButton, ZValue = CreateSlider("ZOffset", "Z Offset", Settings.ZOffset, 170)
    
    -- X Size Slider (Independent X Size control)
    local XSizeFrame, XSizeLabel, XSizeButton, XSizeValue = CreateSlider("XSize", "X Size", Settings.XSize, 220)
    
    -- Y Size Slider (Independent Y Size control)
    local YSizeFrame, YSizeLabel, YSizeButton, YSizeValue = CreateSlider("YSize", "Y Size", Settings.YSize, 270)
    
    -- Z Size Slider (Independent Z Size control)
    local ZSizeFrame, ZSizeLabel, ZSizeButton, ZSizeValue = CreateSlider("ZSize", "Z Size", Settings.ZSize, 320)
    
    -- Overall Size Slider (Affects all dimensions)
    local SizeFrame, SizeLabel, SizeButton, SizeValue = CreateSlider("Size", "Overall Size", Settings.Size, 370)
    
    -- Visualizer section header
    local visualizerHeader = Instance.new("Frame")
    visualizerHeader.Name = "VisualizerHeader"
    visualizerHeader.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
    visualizerHeader.BorderSizePixel = 0
    visualizerHeader.Position = UDim2.new(0, 0, 0, 430)
    visualizerHeader.Size = UDim2.new(1, 0, 0, 40)
    visualizerHeader.Parent = ContentFrame
    
    -- Header corner radius
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 6)
    headerCorner.Parent = visualizerHeader
    
    -- Visualizer section icon
    local visualizerIcon = Instance.new("ImageLabel")
    visualizerIcon.Name = "Icon"
    visualizerIcon.BackgroundTransparency = 1
    visualizerIcon.Position = UDim2.new(0, 10, 0.5, -10)
    visualizerIcon.Size = UDim2.new(0, 20, 0, 20)
    visualizerIcon.Image = "rbxassetid://6031090990" -- Visualize icon
    visualizerIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
    visualizerIcon.Parent = visualizerHeader
    
    -- Visualizer section title
    local visualizerTitle = Instance.new("TextLabel")
    visualizerTitle.Name = "Title"
    visualizerTitle.BackgroundTransparency = 1
    visualizerTitle.Position = UDim2.new(0, 40, 0, 0)
    visualizerTitle.Size = UDim2.new(1, -160, 1, 0)
    visualizerTitle.Font = Enum.Font.GothamBold
    visualizerTitle.Text = "Hitbox Visualizer"
    visualizerTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    visualizerTitle.TextSize = 16
    visualizerTitle.TextXAlignment = Enum.TextXAlignment.Left
    visualizerTitle.Parent = visualizerHeader
    
    -- Modern toggle button with animation
    local VisualizerButton = Instance.new("TextButton")
    VisualizerButton.Name = "VisualizerButton"
    VisualizerButton.BackgroundColor3 = Color3.fromRGB(48, 48, 68)
    VisualizerButton.BorderSizePixel = 0
    VisualizerButton.Position = UDim2.new(1, -120, 0.5, -15)
    VisualizerButton.Size = UDim2.new(0, 100, 0, 30)
    VisualizerButton.Font = Enum.Font.GothamBold
    VisualizerButton.Text = "SHOW"
    VisualizerButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    VisualizerButton.TextSize = 14
    VisualizerButton.Parent = visualizerHeader
    
    -- Button corner radius
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 15) -- Pill-shaped button
    buttonCorner.Parent = VisualizerButton
    
    -- Button gradient
    local buttonGradient = Instance.new("UIGradient")
    buttonGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(52, 152, 219)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(41, 128, 185))
    })
    buttonGradient.Rotation = 90
    buttonGradient.Parent = VisualizerButton
    
    -- Status indicator dot
    local statusDot = Instance.new("Frame")
    statusDot.Name = "StatusDot"
    statusDot.BackgroundColor3 = Color3.fromRGB(231, 76, 60) -- Red when disabled
    statusDot.BorderSizePixel = 0
    statusDot.Position = UDim2.new(0, 10, 0.5, -4)
    statusDot.Size = UDim2.new(0, 8, 0, 8)
    statusDot.Visible = true
    statusDot.ZIndex = 2
    statusDot.Parent = VisualizerButton
    
    -- Make the dot circular
    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(1, 0)
    dotCorner.Parent = statusDot
    
    -- Hidden status label (we'll use the dot color instead of text)
    local VisualizerStatusLabel = Instance.new("TextLabel")
    VisualizerStatusLabel.Name = "VisualizerStatusLabel"
    VisualizerStatusLabel.BackgroundTransparency = 1
    VisualizerStatusLabel.Position = UDim2.new(0, 0, 0, 0)
    VisualizerStatusLabel.Size = UDim2.new(0, 0, 0, 0)
    VisualizerStatusLabel.Text = "Disabled"
    VisualizerStatusLabel.TextTransparency = 1
    VisualizerStatusLabel.Parent = ContentFrame
    
    -- Visualizer Styles Section
    local styleSection = Instance.new("Frame")
    styleSection.Name = "StyleSection"
    styleSection.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
    styleSection.BorderSizePixel = 0
    styleSection.Position = UDim2.new(0, 0, 0, 480)
    styleSection.Size = UDim2.new(1, 0, 0, 70)
    styleSection.Parent = ContentFrame
    
    -- Section corner radius
    local sectionCorner = Instance.new("UICorner")
    sectionCorner.CornerRadius = UDim.new(0, 6)
    sectionCorner.Parent = styleSection
    
    -- Style section icon
    local styleIcon = Instance.new("ImageLabel")
    styleIcon.Name = "Icon"
    styleIcon.BackgroundTransparency = 1
    styleIcon.Position = UDim2.new(0, 10, 0, 10)
    styleIcon.Size = UDim2.new(0, 20, 0, 20)
    styleIcon.Image = "rbxassetid://6022668975" -- Style icon
    styleIcon.ImageColor3 = Color3.fromRGB(200, 200, 200)
    styleIcon.Parent = styleSection
    
    -- Style section title
    local VisualizerStyleLabel = Instance.new("TextLabel")
    VisualizerStyleLabel.Name = "VisualizerStyleLabel"
    VisualizerStyleLabel.BackgroundTransparency = 1
    VisualizerStyleLabel.Position = UDim2.new(0, 40, 0, 10)
    VisualizerStyleLabel.Size = UDim2.new(1, -50, 0, 20)
    VisualizerStyleLabel.Font = Enum.Font.GothamSemibold
    VisualizerStyleLabel.Text = "Visualization Style"
    VisualizerStyleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    VisualizerStyleLabel.TextSize = 14
    VisualizerStyleLabel.TextXAlignment = Enum.TextXAlignment.Left
    VisualizerStyleLabel.Parent = styleSection
    
    -- Style buttons container
    local styleContainer = Instance.new("Frame")
    styleContainer.Name = "StyleContainer"
    styleContainer.BackgroundTransparency = 1
    styleContainer.Position = UDim2.new(0, 10, 0, 35)
    styleContainer.Size = UDim2.new(1, -20, 0, 30)
    styleContainer.Parent = styleSection
    
    -- Style Option Buttons
    local styleButtonWidth = 0.33
    local styleNames = {"Full", "Outline", "Wireframe"}
    local styleDescriptions = {
        "Solid Box", "Edges Only", "Corner Points"
    }
    local styleButtons = {}
    
    -- Create a unified background for radio button style
    local styleButtonsBackground = Instance.new("Frame")
    styleButtonsBackground.Name = "Background"
    styleButtonsBackground.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    styleButtonsBackground.BorderSizePixel = 0
    styleButtonsBackground.Size = UDim2.new(1, 0, 1, 0)
    styleButtonsBackground.Parent = styleContainer
    
    -- Background corner radius
    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(0, 6)
    bgCorner.Parent = styleButtonsBackground
    
    for i, styleName in ipairs(styleNames) do
        local StyleButton = Instance.new("TextButton")
        StyleButton.Name = styleName .. "StyleButton"
        StyleButton.BackgroundColor3 = (styleName == VisualizerSettings.Style) 
            and Color3.fromRGB(52, 152, 219)  -- Blue if selected
            or Color3.fromRGB(35, 35, 50)     -- Dark if not selected
        StyleButton.BorderSizePixel = 0
        StyleButton.Position = UDim2.new((i-1) * styleButtonWidth, 0, 0, 0)
        StyleButton.Size = UDim2.new(styleButtonWidth, 0, 1, 0)
        StyleButton.Font = Enum.Font.GothamSemibold
        StyleButton.Text = styleName
        StyleButton.TextColor3 = (styleName == VisualizerSettings.Style)
            and Color3.fromRGB(255, 255, 255)  -- White if selected
            or Color3.fromRGB(180, 180, 180)   -- Gray if not selected
        StyleButton.TextSize = 13
        StyleButton.ZIndex = 2
        StyleButton.Parent = styleContainer
        
        -- Add tooltip/description under the button text
        local description = Instance.new("TextLabel")
        description.Name = "Description"
        description.BackgroundTransparency = 1
        description.Position = UDim2.new(0, 0, 0.65, 0)
        description.Size = UDim2.new(1, 0, 0.35, 0)
        description.Font = Enum.Font.Gotham
        description.Text = styleDescriptions[i]
        description.TextColor3 = Color3.fromRGB(150, 150, 150)
        description.TextSize = 10
        description.ZIndex = 2
        description.Parent = StyleButton
        
        -- Button corner radius (only add to first and last to create pill effect)
        if i == 1 or i == #styleNames then
            local buttonCorner = Instance.new("UICorner")
            buttonCorner.CornerRadius = UDim.new(0, 6)
            buttonCorner.Parent = StyleButton
            
            -- Fix corner radius (only round outer corners)
            if i == 1 then -- First button
                local cornerFix = Instance.new("Frame")
                cornerFix.Name = "RightFix"
                cornerFix.BackgroundColor3 = StyleButton.BackgroundColor3
                cornerFix.BorderSizePixel = 0
                cornerFix.Position = UDim2.new(0.5, 0, 0, 0)
                cornerFix.Size = UDim2.new(0.5, 0, 1, 0)
                cornerFix.ZIndex = StyleButton.ZIndex
                cornerFix.Parent = StyleButton
            elseif i == #styleNames then -- Last button
                local cornerFix = Instance.new("Frame")
                cornerFix.Name = "LeftFix"
                cornerFix.BackgroundColor3 = StyleButton.BackgroundColor3
                cornerFix.BorderSizePixel = 0
                cornerFix.Position = UDim2.new(0, 0, 0, 0)
                cornerFix.Size = UDim2.new(0.5, 0, 1, 0)
                cornerFix.ZIndex = StyleButton.ZIndex
                cornerFix.Parent = StyleButton
            end
        end
        
        table.insert(styleButtons, StyleButton)
    end
    
    -- Color section
    local colorSection = Instance.new("Frame")
    colorSection.Name = "ColorSection"
    colorSection.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
    colorSection.BorderSizePixel = 0
    colorSection.Position = UDim2.new(0, 0, 0, 560)
    colorSection.Size = UDim2.new(1, 0, 0, 70)
    colorSection.Parent = ContentFrame
    
    -- Section corner radius
    local colorCorner = Instance.new("UICorner")
    colorCorner.CornerRadius = UDim.new(0, 6)
    colorCorner.Parent = colorSection
    
    -- Color section icon
    local colorIcon = Instance.new("ImageLabel")
    colorIcon.Name = "Icon"
    colorIcon.BackgroundTransparency = 1
    colorIcon.Position = UDim2.new(0, 10, 0, 10)
    colorIcon.Size = UDim2.new(0, 20, 0, 20)
    colorIcon.Image = "rbxassetid://6026568240" -- Color palette icon
    colorIcon.ImageColor3 = Color3.fromRGB(200, 200, 200)
    colorIcon.Parent = colorSection
    
    -- Color section title
    local ColorLabel = Instance.new("TextLabel")
    ColorLabel.Name = "ColorLabel"
    ColorLabel.BackgroundTransparency = 1
    ColorLabel.Position = UDim2.new(0, 40, 0, 10)
    ColorLabel.Size = UDim2.new(1, -50, 0, 20)
    ColorLabel.Font = Enum.Font.GothamSemibold
    ColorLabel.Text = "Visualizer Color"
    ColorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    ColorLabel.TextSize = 14
    ColorLabel.TextXAlignment = Enum.TextXAlignment.Left
    ColorLabel.Parent = colorSection
    
    -- Color picker container
    local colorContainer = Instance.new("Frame")
    colorContainer.Name = "ColorContainer"
    colorContainer.BackgroundTransparency = 1
    colorContainer.Position = UDim2.new(0, 10, 0, 35)
    colorContainer.Size = UDim2.new(1, -20, 0, 30)
    colorContainer.Parent = colorSection
    
    -- Color buttons with better styling
    local colorButtonWidth = 0.25
    local colorOptions = {
        {name = "Red", color = Color3.fromRGB(255, 0, 0), displayName = "Red"},
        {name = "Green", color = Color3.fromRGB(46, 204, 113), displayName = "Green"},
        {name = "Blue", color = Color3.fromRGB(52, 152, 219), displayName = "Blue"},
        {name = "Yellow", color = Color3.fromRGB(241, 196, 15), displayName = "Yellow"}
    }
    local colorButtons = {}
    
    for i, colorInfo in ipairs(colorOptions) do
        local ColorButton = Instance.new("TextButton")
        ColorButton.Name = colorInfo.name .. "ColorButton"
        ColorButton.BackgroundColor3 = colorInfo.color
        ColorButton.BorderSizePixel = 0
        ColorButton.Position = UDim2.new((i-1) * colorButtonWidth, 0, 0, 0)
        ColorButton.Size = UDim2.new(colorButtonWidth, -10, 0, 30)
        ColorButton.Font = Enum.Font.GothamSemibold
        ColorButton.Text = ""
        ColorButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        ColorButton.TextSize = 11
        ColorButton.Parent = colorContainer
        
        -- Add corner radius to color buttons
        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 6)
        buttonCorner.Parent = ColorButton
        
        -- Add color name as text
        local colorName = Instance.new("TextLabel")
        colorName.Name = "ColorName"
        colorName.BackgroundTransparency = 1
        colorName.Position = UDim2.new(0, 0, 0, 0)
        colorName.Size = UDim2.new(1, 0, 1, 0)
        colorName.Font = Enum.Font.GothamSemibold
        colorName.Text = colorInfo.displayName
        colorName.TextColor3 = Color3.fromRGB(255, 255, 255)
        colorName.TextStrokeTransparency = 0.5
        colorName.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        colorName.TextSize = 12
        colorName.Parent = ColorButton
        
        -- Add selection indicator
        if colorInfo.color == VisualizerSettings.Color then
            local selectedIndicator = Instance.new("ImageLabel")
            selectedIndicator.Name = "SelectedIndicator"
            selectedIndicator.BackgroundTransparency = 1
            selectedIndicator.Position = UDim2.new(0.5, -8, 0.5, -8)
            selectedIndicator.Size = UDim2.new(0, 16, 0, 16)
            selectedIndicator.Image = "rbxassetid://6031094678" -- Checkmark icon
            selectedIndicator.ImageColor3 = Color3.fromRGB(255, 255, 255)
            selectedIndicator.ZIndex = 2
            selectedIndicator.Parent = ColorButton
        end
        
        table.insert(colorButtons, ColorButton)
    end
    
    -- Visual Reach Mode Section
    local modeSection = Instance.new("Frame")
    modeSection.Name = "ModeSection"
    modeSection.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
    modeSection.BorderSizePixel = 0
    modeSection.Position = UDim2.new(0, 0, 0, 520)
    modeSection.Size = UDim2.new(1, 0, 0, 30)
    modeSection.Parent = ContentFrame
    
    -- Mode section corner radius
    local modeCorner = Instance.new("UICorner")
    modeCorner.CornerRadius = UDim.new(0, 6)
    modeCorner.Parent = modeSection
    
    -- Mode section label
    local modeLabel = Instance.new("TextLabel")
    modeLabel.Name = "ModeLabel"
    modeLabel.BackgroundTransparency = 1
    modeLabel.Position = UDim2.new(0, 10, 0, 0)
    modeLabel.Size = UDim2.new(0, 120, 1, 0)
    modeLabel.Font = Enum.Font.GothamSemibold
    modeLabel.Text = "Visual Reach Mode"
    modeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    modeLabel.TextSize = 13
    modeLabel.TextXAlignment = Enum.TextXAlignment.Left
    modeLabel.Parent = modeSection
    
    -- Create modern toggle switch
    local toggleContainer = Instance.new("Frame")
    toggleContainer.Name = "ToggleContainer"
    toggleContainer.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    toggleContainer.BorderSizePixel = 0
    toggleContainer.Position = UDim2.new(1, -60, 0.5, -10)
    toggleContainer.Size = UDim2.new(0, 50, 0, 20)
    toggleContainer.Parent = modeSection
    
    -- Toggle container corner radius
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(1, 0) -- Perfectly round
    toggleCorner.Parent = toggleContainer
    
    -- Toggle knob
    local toggleKnob = Instance.new("Frame")
    toggleKnob.Name = "Knob"
    toggleKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    toggleKnob.BorderSizePixel = 0
    toggleKnob.Position = UDim2.new(0, 2, 0.5, -8)
    toggleKnob.Size = UDim2.new(0, 16, 0, 16) 
    toggleKnob.ZIndex = 2
    toggleKnob.Parent = toggleContainer
    
    -- Knob corner radius
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0) -- Perfectly round
    knobCorner.Parent = toggleKnob
    
    -- Create invisible button for the whole toggle
    local VisualReachModeButton = Instance.new("TextButton")
    VisualReachModeButton.Name = "VisualReachModeButton"
    VisualReachModeButton.BackgroundTransparency = 1
    VisualReachModeButton.Position = UDim2.new(0, 0, 0, 0)
    VisualReachModeButton.Size = UDim2.new(1, 0, 1, 0)
    VisualReachModeButton.Font = Enum.Font.SourceSans
    VisualReachModeButton.Text = ""
    VisualReachModeButton.Parent = modeSection
    
    -- Presets Frame
    local PresetsFrame = Instance.new("Frame")
    PresetsFrame.Name = "PresetsFrame"
    PresetsFrame.BackgroundTransparency = 1
    PresetsFrame.Position = UDim2.new(0, 0, 0, 630)
    PresetsFrame.Size = UDim2.new(1, 0, 0, 60)
    PresetsFrame.Parent = ContentFrame
    
    -- Presets Label
    local PresetsLabel = Instance.new("TextLabel")
    PresetsLabel.Name = "PresetsLabel"
    PresetsLabel.BackgroundTransparency = 1
    PresetsLabel.Position = UDim2.new(0, 10, 0, 0)
    PresetsLabel.Size = UDim2.new(0, 100, 0, 20)
    PresetsLabel.Font = Enum.Font.SourceSans
    PresetsLabel.Text = "Presets:"
    PresetsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    PresetsLabel.TextSize = 14
    PresetsLabel.TextXAlignment = Enum.TextXAlignment.Left
    PresetsLabel.Parent = PresetsFrame
    
    -- Preset Buttons
    local presetButtonWidth = 0.25
    local presetNames = {"Default", "LongReach", "MegaReach", "Wide"}
    local presetButtons = {}
    
    for i, name in ipairs(presetNames) do
        local PresetButton = Instance.new("TextButton")
        PresetButton.Name = name .. "Button"
        PresetButton.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
        PresetButton.BorderSizePixel = 0
        PresetButton.Position = UDim2.new((i-1) * presetButtonWidth, 5, 0, 25)
        PresetButton.Size = UDim2.new(presetButtonWidth, -10, 0, 30)
        PresetButton.Font = Enum.Font.SourceSans
        PresetButton.Text = name
        PresetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        PresetButton.TextSize = 14
        PresetButton.Parent = PresetsFrame
        
        table.insert(presetButtons, PresetButton)
    end
    
    -- Connect Button Events -----------------------------------------
    
    -- Close Button
    CloseButton.MouseButton1Click:Connect(function()
        ScreenGui:Destroy()
    end)
    
    -- Minimize Button
    local isMinimized = false
    MinimizeButton.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        if isMinimized then
            ContentFrame.Visible = false
            MainFrame.Size = UDim2.new(0, 250, 0, 35)
        else
            ContentFrame.Visible = true
            MainFrame.Size = UDim2.new(0, 250, 0, 675)
        end
    end)
    
    -- Enable Button
    EnableButton.MouseButton1Click:Connect(function()
        ModifyingEnabled = not ModifyingEnabled
        if ModifyingEnabled then
            EnableButton.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
            EnableButton.Text = "Disable Reach Modifier"
            StatusLabel.Text = "Status: Enabled"
            
            -- Apply modifications to current tool if one is equipped
            if CurrentTool then
                ApplyToolModifications()
            end
        else
            EnableButton.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
            EnableButton.Text = "Enable Reach Modifier"
            StatusLabel.Text = "Status: Disabled"
            
            -- Restore original tool properties if one is equipped
            if CurrentTool then
                RestoreToolOriginalProperties()
            end
            
            -- Also disable visualizer when disabling the modifier
            if VisualizerEnabled then
                ToggleHitboxVisualizer()
                VisualizerButton.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
                VisualizerButton.Text = "Show Hitbox Visualizer"
                VisualizerStatusLabel.Text = "Visualizer: Disabled"
            end
        end
    end)
    
    -- Visualizer Button Event Handler
    VisualizerButton.MouseButton1Click:Connect(function()
        -- Only allow visualizer if the modifier is enabled
        if not ModifyingEnabled then
            -- Notify user that the reach modifier must be enabled first
            VisualizerStatusLabel.Text = "Enable Reach Modifier first!"
            wait(2) -- Show message for 2 seconds
            VisualizerStatusLabel.Text = "Visualizer: Disabled"
            return
        end
        
        -- Toggle visualizer
        local isEnabled = ToggleHitboxVisualizer()
        if isEnabled then
            VisualizerButton.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
            VisualizerButton.Text = "Hide Hitbox Visualizer"
            VisualizerStatusLabel.Text = "Visualizer: Enabled"
        else
            VisualizerButton.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
            VisualizerButton.Text = "Show Hitbox Visualizer"
            VisualizerStatusLabel.Text = "Visualizer: Disabled"
        end
    end)
    
    -- Visual Reach Mode Button Event Handler
    VisualReachModeButton.MouseButton1Click:Connect(function()
        -- Toggle the visual reach mode
        VisibleReachMode = not VisibleReachMode
        
        -- Update toggle appearance
        if VisibleReachMode then
            -- Move knob to right side when ON
            toggleContainer.BackgroundColor3 = Color3.fromRGB(155, 89, 182) -- Purple when enabled
            toggleKnob:TweenPosition(
                UDim2.new(1, -18, 0.5, -8),
                Enum.EasingDirection.Out,
                Enum.EasingStyle.Quad,
                0.2,
                true
            )
            
            -- Add status label showing "ON"
            local statusText = Instance.new("TextLabel")
            statusText.Name = "StatusText"
            statusText.BackgroundTransparency = 1
            statusText.Position = UDim2.new(0, 0, 0, 0)
            statusText.Size = UDim2.new(0.5, 0, 1, 0)
            statusText.Font = Enum.Font.GothamBold
            statusText.Text = "ON"
            statusText.TextColor3 = Color3.fromRGB(255, 255, 255)
            statusText.TextSize = 11
            statusText.Parent = toggleContainer
            
            -- If visualizer is enabled, disable it as it's not compatible with visible mode
            if VisualizerEnabled then
                ToggleHitboxVisualizer()
                VisualizerButton.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
                VisualizerButton.Text = "SHOW"
                
                -- Update status dot
                statusDot.BackgroundColor3 = Color3.fromRGB(231, 76, 60) -- Red when disabled
            end
        else
            -- Move knob to left side when OFF
            toggleContainer.BackgroundColor3 = Color3.fromRGB(35, 35, 50) -- Dark when disabled
            toggleKnob:TweenPosition(
                UDim2.new(0, 2, 0.5, -8),
                Enum.EasingDirection.Out,
                Enum.EasingStyle.Quad,
                0.2,
                true
            )
            
            -- Remove status text if it exists
            local statusText = toggleContainer:FindFirstChild("StatusText")
            if statusText then
                statusText:Destroy()
            end
        end
        
        -- Update the tool if currently modifying and a tool is equipped
        if ModifyingEnabled and CurrentTool then
            ApplyToolModifications()
        end
    end)
    
    -- Style buttons event handlers
    for i, button in ipairs(styleButtons) do
        button.MouseButton1Click:Connect(function()
            -- Update the visualization style
            VisualizerSettings.Style = styleNames[i]
            
            -- Update button colors
            for j, otherButton in ipairs(styleButtons) do
                otherButton.BackgroundColor3 = (j == i) 
                    and Color3.fromRGB(46, 204, 113)  -- Green if selected
                    or Color3.fromRGB(52, 152, 219)   -- Blue if not selected
            end
            
            -- Update visualizer if it's visible
            if VisualizerEnabled and HitboxVisualizer then
                UpdateHitboxVisualizer()
            end
        end)
    end
    
    -- Color selection event handlers
    for i, button in ipairs(colorButtons) do
        button.MouseButton1Click:Connect(function()
            -- Update the selected color
            VisualizerSettings.Color = colorOptions[i].color
            
            -- Update border for all buttons
            for j, otherButton in ipairs(colorButtons) do
                otherButton.BorderColor3 = (j == i) 
                    and Color3.fromRGB(255, 255, 255)  -- White border if selected
                    or Color3.fromRGB(0, 0, 0)         -- Black border if not selected
            end
            
            -- Update visualizer if it's visible
            if VisualizerEnabled and HitboxVisualizer then
                UpdateHitboxVisualizer()
            end
        end)
    end
    
    -- Preset buttons event handlers
    for i, button in ipairs(presetButtons) do
        button.MouseButton1Click:Connect(function()
            -- Get preset data
            local presetName = presetNames[i]
            local presetData = PRESETS[presetName]
            
            -- Apply preset data to settings
            Settings.XOffset = presetData.XOffset
            Settings.YOffset = presetData.YOffset
            Settings.ZOffset = presetData.ZOffset
            Settings.XSize = presetData.XSize
            Settings.YSize = presetData.YSize
            Settings.ZSize = presetData.ZSize
            Settings.Size = presetData.Size
            
            -- Update all sliders
            UpdateSliderUI(XButton, XValue, XLabel, "X Offset", Settings.XOffset, MIN_OFFSET, MAX_OFFSET)
            UpdateSliderUI(YButton, YValue, YLabel, "Y Offset", Settings.YOffset, MIN_OFFSET, MAX_OFFSET)
            UpdateSliderUI(ZButton, ZValue, ZLabel, "Z Offset", Settings.ZOffset, MIN_OFFSET, MAX_OFFSET)
            UpdateSliderUI(XSizeButton, XSizeValue, XSizeLabel, "X Size", Settings.XSize, MIN_SIZE, MAX_SIZE)
            UpdateSliderUI(YSizeButton, YSizeValue, YSizeLabel, "Y Size", Settings.YSize, MIN_SIZE, MAX_SIZE)
            UpdateSliderUI(ZSizeButton, ZSizeValue, ZSizeLabel, "Z Size", Settings.ZSize, MIN_SIZE, MAX_SIZE)
            UpdateSliderUI(SizeButton, SizeValue, SizeLabel, "Overall Size", Settings.Size, MIN_SIZE, MAX_SIZE)
            
            -- Apply changes to the tool if enabled
            if ModifyingEnabled and CurrentTool then
                ApplyToolModifications()
            end
        end)
    end
    
    -- Generic slider drag handling function
    local function SetupSliderDrag(slider, valueBox, label, displayName, settingName, minVal, maxVal)
        local isSliding = false
        
        -- Handle mouse button down event
        slider.MouseButton1Down:Connect(function()
            isSliding = true
            
            -- Initial update to where clicked
            local function UpdateFromMousePosition()
                if not isSliding then return end
                
                -- Calculate relative position within the parent slider bar
                local mousePos = UserInputService:GetMouseLocation()
                local sliderPos = slider.Parent.AbsolutePosition
                local sliderSize = slider.Parent.AbsoluteSize
                
                local relativeX = math.clamp((mousePos.X - sliderPos.X) / sliderSize.X, 0, 1)
                local value = minVal + relativeX * (maxVal - minVal)
                value = math.floor(value * 10) / 10 -- Round to 1 decimal place
                
                -- Update settings and UI
                Settings[settingName] = value
                UpdateSliderUI(slider, valueBox, label, displayName, value, minVal, maxVal)
                
                -- Apply the change to the current tool if modifying is enabled
                if ModifyingEnabled and CurrentTool then
                    ApplyToolModifications()
                end
            end
            
            -- Update based on where clicked initially
            UpdateFromMousePosition()
            
            -- Connect mouse move event
            local moveConnection
            moveConnection = UserInputService.InputChanged:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseMovement then
                    UpdateFromMousePosition()
                end
            end)
            
            -- Handle mouse button up event
            local upConnection
            upConnection = UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    isSliding = false
                    moveConnection:Disconnect()
                    upConnection:Disconnect()
                end
            end)
        end)
        
        -- Handle direct value input through the text box
        valueBox.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                local inputValue = tonumber(valueBox.Text)
                if inputValue then
                    -- Clamp to valid range
                    inputValue = math.clamp(inputValue, minVal, maxVal)
                    
                    -- Update settings and UI
                    Settings[settingName] = inputValue
                    UpdateSliderUI(slider, valueBox, label, displayName, inputValue, minVal, maxVal)
                    
                    -- Apply the change to the current tool if modifying is enabled
                    if ModifyingEnabled and CurrentTool then
                        ApplyToolModifications()
                    end
                else
                    -- Restore previous value if input is not a valid number
                    valueBox.Text = tostring(Settings[settingName])
                end
            end
        end)
    end
    
    -- Set up all sliders
    SetupSliderDrag(XButton, XValue, XLabel, "X Offset", "XOffset", MIN_OFFSET, MAX_OFFSET)
    SetupSliderDrag(YButton, YValue, YLabel, "Y Offset", "YOffset", MIN_OFFSET, MAX_OFFSET)
    SetupSliderDrag(ZButton, ZValue, ZLabel, "Z Offset", "ZOffset", MIN_OFFSET, MAX_OFFSET)
    SetupSliderDrag(XSizeButton, XSizeValue, XSizeLabel, "X Size", "XSize", MIN_SIZE, MAX_SIZE)
    SetupSliderDrag(YSizeButton, YSizeValue, YSizeLabel, "Y Size", "YSize", MIN_SIZE, MAX_SIZE)
    SetupSliderDrag(ZSizeButton, ZSizeValue, ZSizeLabel, "Z Size", "ZSize", MIN_SIZE, MAX_SIZE)
    SetupSliderDrag(SizeButton, SizeValue, SizeLabel, "Overall Size", "Size", MIN_SIZE, MAX_SIZE)
    
    return ScreenGui
end

-- Main Setup
local gui = CreateGUI()

-- Set up character tool events
local function OnCharacterAdded(newCharacter)
    Character = newCharacter
    
    -- Connect to character's ChildAdded event to detect when tools are equipped
    Character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            OnToolEquipped(child)
        end
    end)
    
    -- Connect to character's ChildRemoved event to detect when tools are unequipped
    Character.ChildRemoved:Connect(function(child)
        if child:IsA("Tool") and child == CurrentTool then
            OnToolUnequipped()
        end
    end)
    
    -- Check if a tool is already equipped
    local existingTool = Character:FindFirstChildOfClass("Tool")
    if existingTool then
        OnToolEquipped(existingTool)
    end
end

-- Connect to the player's CharacterAdded event
Player.CharacterAdded:Connect(OnCharacterAdded)

-- Handle the case where the character is already loaded
if Character then
    OnCharacterAdded(Character)
end

-- Let the player know the script has loaded
print("Reach Modifier script loaded!")
