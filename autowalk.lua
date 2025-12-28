--[[
    ╔═══════════════════════════════════════════════════════════════╗
    ║                      GHOSTWALK v2.0                           ║
    ║              Auto Walk Recorder & Playback                    ║
    ║                 Aurora Nebula Interface                       ║
    ║                                                               ║
    ║  Features:                                                    ║
    ║  • 60 FPS Recording with velocity capture                     ║
    ║  • Advanced playback (Spline, Physics, AlignPosition)         ║
    ║  • DeltaTime-independent movement                             ║
    ║  • Catmull-Rom spline interpolation                           ║
    ║  • Humanization & anti-detection                              ║
    ║  • Fall recovery system                                       ║
    ╚═══════════════════════════════════════════════════════════════╝
]]

-- ==================== SCRIPT CLEANUP SYSTEM ====================
-- Kalo script dijalankan lagi, destroy yang lama dulu
if _G.GhostWalk then
    -- Destroy GUI
    if _G.GhostWalk.GUI then
        _G.GhostWalk.GUI:Destroy()
    end
    
    -- Disconnect semua connections
    if _G.GhostWalk.Connections then
        for _, conn in pairs(_G.GhostWalk.Connections) do
            if conn and typeof(conn) == "RBXScriptConnection" then
                conn:Disconnect()
            end
        end
    end
    
    -- Destroy Drawing objects (trail, etc)
    if _G.GhostWalk.Drawings then
        for _, drawing in pairs(_G.GhostWalk.Drawings) do
            if drawing and drawing.Remove then
                drawing:Remove()
            end
        end
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
    
    print("[GhostWalk] Script lama di-destroy, menjalankan yang baru...")
end

-- Initialize global storage untuk cleanup nanti
_G.GhostWalk = {
    Version = "2.0",
    GUI = nil,
    Connections = {},
    Drawings = {}
}

-- ==================== SERVICES ====================
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService") -- Untuk JSON encode/decode

-- ==================== PLAYER REFERENCES ====================
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- ==================== ADVANCED CONFIG ====================
local Config = {
    -- Recording Settings (Advanced)
    Recording = {
        Interval = 1/60, -- 60 FPS recording (high resolution)
        Enabled = false,
        CaptureVelocity = true, -- Record velocity for physics replay
        CaptureAnimState = true, -- Record humanoid states
        KeyframeExtraction = true, -- Extract only significant keyframes
        KeyframeThreshold = 0.5, -- Minimum distance for new keyframe (studs)
    },
    
    -- Playback Settings (Advanced)
    Playback = {
        Enabled = false,
        Loop = true,
        Speed = 1.0,
        Method = "Hybrid+", -- "Teleport", "Humanoid", "Hybrid", "Hybrid+", "Spline", "Physics", "AlignPosition"
        
        -- Interpolation Settings
        UseDeltaTime = true, -- Frame-independent movement
        SmoothFactor = 0.15, -- Lerp smoothness (lower = faster approach)
        UseSplineInterpolation = true, -- Catmull-Rom spline for curves
        
        -- Animation Sync
        SyncAnimation = true, -- Use Humanoid:Move() for natural animation
        AnimationSmoothing = 0.3, -- Animation blend factor
    },
    
    -- Smart Timeout (untuk moving platforms)
    SmartTimeout = {
        Enabled = true,
        Buffer = 0.2, -- +20% dari recorded wait time
        DefaultTimeout = 10, -- Default 10 detik kalau gak ada data
    },
    
    -- Fall Recovery
    FallRecovery = {
        Enabled = true,
        Threshold = 10, -- Studs, kalau lebih dari ini = jatuh
        SmartSpeed = true, -- Speed adjustment berdasarkan jarak
        MaxSpeedBoost = 1.5,
    },
    
    -- Predictive Jump System (for parkour) - DISABLED by default, use recorded timing
    PredictiveJump = {
        Enabled = false,             -- Master toggle (enable only for platformers with gaps)
        GapDetection = true,         -- Detect gaps ahead
        EdgeDetection = true,        -- Detect platform edges
        JumpArcCalc = false,         -- Calculate if jump can reach target (expensive)
        EarlyJumpDistance = 1.5,     -- Studs from edge to trigger jump (smaller = less aggressive)
        DebugPrint = false,          -- Print jump decisions
    },
    
    -- Visual
    Visuals = {
        ShowTrail = true,
        TrailFadeDuration = 5, -- Seconds
        ShowGUI = true,
        ShowSplinePath = false, -- Debug: show spline path
    },
    
    -- Practice Mode
    PracticeMode = {
        Enabled = false,
        AutoPause = true,
        ShowProgress = true,
    },
    
    -- Humanization (Anti-Detection)
    Humanization = {
        Enabled = true,
        SpeedVariance = 0.03, -- ±3% speed randomization
        MicroPauses = true, -- Occasional micro-stops
        MicroPauseChance = 0.001, -- 0.1% per frame
    },
    
    -- Keybinds
    Keybinds = {
        Record = Enum.KeyCode.R,
        Playback = Enum.KeyCode.P,
        Stop = Enum.KeyCode.X,
        ToggleGUI = Enum.KeyCode.RightShift,
        PracticeContinue = Enum.KeyCode.Space,
        QuickSave = Enum.KeyCode.F5,
        QuickLoad = Enum.KeyCode.F9,
    },
}

-- ==================== STATE MANAGEMENT ====================
local State = {
    -- Current mode
    Mode = "IDLE", -- "IDLE", "RECORDING", "PLAYING", "PAUSED"
    
    -- Recording data
    CurrentRecording = {
        metadata = {
            version = "1.0",
            recordedAt = 0,
            avatarHeight = 0,
            totalFrames = 0,
            duration = 0,
        },
        frames = {},
    },
    
    -- Playback state
    PlaybackIndex = 1,
    PlaybackStartTime = 0,
    LockedTarget = nil, -- Untuk platform tracking
    
    -- Practice mode
    CurrentObstacle = 0,
    TotalObstacles = 0,
    
    -- Saved routes
    SavedRoutes = {},
    CurrentRouteName = "Untitled",
    
    -- Advanced playback state
    SplineT = 0, -- Spline interpolation parameter (0-1)
    LastDeltaTime = 0,
    LastVelocity = Vector3.new(0, 0, 0),
    LastJumpTime = 0, -- For jump cooldown
    
    -- Savestate System
    Savestates = {}, -- Array of saved checkpoints
    CurrentSavestateIndex = 0,
    MaxSavestates = 10,
    
    -- Animation Tracking
    CurrentAnimationTrack = nil,
    AnimationPaused = false,
    LastAnimationId = "",
    LastAnimationTime = 0,
}

-- ==================== SPLINE & INTERPOLATION SYSTEM ====================

-- Catmull-Rom Spline Interpolation (for smooth curves)
local function catmullRom(p0, p1, p2, p3, t)
    local t2 = t * t
    local t3 = t2 * t
    return 0.5 * (
        (2 * p1) +
        (-p0 + p2) * t +
        (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 +
        (-p0 + 3 * p1 - 3 * p2 + p3) * t3
    )
end

-- CFrame version of Catmull-Rom (interpolates position and rotation)
local function catmullRomCFrame(cf0, cf1, cf2, cf3, t)
    local pos = catmullRom(cf0.Position, cf1.Position, cf2.Position, cf3.Position, t)
    -- For rotation, use standard Slerp between cf1 and cf2
    local rot = cf1:Lerp(cf2, t)
    return CFrame.new(pos) * (rot - rot.Position)
end

-- Frame-independent Lerp (from hasil_riset.md)
-- alpha = 1 - smoothFactor^dt (correct formula for consistent speed across framerates)
local function deltaLerp(current, target, smoothFactor, dt)
    local alpha = 1 - math.pow(1 - smoothFactor, dt * 60) -- Normalize to 60fps
    alpha = math.clamp(alpha, 0, 1)
    if typeof(current) == "Vector3" then
        return current:Lerp(target, alpha)
    elseif typeof(current) == "CFrame" then
        return current:Lerp(target, alpha)
    else
        return current + (target - current) * alpha
    end
end

-- Extract keyframes from raw frames (reduce data, keep important points)
local function extractKeyframes(frames, threshold)
    if #frames < 3 then return frames end
    threshold = threshold or Config.Recording.KeyframeThreshold
    
    local keyframes = {frames[1]} -- Always include first
    local lastKeyframe = frames[1]
    
    for i = 2, #frames - 1 do
        local frame = frames[i]
        local distance = (frame.position - lastKeyframe.position).Magnitude
        
        -- Add keyframe if: distance > threshold, or type changed, or jumping
        local typeChanged = frame.type ~= lastKeyframe.type
        local isJump = frame.type == "JUMP"
        
        if distance > threshold or typeChanged or isJump then
            table.insert(keyframes, frame)
            lastKeyframe = frame
        end
    end
    
    table.insert(keyframes, frames[#frames]) -- Always include last
    return keyframes
end

-- Get spline position at time t using 4 surrounding frames
local function getSplinePosition(frames, frameIndex, t)
    local p0 = frames[math.max(1, frameIndex - 1)]
    local p1 = frames[frameIndex]
    local p2 = frames[math.min(#frames, frameIndex + 1)]
    local p3 = frames[math.min(#frames, frameIndex + 2)]
    
    return catmullRom(p0.position, p1.position, p2.position, p3.position, t)
end

-- ==================== SAVESTATE SYSTEM ====================

-- Create a savestate (checkpoint)
local function createSavestate(name)
    local character = LocalPlayer.Character
    if not character then return nil end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return nil end
    
    local savestate = {
        name = name or ("Savestate_" .. (#State.Savestates + 1)),
        timestamp = tick(),
        
        -- Position & Movement
        position = hrp.Position,
        cframe = hrp.CFrame,
        velocity = hrp.AssemblyLinearVelocity,
        angularVelocity = hrp.AssemblyAngularVelocity,
        
        -- Humanoid state
        health = humanoid.Health,
        maxHealth = humanoid.MaxHealth,
        walkSpeed = humanoid.WalkSpeed,
        jumpPower = humanoid.JumpPower,
        humanoidState = humanoid:GetState().Name,
        
        -- Playback state (if playing)
        playbackIndex = State.PlaybackIndex,
        playbackMode = State.Mode,
        routeName = State.CurrentRouteName,
        
        -- Camera
        cameraCFrame = workspace.CurrentCamera.CFrame,
        cameraFocus = workspace.CurrentCamera.Focus,
    }
    
    -- Limit savestates
    if #State.Savestates >= State.MaxSavestates then
        table.remove(State.Savestates, 1) -- Remove oldest
    end
    
    table.insert(State.Savestates, savestate)
    State.CurrentSavestateIndex = #State.Savestates
    
    return savestate
end

-- Load a savestate
local function loadSavestate(index)
    local savestate = State.Savestates[index]
    if not savestate then 
        print("[GhostWalk] Savestate #" .. index .. " not found!")
        return false 
    end
    
    local character = LocalPlayer.Character
    if not character then 
        print("[GhostWalk] No character to load savestate!")
        return false 
    end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")
    if not hrp or not humanoid then 
        print("[GhostWalk] Missing HumanoidRootPart or Humanoid!")
        return false 
    end
    
    -- Position & Movement (most critical - wrap in pcall)
    local success = pcall(function()
        hrp.CFrame = savestate.cframe
    end)
    
    if not success then
        print("[GhostWalk] Failed to set CFrame!")
        return false
    end
    
    -- Velocity (optional, may fail)
    pcall(function()
        if savestate.velocity then
            hrp.AssemblyLinearVelocity = savestate.velocity
        end
        if savestate.angularVelocity then
            hrp.AssemblyAngularVelocity = savestate.angularVelocity
        end
    end)
    
    -- Humanoid state (optional)
    pcall(function()
        if savestate.health then humanoid.Health = savestate.health end
        if savestate.walkSpeed then humanoid.WalkSpeed = savestate.walkSpeed end
        if savestate.jumpPower then humanoid.JumpPower = savestate.jumpPower end
    end)
    
    -- Playback state
    if savestate.playbackIndex then
        State.PlaybackIndex = savestate.playbackIndex
    end
    
    -- Camera (optional, may fail in some games)
    pcall(function()
        if savestate.cameraCFrame then
            workspace.CurrentCamera.CFrame = savestate.cameraCFrame
        end
    end)
    
    State.CurrentSavestateIndex = index
    print("[GhostWalk] ✅ Loaded savestate: " .. (savestate.name or "Unknown"))
    return true
end

-- Delete a savestate
local function deleteSavestate(index)
    if State.Savestates[index] then
        table.remove(State.Savestates, index)
        if State.CurrentSavestateIndex >= index then
            State.CurrentSavestateIndex = math.max(0, State.CurrentSavestateIndex - 1)
        end
        return true
    end
    return false
end

-- Get savestate list for GUI
local function getSavestateList()
    local list = {}
    for i, ss in ipairs(State.Savestates) do
        table.insert(list, {
            index = i,
            name = ss.name,
            time = os.date("%H:%M:%S", ss.timestamp),
            position = ss.position,
        })
    end
    return list
end

-- Quick save (last savestate)
local function quickSave()
    return createSavestate("QuickSave_" .. os.date("%H%M%S"))
end

-- Quick load (last savestate)
local function quickLoad()
    if #State.Savestates > 0 then
        return loadSavestate(#State.Savestates)
    end
    return false
end

-- ==================== ANIMATION SYNC SYSTEM ====================

-- Get current animation info
local function getCurrentAnimationInfo()
    local character = LocalPlayer.Character
    if not character then return nil end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return nil end
    
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then return nil end
    
    local tracks = animator:GetPlayingAnimationTracks()
    if #tracks == 0 then return nil end
    
    -- Get the most relevant track (usually the one with highest priority or weight)
    local mainTrack = tracks[1]
    for _, track in ipairs(tracks) do
        if track.WeightCurrent > mainTrack.WeightCurrent then
            mainTrack = track
        end
    end
    
    return {
        animationId = mainTrack.Animation and mainTrack.Animation.AnimationId or "",
        timePosition = mainTrack.TimePosition,
        speed = mainTrack.Speed,
        weight = mainTrack.WeightCurrent,
        isPlaying = mainTrack.IsPlaying,
        length = mainTrack.Length,
    }
end

-- Pause all animations
local function pauseAnimations()
    local character = LocalPlayer.Character
    if not character then return end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then return end
    
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        track:AdjustSpeed(0)
    end
    
    State.AnimationPaused = true
end

-- Resume all animations
local function resumeAnimations()
    local character = LocalPlayer.Character
    if not character then return end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then return end
    
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        track:AdjustSpeed(1)
    end
    
    State.AnimationPaused = false
end

-- Sync animation to recorded state
local function syncAnimationToFrame(frame)
    if not frame.animationId or frame.animationId == "" then return end
    if not Config.Playback.SyncAnimation then return end
    
    local character = LocalPlayer.Character
    if not character then return end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then return end
    
    -- Check if we need to load new animation
    if State.LastAnimationId ~= frame.animationId then
        -- Stop current track if exists
        if State.CurrentAnimationTrack then
            State.CurrentAnimationTrack:Stop()
        end
        
        -- Load new animation
        pcall(function()
            local animation = Instance.new("Animation")
            animation.AnimationId = frame.animationId
            State.CurrentAnimationTrack = animator:LoadAnimation(animation)
            State.CurrentAnimationTrack:Play()
        end)
        
        State.LastAnimationId = frame.animationId
    end
    
    -- Sync time position
    if State.CurrentAnimationTrack and frame.animationTime then
        local timeDiff = math.abs(State.CurrentAnimationTrack.TimePosition - frame.animationTime)
        if timeDiff > 0.1 then -- Only sync if significantly different
            State.CurrentAnimationTrack.TimePosition = frame.animationTime
        end
    end
end

-- ==================== HELPER FUNCTIONS ====================

-- Get avatar height (HRP to ground)
local function getAvatarHeight()
    if not LocalPlayer.Character then return 3 end
    local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return 3 end
    
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    
    local result = workspace:Raycast(hrp.Position, Vector3.new(0, -20, 0), rayParams)
    if result then
        return hrp.Position.Y - result.Position.Y
    end
    return 3 -- Default
end

-- Get ground Y position
local function getGroundY(position)
    local rayParams = RaycastParams.new()
    if LocalPlayer.Character then
        rayParams.FilterDescendantsInstances = {LocalPlayer.Character}
    end
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    
    local result = workspace:Raycast(position + Vector3.new(0, 5, 0), Vector3.new(0, -50, 0), rayParams)
    if result then
        return result.Position.Y
    end
    return position.Y - 3 -- Fallback
end

-- Check if player is grounded
local function isGrounded()
    if not LocalPlayer.Character then return false end
    local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
    if not humanoid then return false end
    
    local state = humanoid:GetState()
    return state ~= Enum.HumanoidStateType.Freefall and 
           state ~= Enum.HumanoidStateType.Jumping
end

-- Get part player is standing on
local function getGroundPart()
    if not LocalPlayer.Character then return nil end
    local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    
    local result = workspace:Raycast(hrp.Position, Vector3.new(0, -10, 0), rayParams)
    if result then
        return result.Instance
    end
    return nil
end

-- Check if part is moving (for platform detection)
local function isPartMoving(part)
    if not part then return false end
    
    -- Check velocity
    if part:IsA("BasePart") and part.AssemblyLinearVelocity.Magnitude > 0.1 then
        return true
    end
    
    -- Check if has any animation/tween (simplified check)
    -- Later can add more sophisticated detection
    
    return false
end

-- ==================== PREDICTIVE JUMP SYSTEM ====================

-- Jump physics constants (Roblox defaults)
local GRAVITY = workspace.Gravity or 196.2
local DEFAULT_JUMP_POWER = 50

-- Raycast helper that excludes character
local function safeRaycast(origin, direction)
    local rayParams = RaycastParams.new()
    if LocalPlayer.Character then
        rayParams.FilterDescendantsInstances = {LocalPlayer.Character}
    end
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    return workspace:Raycast(origin, direction, rayParams)
end

-- Check if there's a gap ahead (no ground in front)
local function detectGapAhead(hrp, moveDirection, checkDistance)
    checkDistance = checkDistance or 4
    
    -- Raycast forward at foot level
    local footOffset = Vector3.new(0, -2.5, 0) -- Approximate foot position
    local checkPos = hrp.Position + footOffset + moveDirection * checkDistance
    
    -- Raycast down from the forward position
    local downResult = safeRaycast(checkPos + Vector3.new(0, 2, 0), Vector3.new(0, -10, 0))
    
    if not downResult then
        -- No ground ahead = gap detected
        return true, nil, math.huge
    end
    
    -- Check if ground ahead is much lower (drop)
    local currentGroundY = getGroundY(hrp.Position)
    local aheadGroundY = downResult.Position.Y
    local dropDistance = currentGroundY - aheadGroundY
    
    if dropDistance > 5 then
        -- Significant drop ahead
        return true, downResult.Position, dropDistance
    end
    
    return false, downResult.Position, dropDistance
end

-- Detect if approaching platform edge
local function detectEdge(hrp, moveDirection)
    -- Check multiple points ahead at different distances
    local edgeDistances = {1.5, 2.5, 3.5, 4.5}
    local footOffset = Vector3.new(0, -2.5, 0)
    
    for _, dist in ipairs(edgeDistances) do
        local checkPos = hrp.Position + footOffset + moveDirection * dist
        local downResult = safeRaycast(checkPos + Vector3.new(0, 1, 0), Vector3.new(0, -5, 0))
        
        if not downResult then
            -- Found edge at this distance
            return true, dist
        end
    end
    
    return false, nil
end

-- Calculate if a jump can reach target position
-- Uses projectile motion: y = y0 + vy*t - 0.5*g*t^2, x = x0 + vx*t
local function canJumpReachTarget(startPos, targetPos, jumpPower, walkSpeed)
    jumpPower = jumpPower or DEFAULT_JUMP_POWER
    walkSpeed = walkSpeed or 16
    
    local horizontalDist = math.sqrt((targetPos.X - startPos.X)^2 + (targetPos.Z - startPos.Z)^2)
    local verticalDist = targetPos.Y - startPos.Y
    
    -- Time to reach max height
    local timeToApex = jumpPower / GRAVITY
    local maxHeight = (jumpPower * jumpPower) / (2 * GRAVITY)
    
    -- Time to travel horizontal distance at walkSpeed
    local horizontalTime = horizontalDist / walkSpeed
    
    -- Height at that horizontal time (if jumped at t=0)
    local heightAtTarget = jumpPower * horizontalTime - 0.5 * GRAVITY * horizontalTime * horizontalTime
    
    -- Can reach if height at target time is greater than required height
    -- Add some margin for landing
    return heightAtTarget >= verticalDist - 1, heightAtTarget, horizontalTime
end

-- Find the next platform/ground ahead
local function findNextPlatform(hrp, moveDirection, maxDistance)
    maxDistance = maxDistance or 20
    
    -- Raycast forward at multiple heights
    local heights = {0, 2, 4, 6}
    local nearestPlatform = nil
    local nearestDist = math.huge
    
    for _, heightOffset in ipairs(heights) do
        local origin = hrp.Position + Vector3.new(0, heightOffset, 0)
        
        -- Raycast in an arc pattern (forward + slightly down)
        for angle = 0, 45, 15 do
            local radAngle = math.rad(-angle) -- Negative for downward
            local direction = (moveDirection + Vector3.new(0, math.tan(radAngle), 0)).Unit * maxDistance
            
            local result = safeRaycast(origin, direction)
            if result and result.Instance:IsA("BasePart") then
                local dist = (result.Position - hrp.Position).Magnitude
                if dist < nearestDist and dist > 2 then -- Ignore ground right below
                    nearestDist = dist
                    nearestPlatform = {
                        position = result.Position,
                        part = result.Instance,
                        distance = dist,
                        normal = result.Normal
                    }
                end
            end
        end
    end
    
    return nearestPlatform
end

-- Calculate optimal jump timing
-- Returns: shouldJump, jumpDelay, reason
local function calculateJumpTiming(hrp, moveDirection, targetPos, humanoid)
    local walkSpeed = humanoid and humanoid.WalkSpeed or 16
    local jumpPower = humanoid and humanoid.JumpPower or DEFAULT_JUMP_POWER
    
    -- 1. Check for gap ahead (if enabled)
    local hasGap, gapPos, dropDist = false, nil, 0
    if Config.PredictiveJump.GapDetection then
        hasGap, gapPos, dropDist = detectGapAhead(hrp, moveDirection, 4)
    end
    
    -- 2. Check for edge approaching (if enabled)
    local nearEdge, edgeDist = false, nil
    if Config.PredictiveJump.EdgeDetection then
        nearEdge, edgeDist = detectEdge(hrp, moveDirection)
    end
    
    -- 3. Find next platform (for arc calculation)
    local nextPlatform = nil
    if Config.PredictiveJump.JumpArcCalc then
        nextPlatform = findNextPlatform(hrp, moveDirection, 15)
    end
    
    -- Decision logic
    if hasGap or nearEdge then
        local distToEdge = edgeDist or 4
        local earlyDist = Config.PredictiveJump.EarlyJumpDistance or 2.5
        
        -- Calculate if we should jump now
        if distToEdge < earlyDist then
            -- Very close to edge - jump NOW
            if nextPlatform and Config.PredictiveJump.JumpArcCalc then
                local canReach, _, _ = canJumpReachTarget(hrp.Position, nextPlatform.position, jumpPower, walkSpeed)
                if canReach then
                    return true, 0, "approaching_edge_can_reach"
                else
                    return true, 0, "approaching_edge_must_try"
                end
            else
                return true, 0, "approaching_edge_no_calc"
            end
        elseif distToEdge < earlyDist + 1.5 then
            -- Getting close - prepare but don't jump yet
            return false, distToEdge / walkSpeed, "preparing_for_edge"
        end
    end
    
    -- 4. Check target position (recorded frame)
    if targetPos then
        local heightDiff = targetPos.Y - hrp.Position.Y
        local horizontalDist = math.sqrt((targetPos.X - hrp.Position.X)^2 + (targetPos.Z - hrp.Position.Z)^2)
        
        -- Need to jump if target is significantly higher and we're close
        if heightDiff > 2 and horizontalDist < 5 then
            local canReach, _, _ = canJumpReachTarget(hrp.Position, targetPos, jumpPower, walkSpeed)
            if canReach then
                return true, 0, "target_higher_can_reach"
            end
        end
    end
    
    return false, 0, "no_jump_needed"
end

-- Smart Jump Trigger with predictive logic
local function smartTriggerJump(hrp, humanoid, moveDirection, targetPos, recordedVelocityY)
    -- Check if predictive jump is enabled
    if not Config.PredictiveJump.Enabled then
        return false
    end
    
    if not humanoid then return false end
    
    -- Already airborne?
    local state = humanoid:GetState()
    if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
        return false
    end
    
    -- Cooldown check (500ms to prevent spam)
    local now = tick()
    local lastJump = State.LastJumpTime or 0
    if now - lastJump < 0.5 then -- 500ms cooldown
        return false
    end
    
    -- Calculate if we should jump
    local shouldJump, _, reason = calculateJumpTiming(hrp, moveDirection, targetPos, humanoid)
    
    if shouldJump then
        State.LastJumpTime = now
        
        -- Use recorded velocity if available and reasonable
        local jumpPower = humanoid.JumpPower or DEFAULT_JUMP_POWER
        if recordedVelocityY and recordedVelocityY > jumpPower * 0.5 then
            jumpPower = math.max(jumpPower, recordedVelocityY)
        end
        
        -- Multiple jump methods for compatibility
        humanoid.Jump = true
        
        pcall(function()
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
        
        pcall(function()
            hrp.AssemblyLinearVelocity = Vector3.new(
                hrp.AssemblyLinearVelocity.X,
                jumpPower,
                hrp.AssemblyLinearVelocity.Z
            )
        end)
        
        pcall(function()
            local vim = game:GetService("VirtualInputManager")
            if vim then
                vim:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                task.delay(0.1, function()
                    vim:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                end)
            end
        end)
        
        -- Debug
        if Config.PredictiveJump.DebugPrint then
            print("[GhostWalk] Smart Jump: " .. reason)
        end
        
        return true
    end
    
    return false
end

-- ==================== PRINT INFO ====================
print("═══════════════════════════════════════════")
print("  GhostWalk v" .. _G.GhostWalk.Version .. " Loaded!")
print("  Press RightShift to toggle GUI")
print("  Press R to start/stop recording")
print("  Press P to start/stop playback")
print("═══════════════════════════════════════════")

-- ==================== AURORA NEBULA COLOR SYSTEM ====================
local Colors = {
    -- Base Gradient (animated background)
    GradientStart = Color3.fromRGB(30, 60, 114),    -- Deep blue
    GradientMid = Color3.fromRGB(42, 82, 152),      -- Royal blue
    GradientEnd = Color3.fromRGB(0, 212, 255),      -- Cyan
    GradientAccent = Color3.fromRGB(102, 126, 234), -- Purple accent
    
    -- Glass Effect Colors
    Background = Color3.fromRGB(15, 20, 35),        -- Deep space blue
    Sidebar = Color3.fromRGB(20, 28, 50),           -- Slightly lighter
    Card = Color3.fromRGB(30, 40, 70),              -- Glass card
    CardHover = Color3.fromRGB(40, 55, 95),         -- Hover state
    CardActive = Color3.fromRGB(50, 70, 120),       -- Active state
    
    -- Glass Border
    GlassBorder = Color3.fromRGB(80, 120, 200),     -- Subtle glow border
    GlassBorderActive = Color3.fromRGB(100, 200, 255), -- Active glow
    
    -- Tab-Specific Gradients
    TabHome = {Color3.fromRGB(0, 200, 255), Color3.fromRGB(50, 100, 200), Color3.fromRGB(100, 50, 180)},
    TabRecord = {Color3.fromRGB(255, 100, 100), Color3.fromRGB(255, 50, 150), Color3.fromRGB(200, 50, 200)},
    TabPlayback = {Color3.fromRGB(100, 255, 150), Color3.fromRGB(50, 200, 150), Color3.fromRGB(50, 150, 200)},
    TabRoutes = {Color3.fromRGB(50, 150, 255), Color3.fromRGB(100, 200, 230), Color3.fromRGB(255, 200, 100)},
    TabSettings = {Color3.fromRGB(150, 150, 180), Color3.fromRGB(100, 130, 200), Color3.fromRGB(200, 200, 220)},
    
    -- Accent Colors
    Accent = Color3.fromRGB(0, 220, 255),           -- Bright cyan
    AccentGlow = Color3.fromRGB(100, 200, 255),     -- Glow effect
    AccentDark = Color3.fromRGB(0, 150, 200),
    
    -- Status Colors
    Red = Color3.fromRGB(255, 80, 100),
    Green = Color3.fromRGB(100, 255, 150),
    Yellow = Color3.fromRGB(255, 220, 100),
    Orange = Color3.fromRGB(255, 150, 50),
    Purple = Color3.fromRGB(180, 100, 255),
    
    -- Text Colors
    TextPrimary = Color3.fromRGB(255, 255, 255),
    TextGlow = Color3.fromRGB(150, 220, 255),
    TextSecondary = Color3.fromRGB(160, 175, 200),
    TextMuted = Color3.fromRGB(100, 115, 140),
}

-- ==================== GUI CREATION ====================

-- ScreenGui
local gui = Instance.new("ScreenGui")
gui.Name = "GhostWalk"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Register untuk cleanup
_G.GhostWalk.GUI = gui

-- Main Frame
local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 600, 0, 450)
main.Position = UDim2.new(0.5, -300, 0.5, -225)
main.BackgroundColor3 = Colors.Background
main.BorderSizePixel = 0
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)

-- Shadow (fake, using another frame)
local shadow = Instance.new("Frame")
shadow.Name = "Shadow"
shadow.Size = UDim2.new(1, 20, 1, 20)
shadow.Position = UDim2.new(0, -10, 0, -10)
shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
shadow.BackgroundTransparency = 0.5
shadow.BorderSizePixel = 0
shadow.ZIndex = -1
shadow.Parent = main
Instance.new("UICorner", shadow).CornerRadius = UDim.new(0, 16)

-- Titlebar
local titlebar = Instance.new("Frame")
titlebar.Name = "Titlebar"
titlebar.Size = UDim2.new(1, 0, 0, 40)
titlebar.BackgroundTransparency = 1
titlebar.Parent = main

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -60, 1, 0)
titleText.Position = UDim2.new(0, 15, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "👻 GhostWalk"
titleText.TextColor3 = Colors.TextPrimary
titleText.Font = Enum.Font.GothamBold
titleText.TextSize = 16
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Parent = titlebar

-- Close Button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -35, 0, 5)
closeBtn.BackgroundColor3 = Colors.Red
closeBtn.BackgroundTransparency = 0.8
closeBtn.Text = "✕"
closeBtn.TextColor3 = Colors.TextPrimary
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.Parent = titlebar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

closeBtn.MouseButton1Click:Connect(function()
    main.Visible = false
end)

-- Drag System (titlebar only)
local dragging, dragInput, dragStart, startPos

titlebar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
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

titlebar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

UIS.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- ==================== SIDEBAR ====================
local sidebar = Instance.new("Frame")
sidebar.Name = "Sidebar"
sidebar.Size = UDim2.new(0, 140, 1, -40)
sidebar.Position = UDim2.new(0, 0, 0, 40)
sidebar.BackgroundColor3 = Colors.Sidebar
sidebar.BorderSizePixel = 0
sidebar.Parent = main
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 0)

-- Sidebar tabs config
local tabs = {
    { name = "Home", icon = "🏠" },
    { name = "Record", icon = "🔴" },
    { name = "Playback", icon = "▶️" },
    { name = "Editor", icon = "📝" },
    { name = "Routes", icon = "💾" },
    { name = "Settings", icon = "⚙️" },
}

local tabButtons = {}
local tabPages = {}
local activeTab = "Home"

-- Create tab buttons
for i, tab in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Name = tab.name .. "Tab"
    btn.Size = UDim2.new(1, -10, 0, 40)
    btn.Position = UDim2.new(0, 5, 0, 5 + (i - 1) * 45)
    btn.BackgroundColor3 = Colors.Card
    btn.BackgroundTransparency = 1
    btn.Text = tab.icon .. "  " .. tab.name
    btn.TextColor3 = Colors.TextSecondary
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = sidebar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    
    local padding = Instance.new("UIPadding", btn)
    padding.PaddingLeft = UDim.new(0, 12)
    
    tabButtons[tab.name] = btn
end

-- ==================== CONTENT AREA ====================
local content = Instance.new("Frame")
content.Name = "Content"
content.Size = UDim2.new(1, -140, 1, -40)
content.Position = UDim2.new(0, 140, 0, 40)
content.BackgroundTransparency = 1
content.Parent = main

-- ==================== TAB PAGES ====================

-- Create page for each tab
for _, tab in ipairs(tabs) do
    local page = Instance.new("ScrollingFrame")
    page.Name = tab.name .. "Page"
    page.Size = UDim2.new(1, -20, 1, -20)
    page.Position = UDim2.new(0, 10, 0, 10)
    page.BackgroundTransparency = 1
    page.ScrollBarThickness = 4
    page.ScrollBarImageColor3 = Colors.Accent
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = (tab.name == "Home")
    page.Parent = content
    
    local layout = Instance.new("UIListLayout", page)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    
    tabPages[tab.name] = page
end

-- ==================== TAB SWITCHING ====================
local function switchTab(tabName)
    activeTab = tabName
    
    for name, page in pairs(tabPages) do
        page.Visible = (name == tabName)
    end
    
    for name, btn in pairs(tabButtons) do
        if name == tabName then
            btn.BackgroundTransparency = 0
            btn.BackgroundColor3 = Colors.Accent
            btn.TextColor3 = Colors.TextPrimary
        else
            btn.BackgroundTransparency = 1
            btn.TextColor3 = Colors.TextSecondary
        end
    end
end

-- Connect tab buttons
for name, btn in pairs(tabButtons) do
    btn.MouseButton1Click:Connect(function()
        switchTab(name)
    end)
end

-- Initial tab
switchTab("Home")

-- ==================== UI HELPER FUNCTIONS ====================

-- Helper: Create Section Label
local function createLabel(parent, text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 30)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Colors.Accent
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = parent
    
    local padding = Instance.new("UIPadding", label)
    padding.PaddingLeft = UDim.new(0, 5)
    
    return label
end

-- Helper: Create Toggle
local function createToggle(parent, text, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 35)
    frame.BackgroundColor3 = Colors.Card
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Colors.TextPrimary
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    
    local toggleBg = Instance.new("Frame")
    toggleBg.Size = UDim2.new(0, 44, 0, 22)
    toggleBg.Position = UDim2.new(1, -54, 0.5, -11)
    toggleBg.BackgroundColor3 = default and Colors.Accent or Colors.CardHover
    toggleBg.Parent = frame
    Instance.new("UICorner", toggleBg).CornerRadius = UDim.new(1, 0)
    
    local toggleCircle = Instance.new("Frame")
    toggleCircle.Size = UDim2.new(0, 18, 0, 18)
    toggleCircle.Position = UDim2.new(0, default and 24 or 2, 0, 2)
    toggleCircle.BackgroundColor3 = Colors.TextPrimary
    toggleCircle.Parent = toggleBg
    Instance.new("UICorner", toggleCircle).CornerRadius = UDim.new(1, 0)
    
    local enabled = default
    
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = frame
    
    btn.MouseButton1Click:Connect(function()
        enabled = not enabled
        
        TweenService:Create(toggleBg, TweenInfo.new(0.2), {
            BackgroundColor3 = enabled and Colors.Accent or Colors.CardHover
        }):Play()
        
        TweenService:Create(toggleCircle, TweenInfo.new(0.2), {
            Position = UDim2.new(0, enabled and 24 or 2, 0, 2)
        }):Play()
        
        if callback then callback(enabled) end
    end)
    
    return frame
end

-- Helper: Create Button
local function createButton(parent, text, color, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 120, 0, 38)
    btn.BackgroundColor3 = color or Colors.Accent
    btn.Text = text
    btn.TextColor3 = Colors.TextPrimary
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    
    btn.MouseButton1Click:Connect(function()
        if callback then callback() end
    end)
    
    return btn
end

-- Helper: Create Slider
local function createSlider(parent, text, min, max, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 50)
    frame.BackgroundColor3 = Colors.Card
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 0, 25)
    label.Position = UDim2.new(0, 12, 0, 3)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Colors.TextPrimary
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    
    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0.3, 0, 0, 25)
    valueLabel.Position = UDim2.new(0.7, -12, 0, 3)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = tostring(default)
    valueLabel.TextColor3 = Colors.Accent
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextSize = 13
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = frame
    
    local sliderBg = Instance.new("Frame")
    sliderBg.Size = UDim2.new(1, -24, 0, 6)
    sliderBg.Position = UDim2.new(0, 12, 0, 35)
    sliderBg.BackgroundColor3 = Colors.CardHover
    sliderBg.Parent = frame
    Instance.new("UICorner", sliderBg).CornerRadius = UDim.new(1, 0)
    
    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    sliderFill.BackgroundColor3 = Colors.Accent
    sliderFill.Parent = sliderBg
    Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(1, 0)
    
    local sliderDragging = false
    
    sliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliderDragging = true
        end
    end)
    
    sliderBg.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliderDragging = false
        end
    end)
    
    UIS.InputChanged:Connect(function(input)
        if sliderDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local rel = math.clamp((input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
            local value = math.floor(min + (max - min) * rel)
            sliderFill.Size = UDim2.new(rel, 0, 1, 0)
            valueLabel.Text = tostring(value)
            if callback then callback(value) end
        end
    end)
    
    return frame
end

-- Helper: Create Status Badge
local function createStatusBadge(parent)
    local badge = Instance.new("TextLabel")
    badge.Size = UDim2.new(0, 100, 0, 26)
    badge.BackgroundColor3 = Colors.CardHover
    badge.Text = "IDLE"
    badge.TextColor3 = Colors.TextSecondary
    badge.Font = Enum.Font.GothamBold
    badge.TextSize = 12
    badge.Parent = parent
    Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 13)
    
    return badge
end

-- Helper: Create Dropdown
local function createDropdown(parent, text, options, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 35)
    frame.BackgroundColor3 = Colors.Card
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.5, 0, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Colors.TextPrimary
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    
    local dropBtn = Instance.new("TextButton")
    dropBtn.Size = UDim2.new(0.45, -10, 0, 26)
    dropBtn.Position = UDim2.new(0.55, 0, 0, 4)
    dropBtn.BackgroundColor3 = Colors.CardHover
    dropBtn.Text = default .. " ▼"
    dropBtn.TextColor3 = Colors.Accent
    dropBtn.Font = Enum.Font.GothamBold
    dropBtn.TextSize = 12
    dropBtn.Parent = frame
    Instance.new("UICorner", dropBtn).CornerRadius = UDim.new(0, 6)
    
    local isOpen = false
    local optionFrames = {}
    
    -- Parent to gui directly to avoid ScrollingFrame clipping
    local optionsContainer = Instance.new("Frame")
    optionsContainer.Size = UDim2.new(0, 120, 0, #options * 28)
    optionsContainer.BackgroundColor3 = Colors.Sidebar
    optionsContainer.Visible = false
    optionsContainer.ZIndex = 100
    optionsContainer.Parent = gui -- Parent to main GUI, not frame
    Instance.new("UICorner", optionsContainer).CornerRadius = UDim.new(0, 6)
    
    -- Update dropdown position based on button position
    local function updateDropdownPosition()
        local absPos = dropBtn.AbsolutePosition
        local absSize = dropBtn.AbsoluteSize
        optionsContainer.Position = UDim2.new(0, absPos.X, 0, absPos.Y + absSize.Y + 2)
    end
    
    for i, option in ipairs(options) do
        local optBtn = Instance.new("TextButton")
        optBtn.Size = UDim2.new(1, -4, 0, 26)
        optBtn.Position = UDim2.new(0, 2, 0, (i-1) * 28 + 1)
        optBtn.BackgroundColor3 = Colors.Card
        optBtn.BackgroundTransparency = 0.3
        optBtn.Text = option
        optBtn.TextColor3 = Colors.TextPrimary
        optBtn.Font = Enum.Font.Gotham
        optBtn.TextSize = 12
        optBtn.ZIndex = 101
        optBtn.Parent = optionsContainer
        Instance.new("UICorner", optBtn).CornerRadius = UDim.new(0, 4)
        
        optBtn.MouseButton1Click:Connect(function()
            dropBtn.Text = option .. " ▼"
            optionsContainer.Visible = false
            isOpen = false
            if callback then callback(option) end
        end)
        
        table.insert(optionFrames, optBtn)
    end
    
    dropBtn.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        if isOpen then
            updateDropdownPosition()
        end
        optionsContainer.Visible = isOpen
    end)
    
    return frame
end

-- Helper: Create Stat Card
local function createStatCard(parent, label, value)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(0, 130, 0, 60)
    card.BackgroundColor3 = Colors.Card
    card.Parent = parent
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
    
    local valLabel = Instance.new("TextLabel")
    valLabel.Name = "Value"
    valLabel.Size = UDim2.new(1, 0, 0, 30)
    valLabel.Position = UDim2.new(0, 0, 0, 8)
    valLabel.BackgroundTransparency = 1
    valLabel.Text = tostring(value)
    valLabel.TextColor3 = Colors.Accent
    valLabel.Font = Enum.Font.GothamBold
    valLabel.TextSize = 20
    valLabel.Parent = card
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0, 20)
    nameLabel.Position = UDim2.new(0, 0, 0, 35)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = label
    nameLabel.TextColor3 = Colors.TextSecondary
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.TextSize = 11
    nameLabel.Parent = card
    
    return card
end

-- ==================== POPULATE HOME TAB ====================
local homePage = tabPages["Home"]

-- Status Section
createLabel(homePage, "Status")

local statusContainer = Instance.new("Frame")
statusContainer.Size = UDim2.new(1, -10, 0, 80)
statusContainer.BackgroundColor3 = Colors.Card
statusContainer.Parent = homePage
Instance.new("UICorner", statusContainer).CornerRadius = UDim.new(0, 8)

local statusBadge = createStatusBadge(statusContainer)
statusBadge.Position = UDim2.new(0.5, -50, 0, 10)

local routeLabel = Instance.new("TextLabel")
routeLabel.Size = UDim2.new(1, 0, 0, 20)
routeLabel.Position = UDim2.new(0, 0, 0, 45)
routeLabel.BackgroundTransparency = 1
routeLabel.Text = "Route: " .. State.CurrentRouteName
routeLabel.TextColor3 = Colors.TextSecondary
routeLabel.Font = Enum.Font.Gotham
routeLabel.TextSize = 12
routeLabel.Parent = statusContainer

-- Stats Section
createLabel(homePage, "Statistics")

local statsRow = Instance.new("Frame")
statsRow.Size = UDim2.new(1, -10, 0, 70)
statsRow.BackgroundTransparency = 1
statsRow.Parent = homePage

local statsLayout = Instance.new("UIListLayout", statsRow)
statsLayout.FillDirection = Enum.FillDirection.Horizontal
statsLayout.Padding = UDim.new(0, 10)

local framesStat = createStatCard(statsRow, "Frames", 0)
local durationStat = createStatCard(statsRow, "Duration", "0.0s")
local routesStat = createStatCard(statsRow, "Routes", #State.SavedRoutes)

-- Quick Actions
createLabel(homePage, "Quick Actions")

local actionsRow = Instance.new("Frame")
actionsRow.Size = UDim2.new(1, -10, 0, 45)
actionsRow.BackgroundTransparency = 1
actionsRow.Parent = homePage

local actionsLayout = Instance.new("UIListLayout", actionsRow)
actionsLayout.FillDirection = Enum.FillDirection.Horizontal
actionsLayout.Padding = UDim.new(0, 10)

local recordBtn = createButton(actionsRow, "🔴 Record", Colors.Red, function()
    print("[GhostWalk] Record clicked")
    -- Recording logic will be added later
end)

local playBtn = createButton(actionsRow, "▶️ Play", Colors.Green, function()
    print("[GhostWalk] Play clicked")
    -- Playback logic will be added later
end)

local stopBtn = createButton(actionsRow, "⏹️ Stop", Colors.CardHover, function()
    print("[GhostWalk] Stop clicked")
    -- Stop logic will be added later
end)

-- Quick Settings
createLabel(homePage, "Quick Settings")

createToggle(homePage, "Loop Playback", Config.Playback.Loop, function(v)
    Config.Playback.Loop = v
end)

createToggle(homePage, "Show Trail", Config.Visuals.ShowTrail, function(v)
    Config.Visuals.ShowTrail = v
end)

createToggle(homePage, "Practice Mode", Config.PracticeMode.Enabled, function(v)
    Config.PracticeMode.Enabled = v
end)

-- ==================== KEYBINDS ====================
local toggleGuiConn = UIS.InputBegan:Connect(function(input)
    if input.KeyCode == Config.Keybinds.ToggleGUI then
        main.Visible = not main.Visible
    end
end)
table.insert(_G.GhostWalk.Connections, toggleGuiConn)

-- ==================== RECORDING SYSTEM ====================

local recordingConnection = nil
local lastRecordTime = 0
local recordStartTime = 0

-- Frame types
local FrameType = {
    MOVE = "MOVE",
    JUMP = "JUMP",
    STAIRS = "STAIRS",
    PLATFORM = "PLATFORM",
}

-- Auto-detect frame type
local function detectFrameType()
    if not LocalPlayer.Character then return FrameType.MOVE end
    local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
    if not humanoid then return FrameType.MOVE end
    
    local state = humanoid:GetState()
    
    -- Detect Jump
    if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
        return FrameType.JUMP
    end
    
    -- Detect Platform (standing on moving part)
    local groundPart = getGroundPart()
    if groundPart and isPartMoving(groundPart) then
        return FrameType.PLATFORM
    end
    
    -- Detect Stairs (Y increasing gradually while walking)
    -- This is tracked over multiple frames in the recording logic
    
    return FrameType.MOVE
end

-- Get jump phase
local function getJumpPhase()
    if not LocalPlayer.Character then return nil end
    local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
    local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp then return nil end
    
    local state = humanoid:GetState()
    local velocity = hrp.AssemblyLinearVelocity
    
    if state == Enum.HumanoidStateType.Jumping then
        if velocity.Y > 5 then
            return "START"
        elseif velocity.Y > -1 then
            return "PEAK"
        else
            return "FALL"
        end
    elseif state == Enum.HumanoidStateType.Freefall then
        if velocity.Y > 1 then
            return "PEAK"
        else
            return "FALL"
        end
    elseif state == Enum.HumanoidStateType.Landed then
        return "LAND"
    end
    
    return nil
end

-- Create a single frame
local function createFrame()
    if not LocalPlayer.Character then return nil end
    local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    
    local position = hrp.Position
    local rotation = hrp.CFrame - hrp.CFrame.Position -- Get rotation only
    local groundY = getGroundY(position)
    local grounded = isGrounded()
    local groundPart = getGroundPart()
    
    local frameType = detectFrameType()
    local jumpPhase = nil
    local platformData = nil
    
    if frameType == FrameType.JUMP then
        jumpPhase = getJumpPhase()
    elseif frameType == FrameType.PLATFORM and groundPart then
        platformData = {
            name = groundPart.Name,
            recordedPosition = groundPart.Position,
        }
    end
    
    return {
        type = frameType,
        timestamp = tick() - recordStartTime,
        position = position,
        rotation = {rotation:ToEulerAnglesXYZ()}, -- Store as angles
        velocity = hrp.AssemblyLinearVelocity, -- Store velocity for jump precision
        isGrounded = grounded,
        groundY = groundY,
        heightAboveGround = position.Y - groundY,
        jumpPhase = jumpPhase,
        platformData = platformData,
    }
end

-- Forward declare UI elements that will be created later
local recStatusText, recFramesText, playStatusText, playProgressText, routeStatsLabel

-- Update GUI stats (ALL tabs)
local function updateRecordingStats()
    local frames = #State.CurrentRecording.frames
    local duration = frames > 0 and State.CurrentRecording.frames[frames].timestamp or 0
    
    -- Update Home tab stat cards
    if framesStat and framesStat:FindFirstChild("Value") then
        framesStat.Value.Text = tostring(frames)
    end
    if durationStat and durationStat:FindFirstChild("Value") then
        durationStat.Value.Text = string.format("%.1fs", duration)
    end
    
    -- Update metadata
    State.CurrentRecording.metadata.totalFrames = frames
    State.CurrentRecording.metadata.duration = duration
end

-- Update ALL UI status elements
local function updateAllUI()
    local frames = #State.CurrentRecording.frames
    local duration = State.CurrentRecording.metadata.duration
    local mode = State.Mode
    
    -- Home tab stats
    if framesStat and framesStat:FindFirstChild("Value") then
        framesStat.Value.Text = tostring(frames)
    end
    if durationStat and durationStat:FindFirstChild("Value") then
        durationStat.Value.Text = string.format("%.1fs", duration)
    end
    
    -- Record tab (will be updated when tab is created)
    -- These variables will be set later, check if they exist
    if recStatusText then
        recStatusText.Text = "Status: " .. mode
        if mode == "RECORDING" then
            recStatusText.TextColor3 = Colors.Red
        else
            recStatusText.TextColor3 = Colors.TextPrimary
        end
    end
    if recFramesText then
        recFramesText.Text = string.format("Frames: %d | Duration: %.1fs", frames, duration)
    end
    
    -- Playback tab
    if playStatusText then
        playStatusText.Text = "Status: " .. mode
        if mode == "PLAYING" then
            playStatusText.TextColor3 = Colors.Green
        else
            playStatusText.TextColor3 = Colors.TextPrimary
        end
    end
    if playProgressText then
        playProgressText.Text = string.format("Progress: %d/%d frames", State.PlaybackIndex, frames)
    end
    
    -- Routes tab
    if routeStatsLabel then
        routeStatsLabel.Text = string.format("Frames: %d | Duration: %.1fs", frames, duration)
    end
end

-- Update status badge
local function updateStatusBadge(mode)
    if not statusBadge then return end
    
    State.Mode = mode
    statusBadge.Text = mode
    
    if mode == "IDLE" then
        statusBadge.BackgroundColor3 = Colors.CardHover
        statusBadge.TextColor3 = Colors.TextSecondary
    elseif mode == "RECORDING" then
        statusBadge.BackgroundColor3 = Colors.Red
        statusBadge.TextColor3 = Colors.TextPrimary
    elseif mode == "PLAYING" then
        statusBadge.BackgroundColor3 = Colors.Green
        statusBadge.TextColor3 = Colors.TextPrimary
    elseif mode == "PAUSED" then
        statusBadge.BackgroundColor3 = Colors.Yellow
        statusBadge.TextColor3 = Colors.Background
    end
end

-- Start recording
local function startRecording()
    if State.Mode == "RECORDING" then return end
    
    -- Clear previous recording
    State.CurrentRecording = {
        metadata = {
            version = "1.0",
            recordedAt = os.time(),
            avatarHeight = getAvatarHeight(),
            totalFrames = 0,
            duration = 0,
        },
        frames = {},
    }
    
    recordStartTime = tick()
    lastRecordTime = 0
    
    updateStatusBadge("RECORDING")
    print("[GhostWalk] Recording started!")
    
    -- Recording loop
    recordingConnection = RunService.RenderStepped:Connect(function()
        local elapsed = tick() - recordStartTime
        
        -- Record at interval
        if elapsed - lastRecordTime >= Config.Recording.Interval then
            local frame = createFrame()
            if frame then
                table.insert(State.CurrentRecording.frames, frame)
                lastRecordTime = elapsed
                updateRecordingStats()
                updateAllUI()
            end
        end
    end)
    
    table.insert(_G.GhostWalk.Connections, recordingConnection)
end

-- Stop recording
local function stopRecording()
    if State.Mode ~= "RECORDING" then return end
    
    if recordingConnection then
        recordingConnection:Disconnect()
        recordingConnection = nil
    end
    
    updateStatusBadge("IDLE")
    updateRecordingStats()
    
    local frames = #State.CurrentRecording.frames
    local duration = State.CurrentRecording.metadata.duration
    
    print("[GhostWalk] Recording stopped!")
    print(string.format("  Frames: %d | Duration: %.1fs", frames, duration))
    
    -- Analyze recorded frames
    local jumpCount = 0
    local platformCount = 0
    local stairsCount = 0
    
    for _, frame in ipairs(State.CurrentRecording.frames) do
        if frame.type == FrameType.JUMP then
            jumpCount = jumpCount + 1
        elseif frame.type == FrameType.PLATFORM then
            platformCount = platformCount + 1
        elseif frame.type == FrameType.STAIRS then
            stairsCount = stairsCount + 1
        end
    end
    
    print(string.format("  Detected: %d jumps, %d platform frames", jumpCount, platformCount))
end

-- Toggle recording
local function toggleRecording()
    if State.Mode == "RECORDING" then
        stopRecording()
    elseif State.Mode == "IDLE" then
        startRecording()
    end
end

-- ==================== PLAYBACK SYSTEM ====================

local playbackConnection = nil
local playbackStartTime = 0
local isRecovering = false
local fallCheckGracePeriod = 2 -- Seconds to wait before checking for falls
local lastFallCheckTime = 0

-- ==================== FALL RECOVERY SYSTEM ====================

-- Find nearest VALID frame to current position (must be grounded and reachable)
local function findNearestFrame(currentPos)
    local frames = State.CurrentRecording.frames
    local nearestIndex = State.PlaybackIndex
    local nearestDist = math.huge
    
    -- Get current Y level to avoid frames too far below
    local currentY = currentPos.Y
    local minY = currentY - 20 -- Don't go to frames more than 20 studs below
    
    -- Search from current index forward
    for i = State.PlaybackIndex, #frames do
        local frame = frames[i]
        
        -- ONLY consider GROUNDED frames that are above minimum Y
        if frame.isGrounded and frame.position.Y >= minY then
            local frameDist = (frame.position - currentPos).Magnitude
            
            -- Calculate horizontal distance (ignore Y for better matching)
            local horizontalDist = math.sqrt(
                (frame.position.X - currentPos.X)^2 + 
                (frame.position.Z - currentPos.Z)^2
            )
            
            -- Prefer frames that are closer horizontally
            if horizontalDist < nearestDist then
                nearestDist = horizontalDist
                nearestIndex = i
            end
        end
    end
    
    -- If no grounded frame found ahead, search backwards
    if nearestDist == math.huge then
        for i = State.PlaybackIndex - 1, 1, -1 do
            local frame = frames[i]
            if frame.isGrounded and frame.position.Y >= minY then
                local horizontalDist = math.sqrt(
                    (frame.position.X - currentPos.X)^2 + 
                    (frame.position.Z - currentPos.Z)^2
                )
                if horizontalDist < nearestDist then
                    nearestDist = horizontalDist
                    nearestIndex = i
                end
            end
        end
    end
    
    return nearestIndex, nearestDist
end

-- Calculate smart speed for recovery walk
local function getRecoverySpeed(distance)
    if not Config.FallRecovery.SmartSpeed then
        return 16 -- Default walk speed
    end
    
    -- Gradual speed increase based on distance
    -- Close: normal speed, Far: faster
    local baseSpeed = 16
    local maxBoost = Config.FallRecovery.MaxSpeedBoost
    
    if distance < 10 then
        return baseSpeed -- Normal speed for close distances
    elseif distance < 30 then
        -- Linear interpolation: 1.0x to 1.3x
        local t = (distance - 10) / 20
        return baseSpeed * (1 + t * 0.3)
    elseif distance < 50 then
        -- 1.3x to maxBoost
        local t = (distance - 30) / 20
        return baseSpeed * (1.3 + t * (maxBoost - 1.3))
    else
        return baseSpeed * maxBoost
    end
end

-- Check if player has fallen (position too far from expected)
local function checkForFall(hrp, expectedFrame)
    if not Config.FallRecovery.Enabled then return false end
    if isRecovering then return false end
    
    -- Grace period: don't check for falls in the first few seconds of playback
    -- This prevents false detection when player starts from different position
    local elapsed = tick() - playbackStartTime
    if elapsed < fallCheckGracePeriod then
        return false -- Don't check falls during grace period
    end
    
    -- Also skip if we're still at the beginning frames (first 10 frames)
    if State.PlaybackIndex < 10 then
        return false
    end
    
    local currentPos = hrp.Position
    local expectedPos = expectedFrame.position
    local distance = (currentPos - expectedPos).Magnitude
    
    return distance > Config.FallRecovery.Threshold
end

-- Perform recovery walk to nearest valid frame
local function performRecovery(hrp)
    if isRecovering then return end
    isRecovering = true
    
    local currentPos = hrp.Position
    local nearestIndex, distance = findNearestFrame(currentPos)
    
    print(string.format("[GhostWalk] Fall detected! Recovering to frame %d (%.1f studs away)", nearestIndex, distance))
    
    -- Update playback index to nearest frame
    State.PlaybackIndex = nearestIndex
    
    -- Get target frame
    local targetFrame = State.CurrentRecording.frames[nearestIndex]
    if not targetFrame then
        isRecovering = false
        return
    end
    
    -- Get humanoid for walking
    local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
    if not humanoid then
        isRecovering = false
        return
    end
    
    -- Calculate speed
    local speed = getRecoverySpeed(distance)
    local originalSpeed = humanoid.WalkSpeed
    
    -- Apply smart speed
    humanoid.WalkSpeed = speed
    
    -- Walk to target (using MoveTo for natural movement)
    local targetPos = targetFrame.position
    
    -- Height adjustment
    local currentAvatarHeight = getAvatarHeight()
    local recordedHeight = State.CurrentRecording.metadata.avatarHeight
    local heightDiff = currentAvatarHeight - recordedHeight
    targetPos = Vector3.new(targetPos.X, targetPos.Y + heightDiff, targetPos.Z)
    
    humanoid:MoveTo(targetPos)
    
    -- Wait for arrival or timeout
    local startTime = tick()
    local maxTime = distance / speed * 2 -- Give double expected time
    
    spawn(function()
        while isRecovering do
            local dist = (hrp.Position - targetPos).Magnitude
            
            if dist < 3 then
                -- Arrived!
                print("[GhostWalk] Recovery complete!")
                break
            end
            
            if tick() - startTime > maxTime then
                -- Timeout
                print("[GhostWalk] Recovery timeout, continuing anyway")
                break
            end
            
            wait(0.1)
        end
        
        -- Restore speed
        humanoid.WalkSpeed = originalSpeed
        isRecovering = false
        
        -- Reset playback time to match new position
        if State.CurrentRecording.frames[State.PlaybackIndex] then
            local frameTime = State.CurrentRecording.frames[State.PlaybackIndex].timestamp
            playbackStartTime = tick() - (frameTime / Config.Playback.Speed)
        end
    end)
end

-- Start playback
local function startPlayback()
    if State.Mode == "PLAYING" then return end
    if #State.CurrentRecording.frames == 0 then
        print("[GhostWalk] No recording to play!")
        return
    end
    
    State.PlaybackIndex = 1
    playbackStartTime = tick()
    isRecovering = false -- Reset recovery state
    
    -- Teleport to starting position (frame 1)
    local firstFrame = State.CurrentRecording.frames[1]
    if firstFrame and LocalPlayer.Character then
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local startPos = firstFrame.position
            
            -- Height adjustment
            local currentAvatarHeight = getAvatarHeight()
            local recordedHeight = State.CurrentRecording.metadata.avatarHeight
            local heightDiff = currentAvatarHeight - recordedHeight
            startPos = Vector3.new(startPos.X, startPos.Y + heightDiff, startPos.Z)
            
            -- Apply rotation
            local rotX, rotY, rotZ = unpack(firstFrame.rotation)
            local startRot = CFrame.Angles(rotX, rotY, rotZ)
            
            -- Teleport to start
            hrp.CFrame = CFrame.new(startPos) * startRot
            print("[GhostWalk] Teleported to start position")
        end
    end
    
    updateStatusBadge("PLAYING")
    print("[GhostWalk] Playback started!")
    
    playbackConnection = RunService.RenderStepped:Connect(function()
        if not LocalPlayer.Character then return end
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        
        local elapsed = tick() - playbackStartTime
        local frames = State.CurrentRecording.frames
        
        -- Find current frame based on timestamp
        local currentFrame = nil
        local nextFrame = nil
        
        for i = State.PlaybackIndex, #frames do
            if frames[i].timestamp <= elapsed * Config.Playback.Speed then
                currentFrame = frames[i]
                State.PlaybackIndex = i
                nextFrame = frames[i + 1]
            else
                break
            end
        end
        
        if currentFrame then
            -- Check for fall (position too far from expected)
            if checkForFall(hrp, currentFrame) then
                performRecovery(hrp)
                return -- Skip this frame, recovery will handle positioning
            end
            
            -- Skip movement if recovering
            if isRecovering then return end
            
            -- Get humanoid reference
            local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
            
            -- Helper function to trigger jump (multiple methods for compatibility)
            -- With cooldown to prevent spam
            local lastJumpTime = State.LastJumpTime or 0
            local jumpCooldown = 0.4 -- Minimum 0.4s between jumps (slightly faster than humanoid default)
            
            local function triggerJump(forceVelocity)
                if not humanoid then return end
                
                -- Cooldown check
                local now = tick()
                if now - lastJumpTime < jumpCooldown then
                    return -- On cooldown
                end
                
                local currentState = humanoid:GetState()
                if currentState == Enum.HumanoidStateType.Jumping or 
                   currentState == Enum.HumanoidStateType.Freefall then
                    return -- Already jumping
                end
                
                -- Check if we actually need to jump (height difference)
                local targetY = currentFrame.position.Y
                local currentY = hrp.Position.Y
                local heightDiff = targetY - currentY
                
                -- Only jump if target is significantly higher (> 1 stud)
                -- OR if recorded frame has upward velocity
                local needsJump = heightDiff > 1 or (forceVelocity and forceVelocity > 10)
                
                if not needsJump and currentFrame.isGrounded then
                    return -- Don't jump if target is at same height and grounded
                end
                
                -- Update cooldown
                State.LastJumpTime = now
                
                -- Method 1: Humanoid.Jump property
                humanoid.Jump = true
                
                -- Method 2: ChangeState (more reliable in some games)
                pcall(function()
                    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end)
                
                -- Method 3: Apply upward velocity (works even if Jump is blocked)
                pcall(function()
                    if hrp and forceVelocity then
                        hrp.AssemblyLinearVelocity = Vector3.new(
                            hrp.AssemblyLinearVelocity.X,
                            math.max(forceVelocity, humanoid.JumpPower or 50),
                            hrp.AssemblyLinearVelocity.Z
                        )
                    elseif hrp then
                        local jumpPower = humanoid.JumpPower or 50
                        hrp.AssemblyLinearVelocity = Vector3.new(
                            hrp.AssemblyLinearVelocity.X,
                            jumpPower,
                            hrp.AssemblyLinearVelocity.Z
                        )
                    end
                end)
                
                -- Method 4: VirtualInputManager (exploit feature)
                pcall(function()
                    if game:GetService("VirtualInputManager") then
                        local vim = game:GetService("VirtualInputManager")
                        vim:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                        task.delay(0.1, function()
                            vim:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                        end)
                    end
                end)
            end
            
            -- ==================== PREDICTIVE JUMP HANDLING ====================
            -- Calculate move direction from current position to target
            local targetPos = currentFrame.position
            local moveDirection = Vector3.new(0, 0, 0)
            local horizontalDist = math.sqrt((targetPos.X - hrp.Position.X)^2 + (targetPos.Z - hrp.Position.Z)^2)
            
            if horizontalDist > 0.1 then
                moveDirection = Vector3.new(
                    targetPos.X - hrp.Position.X,
                    0,
                    targetPos.Z - hrp.Position.Z
                ).Unit
            else
                -- Use character facing direction if not moving much
                moveDirection = hrp.CFrame.LookVector
                moveDirection = Vector3.new(moveDirection.X, 0, moveDirection.Z).Unit
            end
            
            -- Get recorded velocity for jump power
            local recordedVelocityY = currentFrame.velocity and currentFrame.velocity.Y or nil
            
            -- PRIORITY 1: Recorded JUMP frames - always respect recording
            if currentFrame.type == "JUMP" and currentFrame.jumpPhase == "START" then
                triggerJump(recordedVelocityY)
            
            -- PRIORITY 2: Predictive jump - detect gaps/edges ahead
            elseif isGrounded() then
                -- Use smart jump for parkour gap detection
                local didJump = smartTriggerJump(hrp, humanoid, moveDirection, targetPos, recordedVelocityY)
                
                -- PRIORITY 3: Look-ahead recorded frames (backup)
                if not didJump then
                    local frames = State.CurrentRecording.frames
                    for lookAhead = 1, 3 do -- Extended look-ahead
                        local futureIdx = State.PlaybackIndex + lookAhead
                        if futureIdx <= #frames then
                            local futureFrame = frames[futureIdx]
                            if futureFrame and futureFrame.type == "JUMP" and futureFrame.jumpPhase == "START" then
                                local distToJump = (hrp.Position - futureFrame.position).Magnitude
                                -- Jump earlier - at 4 studs instead of 3
                                if distToJump < 4 then
                                    local jumpVel = futureFrame.velocity and futureFrame.velocity.Y or nil
                                    triggerJump(jumpVel)
                                    break
                                end
                            end
                        end
                    end
                end
            
            -- PRIORITY 4: Airborne sync - if recording shows airborne but we're grounded
            elseif not currentFrame.isGrounded and humanoid then
                local currentState = humanoid:GetState()
                if currentState ~= Enum.HumanoidStateType.Jumping and 
                   currentState ~= Enum.HumanoidStateType.Freefall then
                    local heightAboveGround = currentFrame.heightAboveGround or 3
                    local currentHeight = hrp.Position.Y - getGroundY(hrp.Position)
                    
                    if heightAboveGround > currentHeight + 1.5 then
                        if recordedVelocityY and recordedVelocityY > 3 then
                            triggerJump(recordedVelocityY)
                        end
                    end
                end
            end
            
            -- Apply position
            local targetPos = currentFrame.position
            
            -- Height adjustment for different avatar
            if currentFrame.isGrounded then
                local currentAvatarHeight = getAvatarHeight()
                local recordedHeight = State.CurrentRecording.metadata.avatarHeight
                local heightDiff = currentAvatarHeight - recordedHeight
                targetPos = Vector3.new(targetPos.X, targetPos.Y + heightDiff, targetPos.Z)
            end
            
            -- Get humanoid for movement
            local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
            
            -- Check if currently airborne - if so, let physics handle movement naturally
            local isAirborne = false
            if humanoid then
                local hState = humanoid:GetState()
                isAirborne = (hState == Enum.HumanoidStateType.Jumping or 
                              hState == Enum.HumanoidStateType.Freefall)
            end
            
            -- Apply rotation (smooth lerp for rotation only)
            local rotX, rotY, rotZ = unpack(currentFrame.rotation)
            local targetRot = CFrame.Angles(rotX, rotY, rotZ)
            local currentRot = hrp.CFrame - hrp.CFrame.Position
            local newRot = currentRot:Lerp(targetRot, 0.2) -- Smooth rotation
            
            -- If airborne, let physics handle movement 100% - NO interference
            -- Only apply rotation, don't touch position or velocity
            local skipPositionLerp = false
            if isAirborne then
                -- Only update rotation smoothly, nothing else!
                hrp.CFrame = CFrame.new(hrp.Position) * newRot
                skipPositionLerp = true
                -- DON'T set velocity - let physics engine handle the jump arc naturally
            end
            
            -- Calculate direction and distance to target
            local distance = (hrp.Position - targetPos).Magnitude
            local direction = distance > 0.1 and (targetPos - hrp.Position).Unit or Vector3.new(0,0,0)
            
            -- Choose movement method based on config
            -- Skip position lerping if airborne (already handled above)
            if not skipPositionLerp and Config.Playback.Method == "Teleport" then
                -- Smooth teleport with lerp + walking animation
                local lerpFactor = math.clamp(distance * 0.1, 0.3, 0.8)
                local smoothPos = hrp.Position:Lerp(targetPos, lerpFactor)
                local smoothRot = currentRot:Lerp(targetRot, 0.3)
                hrp.CFrame = CFrame.new(smoothPos) * smoothRot
                
                -- Force walking animation when moving
                if humanoid and distance > 0.5 then
                    humanoid:Move(direction, false) -- Trigger walk anim
                elseif humanoid then
                    humanoid:Move(Vector3.new(0,0,0), false) -- Stop anim
                end
                
            elseif not skipPositionLerp and Config.Playback.Method == "Tween" then
                -- Ultra-smooth tween + walking animation
                local tweenInfo = TweenInfo.new(
                    Config.Recording.Interval * 0.8,
                    Enum.EasingStyle.Linear,
                    Enum.EasingDirection.Out
                )
                local targetCFrame = CFrame.new(targetPos) * targetRot
                local tween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
                tween:Play()
                
                -- Force walking animation when moving
                if humanoid and distance > 0.5 then
                    humanoid:Move(direction, false)
                elseif humanoid then
                    humanoid:Move(Vector3.new(0,0,0), false)
                end
                
            elseif not skipPositionLerp and Config.Playback.Method == "Physics" then
                -- Ultra-smooth physics-based movement using velocity
                local speed = humanoid and humanoid.WalkSpeed or 16
                local moveVector = (targetPos - hrp.Position)
                local moveDir = moveVector.Magnitude > 0.1 and moveVector.Unit or Vector3.zero
                
                if distance > 0.3 then
                    local velocity = moveDir * math.min(speed, distance * 5)
                    hrp.AssemblyLinearVelocity = Vector3.new(velocity.X, hrp.AssemblyLinearVelocity.Y, velocity.Z)
                    if humanoid then
                        humanoid:Move(Vector3.new(0, 0, -1), false)
                    end
                else
                    hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0)
                    if humanoid then
                        humanoid:Move(Vector3.new(0, 0, 0), false)
                    end
                end
                hrp.CFrame = CFrame.new(hrp.Position) * newRot
                
            elseif not skipPositionLerp and Config.Playback.Method == "Humanoid" then
                -- Simple: smooth lerp + walk animation
                hrp.CFrame = CFrame.new(hrp.Position) * newRot
                
                if distance > 0.2 then
                    local lerpSpeed = 0.1
                    local newPos = hrp.Position:Lerp(targetPos, lerpSpeed)
                    hrp.CFrame = CFrame.new(newPos) * newRot
                    if humanoid then
                        humanoid:Move(Vector3.new(0, 0, -1), false)
                    end
                else
                    if humanoid then
                        humanoid:Move(Vector3.new(0, 0, 0), false)
                    end
                end
                
            elseif not skipPositionLerp and Config.Playback.Method == "Hybrid+" then
                -- ========== HYBRID+ (Advanced) ==========
                -- DeltaTime-independent interpolation + animation sync + humanization
                
                -- Calculate DeltaTime
                local dt = RunService.RenderStepped:Wait()
                State.LastDeltaTime = dt
                
                -- DeltaTime-independent lerp (from hasil_riset.md)
                local smoothFactor = Config.Playback.SmoothFactor
                local alpha = 1 - math.pow(1 - smoothFactor, dt * 60)
                alpha = math.clamp(alpha, 0.05, 0.5)
                
                -- Humanization: add micro-variance
                if Config.Humanization.Enabled then
                    local variance = Config.Humanization.SpeedVariance
                    alpha = alpha * (1 + (math.random() - 0.5) * 2 * variance)
                    
                    -- Micro-pause chance
                    if Config.Humanization.MicroPauses and math.random() < Config.Humanization.MicroPauseChance then
                        alpha = alpha * 0.1 -- Slow down momentarily
                    end
                end
                
                -- Apply smooth position
                local newPos = hrp.Position:Lerp(targetPos, alpha)
                hrp.CFrame = CFrame.new(newPos) * newRot
                
                -- Animation sync using Humanoid:Move()
                if Config.Playback.SyncAnimation and humanoid then
                    if distance > 0.3 then
                        -- Calculate move direction relative to character facing
                        local lookVector = hrp.CFrame.LookVector
                        local rightVector = hrp.CFrame.RightVector
                        local moveDir = (targetPos - hrp.Position).Unit
                        
                        local forwardDot = lookVector:Dot(moveDir)
                        local rightDot = rightVector:Dot(moveDir)
                        
                        humanoid:Move(Vector3.new(rightDot, 0, -forwardDot), false)
                    else
                        humanoid:Move(Vector3.new(0, 0, 0), false)
                    end
                end
                
                -- Sync to recorded animation if available (advanced sync)
                syncAnimationToFrame(currentFrame)
                
            elseif not skipPositionLerp and Config.Playback.Method == "Spline" then
                -- ========== SPLINE (Catmull-Rom) ==========
                -- Ultra-smooth curved path interpolation
                
                local frames = State.CurrentRecording.frames
                local idx = State.PlaybackIndex
                
                -- Need at least 4 points for Catmull-Rom
                if #frames >= 4 then
                    -- Calculate t based on time between frames
                    local p1 = frames[idx]
                    local p2 = frames[math.min(#frames, idx + 1)]
                    
                    local frameTime = elapsed * Config.Playback.Speed
                    local t = 0
                    if p2.timestamp > p1.timestamp then
                        t = math.clamp((frameTime - p1.timestamp) / (p2.timestamp - p1.timestamp), 0, 1)
                    end
                    
                    -- Get spline position
                    local splinePos = getSplinePosition(frames, idx, t)
                    
                    -- Height adjustment
                    if currentFrame.isGrounded then
                        local heightDiff = getAvatarHeight() - State.CurrentRecording.metadata.avatarHeight
                        splinePos = Vector3.new(splinePos.X, splinePos.Y + heightDiff, splinePos.Z)
                    end
                    
                    -- Smooth apply with deltaLerp
                    local dt = State.LastDeltaTime or 0.016
                    local newPos = deltaLerp(hrp.Position, splinePos, Config.Playback.SmoothFactor, dt)
                    hrp.CFrame = CFrame.new(newPos) * newRot
                else
                    -- Fallback to regular lerp
                    local newPos = hrp.Position:Lerp(targetPos, 0.15)
                    hrp.CFrame = CFrame.new(newPos) * newRot
                end
                
                -- Animation
                if humanoid and distance > 0.3 then
                    humanoid:Move(Vector3.new(0, 0, -1), false)
                elseif humanoid then
                    humanoid:Move(Vector3.new(0, 0, 0), false)
                end
                
            elseif not skipPositionLerp and Config.Playback.Method == "AlignPosition" then
                -- ========== ALIGN POSITION (Physics Constraints) ==========
                -- Uses physics engine for ultra-smooth 240Hz movement
                
                -- Create or get AlignPosition constraint
                local alignPos = hrp:FindFirstChild("GhostWalkAlign")
                if not alignPos then
                    alignPos = Instance.new("AlignPosition")
                    alignPos.Name = "GhostWalkAlign"
                    alignPos.Mode = Enum.PositionAlignmentMode.OneAttachment
                    alignPos.ApplyAtCenterOfMass = true
                    alignPos.MaxForce = 100000
                    alignPos.MaxVelocity = humanoid and humanoid.WalkSpeed or 16
                    alignPos.Responsiveness = 50
                    alignPos.Parent = hrp
                    
                    local attachment = hrp:FindFirstChild("RootAttachment") or Instance.new("Attachment", hrp)
                    alignPos.Attachment0 = attachment
                end
                
                -- Update target position
                alignPos.Position = targetPos
                alignPos.MaxVelocity = (humanoid and humanoid.WalkSpeed or 16) * Config.Playback.Speed
                
                -- Apply rotation separately
                hrp.CFrame = CFrame.new(hrp.Position) * newRot
                
                -- Animation
                if humanoid and distance > 0.3 then
                    humanoid:Move(Vector3.new(0, 0, -1), false)
                elseif humanoid then
                    humanoid:Move(Vector3.new(0, 0, 0), false)
                end
                
            else -- "Hybrid" (default) - lerp + walk
                hrp.CFrame = CFrame.new(hrp.Position) * newRot
                
                if distance > 0.2 then
                    local lerpSpeed = math.clamp(distance * 0.08, 0.05, 0.2)
                    local newPos = hrp.Position:Lerp(targetPos, lerpSpeed)
                    hrp.CFrame = CFrame.new(newPos) * newRot
                    if humanoid then
                        humanoid:Move(Vector3.new(0, 0, -1), false)
                    end
                else
                    if humanoid then
                        humanoid:Move(Vector3.new(0, 0, 0), false)
                    end
                end
            end
        end
        
        -- Check if playback ended
        if State.PlaybackIndex >= #frames then
            if Config.Playback.Loop then
                -- Loop
                State.PlaybackIndex = 1
                playbackStartTime = tick()
            else
                stopPlayback()
            end
        end
        
        -- Update stats
        updateRecordingStats()
        updateAllUI()
    end)
    
    table.insert(_G.GhostWalk.Connections, playbackConnection)
end

-- Stop playback
local function stopPlayback()
    if State.Mode ~= "PLAYING" then return end
    
    if playbackConnection then
        playbackConnection:Disconnect()
        playbackConnection = nil
    end
    
    -- Cleanup AlignPosition constraint if used
    if LocalPlayer.Character then
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local alignPos = hrp:FindFirstChild("GhostWalkAlign")
            if alignPos then
                alignPos:Destroy()
            end
        end
    end
    
    updateStatusBadge("IDLE")
    print("[GhostWalk] Playback stopped!")
end

-- Pause playback
local pausedAtTime = 0
local pausedAtIndex = 1

local function pausePlayback()
    if State.Mode ~= "PLAYING" then return end
    
    -- Save current state
    pausedAtTime = tick() - playbackStartTime
    pausedAtIndex = State.PlaybackIndex
    
    -- Disconnect but don't reset
    if playbackConnection then
        playbackConnection:Disconnect()
        playbackConnection = nil
    end
    
    updateStatusBadge("PAUSED")
    print("[GhostWalk] Playback paused!")
end

-- Resume playback
local function resumePlayback()
    if State.Mode ~= "PAUSED" then return end
    
    -- Resume from where we left off
    State.PlaybackIndex = pausedAtIndex
    playbackStartTime = tick() - pausedAtTime
    
    updateStatusBadge("PLAYING")
    print("[GhostWalk] Playback resumed!")
    
    -- Reconnect playback loop
    playbackConnection = RunService.RenderStepped:Connect(function()
        if not LocalPlayer.Character then return end
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        
        local elapsed = tick() - playbackStartTime
        local frames = State.CurrentRecording.frames
        
        -- Find current frame based on timestamp
        local currentFrame = nil
        local nextFrame = nil
        
        for i = State.PlaybackIndex, #frames do
            if frames[i].timestamp <= elapsed * Config.Playback.Speed then
                currentFrame = frames[i]
                State.PlaybackIndex = i
                nextFrame = frames[i + 1]
            else
                break
            end
        end
        
        if currentFrame then
            -- Check for fall
            if checkForFall(hrp, currentFrame) then
                performRecovery(hrp)
                return
            end
            
            if isRecovering then return end
            
            -- Get humanoid reference
            local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
            
            -- Helper function to trigger jump (multiple methods for compatibility)
            local function triggerJump()
                if not humanoid then return end
                
                local currentState = humanoid:GetState()
                if currentState == Enum.HumanoidStateType.Jumping or 
                   currentState == Enum.HumanoidStateType.Freefall then
                    return
                end
                
                humanoid.Jump = true
                pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end)
                pcall(function()
                    if hrp then
                        local jumpPower = humanoid.JumpPower or 50
                        hrp.AssemblyLinearVelocity = Vector3.new(
                            hrp.AssemblyLinearVelocity.X,
                            jumpPower,
                            hrp.AssemblyLinearVelocity.Z
                        )
                    end
                end)
                pcall(function()
                    if game:GetService("VirtualInputManager") then
                        local vim = game:GetService("VirtualInputManager")
                        vim:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                        task.delay(0.1, function()
                            vim:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                        end)
                    end
                end)
            end
            
            -- Handle JUMP frames
            if currentFrame.type == "JUMP" then
                if currentFrame.jumpPhase == "START" then
                    triggerJump()
                end
            end
            
            -- Also check if should be airborne
            if not currentFrame.isGrounded and humanoid then
                local currentState = humanoid:GetState()
                if currentState ~= Enum.HumanoidStateType.Jumping and 
                   currentState ~= Enum.HumanoidStateType.Freefall then
                    triggerJump()
                end
            end
            
            -- Apply position
            local targetPos = currentFrame.position
            
            if currentFrame.isGrounded then
                local currentAvatarHeight = getAvatarHeight()
                local recordedHeight = State.CurrentRecording.metadata.avatarHeight
                local heightDiff = currentAvatarHeight - recordedHeight
                targetPos = Vector3.new(targetPos.X, targetPos.Y + heightDiff, targetPos.Z)
            end
            
            -- Apply rotation (smooth lerp for rotation only)
            local rotX, rotY, rotZ = unpack(currentFrame.rotation)
            local targetRot = CFrame.Angles(rotX, rotY, rotZ)
            local currentRot = hrp.CFrame - hrp.CFrame.Position
            local newRot = currentRot:Lerp(targetRot, 0.2)
            
            -- Calculate direction and distance to target
            local distance = (hrp.Position - targetPos).Magnitude
            local direction = distance > 0.1 and (targetPos - hrp.Position).Unit or Vector3.new(0,0,0)
            
            -- Choose movement method based on config
            if Config.Playback.Method == "Teleport" then
                local lerpFactor = math.clamp(distance * 0.1, 0.3, 0.8)
                local smoothPos = hrp.Position:Lerp(targetPos, lerpFactor)
                local smoothRot = currentRot:Lerp(targetRot, 0.3)
                hrp.CFrame = CFrame.new(smoothPos) * smoothRot
                
                if humanoid and distance > 0.5 then
                    humanoid:Move(direction, false)
                elseif humanoid then
                    humanoid:Move(Vector3.new(0,0,0), false)
                end
                
            elseif Config.Playback.Method == "Tween" then
                local tweenInfo = TweenInfo.new(
                    Config.Recording.Interval * 0.8,
                    Enum.EasingStyle.Linear,
                    Enum.EasingDirection.Out
                )
                local targetCFrame = CFrame.new(targetPos) * targetRot
                local tween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
                tween:Play()
                
                if humanoid and distance > 0.5 then
                    humanoid:Move(direction, false)
                elseif humanoid then
                    humanoid:Move(Vector3.new(0,0,0), false)
                end
                
            elseif Config.Playback.Method == "Physics" then
                -- Ultra-smooth physics-based movement
                local speed = humanoid and humanoid.WalkSpeed or 16
                local moveVector = (targetPos - hrp.Position)
                local moveDir = moveVector.Magnitude > 0.1 and moveVector.Unit or Vector3.zero
                
                if distance > 0.3 then
                    local velocity = moveDir * math.min(speed, distance * 5)
                    hrp.AssemblyLinearVelocity = Vector3.new(velocity.X, hrp.AssemblyLinearVelocity.Y, velocity.Z)
                    if humanoid then
                        humanoid:Move(Vector3.new(0, 0, -1), false)
                    end
                else
                    hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0)
                    if humanoid then
                        humanoid:Move(Vector3.new(0, 0, 0), false)
                    end
                end
                hrp.CFrame = CFrame.new(hrp.Position) * newRot
                
            elseif Config.Playback.Method == "Humanoid" then
                hrp.CFrame = CFrame.new(hrp.Position) * newRot
                
                if distance > 0.2 then
                    local lerpSpeed = 0.1
                    local newPos = hrp.Position:Lerp(targetPos, lerpSpeed)
                    hrp.CFrame = CFrame.new(newPos) * newRot
                    if humanoid then
                        humanoid:Move(Vector3.new(0, 0, -1), false)
                    end
                else
                    if humanoid then
                        humanoid:Move(Vector3.new(0, 0, 0), false)
                    end
                end
                
            else -- "Hybrid" - lerp + walk
                hrp.CFrame = CFrame.new(hrp.Position) * newRot
                
                if distance > 0.2 then
                    local lerpSpeed = math.clamp(distance * 0.08, 0.05, 0.2)
                    local newPos = hrp.Position:Lerp(targetPos, lerpSpeed)
                    hrp.CFrame = CFrame.new(newPos) * newRot
                    if humanoid then
                        humanoid:Move(Vector3.new(0, 0, -1), false)
                    end
                else
                    if humanoid then
                        humanoid:Move(Vector3.new(0, 0, 0), false)
                    end
                end
            end
        end
        
        -- Check if playback ended
        if State.PlaybackIndex >= #frames then
            if Config.Playback.Loop then
                State.PlaybackIndex = 1
                playbackStartTime = tick()
            else
                stopPlayback()
            end
        end
        
        updateRecordingStats()
        updateAllUI()
    end)
    
    table.insert(_G.GhostWalk.Connections, playbackConnection)
end

-- Toggle playback (with pause support)
local function togglePlayback()
    if State.Mode == "PLAYING" then
        pausePlayback() -- Pause instead of stop
    elseif State.Mode == "PAUSED" then
        resumePlayback() -- Resume from pause
    elseif State.Mode == "IDLE" then
        startPlayback()
    end
end

-- Stop all
local function stopAll()
    if State.Mode == "RECORDING" then
        stopRecording()
    elseif State.Mode == "PLAYING" or State.Mode == "PAUSED" then
        stopPlayback()
    end
end

-- ==================== CONNECT BUTTONS ====================

-- Update the button callbacks
recordBtn.MouseButton1Click:Connect(toggleRecording)
playBtn.MouseButton1Click:Connect(togglePlayback)
stopBtn.MouseButton1Click:Connect(stopAll)

-- ==================== KEYBINDS FOR RECORD/PLAY/SAVESTATE ====================

local actionKeybindConn = UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    
    if input.KeyCode == Config.Keybinds.Record then
        toggleRecording()
    elseif input.KeyCode == Config.Keybinds.Playback then
        togglePlayback()
    elseif input.KeyCode == Config.Keybinds.Stop then
        stopAll()
    elseif input.KeyCode == Config.Keybinds.QuickSave then
        -- F5: Quick Save Savestate
        local ss = quickSave()
        if ss then
            print("[GhostWalk] ⚡ Savestate created: " .. ss.name)
            if refreshSavestateList then
                refreshSavestateList()
            end
        end
    elseif input.KeyCode == Config.Keybinds.QuickLoad then
        -- F9: Quick Load Savestate
        if quickLoad() then
            print("[GhostWalk] ⚡ Loaded last savestate!")
            if refreshSavestateList then
                refreshSavestateList()
            end
        else
            print("[GhostWalk] No savestate to load!")
        end
    end
end)
table.insert(_G.GhostWalk.Connections, actionKeybindConn)

-- ==================== POPULATE RECORD TAB ====================
local recordPage = tabPages["Record"]

createLabel(recordPage, "Recording Controls")

local recStatusFrame = Instance.new("Frame")
recStatusFrame.Size = UDim2.new(1, -10, 0, 60)
recStatusFrame.BackgroundColor3 = Colors.Card
recStatusFrame.Parent = recordPage
Instance.new("UICorner", recStatusFrame).CornerRadius = UDim.new(0, 8)

recStatusText = Instance.new("TextLabel")
recStatusText.Size = UDim2.new(1, 0, 0, 25)
recStatusText.Position = UDim2.new(0, 0, 0, 10)
recStatusText.BackgroundTransparency = 1
recStatusText.Text = "Status: IDLE"
recStatusText.TextColor3 = Colors.TextPrimary
recStatusText.Font = Enum.Font.GothamBold
recStatusText.TextSize = 14
recStatusText.Parent = recStatusFrame

recFramesText = Instance.new("TextLabel")
recFramesText.Size = UDim2.new(1, 0, 0, 20)
recFramesText.Position = UDim2.new(0, 0, 0, 35)
recFramesText.BackgroundTransparency = 1
recFramesText.Text = "Frames: 0 | Duration: 0.0s"
recFramesText.TextColor3 = Colors.TextSecondary
recFramesText.Font = Enum.Font.Gotham
recFramesText.TextSize = 12
recFramesText.Parent = recStatusFrame

createLabel(recordPage, "Recording Settings")

createSlider(recordPage, "Record Interval (ms)", 50, 200, Config.Recording.Interval * 1000, function(v)
    Config.Recording.Interval = v / 1000
end)

createLabel(recordPage, "Actions")

local recBtnRow = Instance.new("Frame")
recBtnRow.Size = UDim2.new(1, -10, 0, 45)
recBtnRow.BackgroundTransparency = 1
recBtnRow.Parent = recordPage

local recBtnLayout = Instance.new("UIListLayout", recBtnRow)
recBtnLayout.FillDirection = Enum.FillDirection.Horizontal
recBtnLayout.Padding = UDim.new(0, 10)

createButton(recBtnRow, "🔴 Start", Colors.Red, function()
    startRecording()
    recStatusText.Text = "Status: RECORDING"
    recStatusText.TextColor3 = Colors.Red
end)

createButton(recBtnRow, "⏹️ Stop", Colors.CardHover, function()
    stopRecording()
    recStatusText.Text = "Status: IDLE"
    recStatusText.TextColor3 = Colors.TextPrimary
    recFramesText.Text = string.format("Frames: %d | Duration: %.1fs", 
        #State.CurrentRecording.frames, 
        State.CurrentRecording.metadata.duration)
end)

createButton(recBtnRow, "🗑️ Clear", Colors.CardHover, function()
    State.CurrentRecording.frames = {}
    State.CurrentRecording.metadata.totalFrames = 0
    State.CurrentRecording.metadata.duration = 0
    recFramesText.Text = "Frames: 0 | Duration: 0.0s"
    updateRecordingStats()
    print("[GhostWalk] Recording cleared!")
end)

-- ==================== POPULATE PLAYBACK TAB ====================
local playbackPage = tabPages["Playback"]

createLabel(playbackPage, "Playback Controls")

local playStatusFrame = Instance.new("Frame")
playStatusFrame.Size = UDim2.new(1, -10, 0, 60)
playStatusFrame.BackgroundColor3 = Colors.Card
playStatusFrame.Parent = playbackPage
Instance.new("UICorner", playStatusFrame).CornerRadius = UDim.new(0, 8)

playStatusText = Instance.new("TextLabel")
playStatusText.Size = UDim2.new(1, 0, 0, 25)
playStatusText.Position = UDim2.new(0, 0, 0, 10)
playStatusText.BackgroundTransparency = 1
playStatusText.Text = "Status: IDLE"
playStatusText.TextColor3 = Colors.TextPrimary
playStatusText.Font = Enum.Font.GothamBold
playStatusText.TextSize = 14
playStatusText.Parent = playStatusFrame

playProgressText = Instance.new("TextLabel")
playProgressText.Size = UDim2.new(1, 0, 0, 20)
playProgressText.Position = UDim2.new(0, 0, 0, 35)
playProgressText.BackgroundTransparency = 1
playProgressText.Text = "Progress: 0/0 frames"
playProgressText.TextColor3 = Colors.TextSecondary
playProgressText.Font = Enum.Font.Gotham
playProgressText.TextSize = 12
playProgressText.Parent = playStatusFrame

createLabel(playbackPage, "Playback Settings")

createSlider(playbackPage, "Speed", 50, 200, Config.Playback.Speed * 100, function(v)
    Config.Playback.Speed = v / 100
end)

createToggle(playbackPage, "Loop Playback", Config.Playback.Loop, function(v)
    Config.Playback.Loop = v
end)

createToggle(playbackPage, "Smart Recovery", Config.FallRecovery.Enabled, function(v)
    Config.FallRecovery.Enabled = v
end)

createDropdown(playbackPage, "Movement Method", {"Hybrid+", "Spline", "AlignPosition", "Hybrid", "Physics", "Humanoid", "Teleport"}, Config.Playback.Method, function(v)
    Config.Playback.Method = v
    print("[GhostWalk] Movement method set to:", v)
end)

createLabel(playbackPage, "Practice Mode")

createToggle(playbackPage, "Enable Practice Mode", Config.PracticeMode.Enabled, function(v)
    Config.PracticeMode.Enabled = v
end)

createToggle(playbackPage, "Auto-pause at Obstacles", Config.PracticeMode.AutoPause, function(v)
    Config.PracticeMode.AutoPause = v
end)

createLabel(playbackPage, "Actions")

local playBtnRow = Instance.new("Frame")
playBtnRow.Size = UDim2.new(1, -10, 0, 45)
playBtnRow.BackgroundTransparency = 1
playBtnRow.Parent = playbackPage

local playBtnLayout = Instance.new("UIListLayout", playBtnRow)
playBtnLayout.FillDirection = Enum.FillDirection.Horizontal
playBtnLayout.Padding = UDim.new(0, 10)

createButton(playBtnRow, "▶️ Play", Colors.Green, function()
    startPlayback()
    playStatusText.Text = "Status: PLAYING"
    playStatusText.TextColor3 = Colors.Green
end)

createButton(playBtnRow, "⏹️ Stop", Colors.CardHover, function()
    stopPlayback()
    playStatusText.Text = "Status: IDLE"
    playStatusText.TextColor3 = Colors.TextPrimary
end)

-- ==================== POPULATE SETTINGS TAB ====================
local settingsPage = tabPages["Settings"]

createLabel(settingsPage, "Visual Settings")

createToggle(settingsPage, "Show Trail", Config.Visuals.ShowTrail, function(v)
    Config.Visuals.ShowTrail = v
end)

createSlider(settingsPage, "Trail Duration (s)", 1, 10, Config.Visuals.TrailFadeDuration, function(v)
    Config.Visuals.TrailFadeDuration = v
end)

createLabel(settingsPage, "Smart Systems")

createToggle(settingsPage, "Smart Timeout", Config.SmartTimeout.Enabled, function(v)
    Config.SmartTimeout.Enabled = v
end)

createSlider(settingsPage, "Timeout Buffer (%)", 10, 50, Config.SmartTimeout.Buffer * 100, function(v)
    Config.SmartTimeout.Buffer = v / 100
end)

createSlider(settingsPage, "Default Timeout (s)", 5, 30, Config.SmartTimeout.DefaultTimeout, function(v)
    Config.SmartTimeout.DefaultTimeout = v
end)

createLabel(settingsPage, "Fall Recovery")

createToggle(settingsPage, "Enable Fall Recovery", Config.FallRecovery.Enabled, function(v)
    Config.FallRecovery.Enabled = v
end)

createSlider(settingsPage, "Fall Threshold (studs)", 5, 30, Config.FallRecovery.Threshold, function(v)
    Config.FallRecovery.Threshold = v
end)

createToggle(settingsPage, "Smart Speed Recovery", Config.FallRecovery.SmartSpeed, function(v)
    Config.FallRecovery.SmartSpeed = v
end)

createLabel(settingsPage, "🦘 Predictive Jump (Parkour)")

createToggle(settingsPage, "Enable Predictive Jump", Config.PredictiveJump.Enabled, function(v)
    Config.PredictiveJump.Enabled = v
end)

createToggle(settingsPage, "Gap Detection", Config.PredictiveJump.GapDetection, function(v)
    Config.PredictiveJump.GapDetection = v
end)

createToggle(settingsPage, "Edge Detection", Config.PredictiveJump.EdgeDetection, function(v)
    Config.PredictiveJump.EdgeDetection = v
end)

createToggle(settingsPage, "Jump Arc Calculation", Config.PredictiveJump.JumpArcCalc, function(v)
    Config.PredictiveJump.JumpArcCalc = v
end)

createSlider(settingsPage, "Early Jump Distance", 10, 40, Config.PredictiveJump.EarlyJumpDistance * 10, function(v)
    Config.PredictiveJump.EarlyJumpDistance = v / 10
end)

createToggle(settingsPage, "Debug Print Jump Reasons", Config.PredictiveJump.DebugPrint, function(v)
    Config.PredictiveJump.DebugPrint = v
end)

createLabel(settingsPage, "Keybinds Info")

local keybindInfo = Instance.new("TextLabel")
keybindInfo.Size = UDim2.new(1, -10, 0, 100)
keybindInfo.BackgroundColor3 = Colors.Card
keybindInfo.Text = "R = Record    |  P = Playback\nX = Stop      |  RightShift = Toggle GUI\nF5 = Quick Save Savestate\nF9 = Quick Load Savestate"
keybindInfo.TextColor3 = Colors.TextSecondary
keybindInfo.Font = Enum.Font.Code
keybindInfo.TextSize = 12
keybindInfo.Parent = settingsPage
Instance.new("UICorner", keybindInfo).CornerRadius = UDim.new(0, 8)

-- ==================== POPULATE ROUTES TAB ====================
local routesPage = tabPages["Routes"]

createLabel(routesPage, "Saved Routes")

local noRoutesLabel = Instance.new("TextLabel")
noRoutesLabel.Size = UDim2.new(1, -10, 0, 60)
noRoutesLabel.BackgroundColor3 = Colors.Card
noRoutesLabel.Text = "No saved routes yet.\nRecord a route and save it!"
noRoutesLabel.TextColor3 = Colors.TextMuted
noRoutesLabel.Font = Enum.Font.Gotham
noRoutesLabel.TextSize = 12
noRoutesLabel.Parent = routesPage
Instance.new("UICorner", noRoutesLabel).CornerRadius = UDim.new(0, 8)

createLabel(routesPage, "Current Route")

local currentRouteFrame = Instance.new("Frame")
currentRouteFrame.Size = UDim2.new(1, -10, 0, 70)
currentRouteFrame.BackgroundColor3 = Colors.Card
currentRouteFrame.Parent = routesPage
Instance.new("UICorner", currentRouteFrame).CornerRadius = UDim.new(0, 8)

local routeNameLabel = Instance.new("TextLabel")
routeNameLabel.Size = UDim2.new(1, -20, 0, 25)
routeNameLabel.Position = UDim2.new(0, 10, 0, 10)
routeNameLabel.BackgroundTransparency = 1
routeNameLabel.Text = "Route: " .. State.CurrentRouteName
routeNameLabel.TextColor3 = Colors.TextPrimary
routeNameLabel.Font = Enum.Font.GothamBold
routeNameLabel.TextSize = 13
routeNameLabel.TextXAlignment = Enum.TextXAlignment.Left
routeNameLabel.Parent = currentRouteFrame

routeStatsLabel = Instance.new("TextLabel")
routeStatsLabel.Size = UDim2.new(1, -20, 0, 20)
routeStatsLabel.Position = UDim2.new(0, 10, 0, 35)
routeStatsLabel.BackgroundTransparency = 1
routeStatsLabel.Text = "Frames: 0 | Duration: 0.0s"
routeStatsLabel.TextColor3 = Colors.TextSecondary
routeStatsLabel.Font = Enum.Font.Gotham
routeStatsLabel.TextSize = 11
routeStatsLabel.TextXAlignment = Enum.TextXAlignment.Left
routeStatsLabel.Parent = currentRouteFrame

createLabel(routesPage, "Actions")

local routeBtnRow = Instance.new("Frame")
routeBtnRow.Size = UDim2.new(1, -10, 0, 45)
routeBtnRow.BackgroundTransparency = 1
routeBtnRow.Parent = routesPage

local routeBtnLayout = Instance.new("UIListLayout", routeBtnRow)
routeBtnLayout.FillDirection = Enum.FillDirection.Horizontal
routeBtnLayout.Padding = UDim.new(0, 10)

createButton(routeBtnRow, "💾 Save", Colors.Accent, function()
    if #State.CurrentRecording.frames > 0 then
        -- Apply keyframe extraction if enabled
        local framesToSave = State.CurrentRecording.frames
        local extractionApplied = false
        
        if Config.Recording.KeyframeExtraction then
            local originalCount = #framesToSave
            framesToSave = extractKeyframes(framesToSave, Config.Recording.KeyframeThreshold)
            extractionApplied = true
            local reduction = math.floor((1 - #framesToSave / originalCount) * 100)
            print(string.format("[GhostWalk] Keyframe extraction: %d → %d frames (-%d%%)", originalCount, #framesToSave, reduction))
        end
        
        local route = {
            name = State.CurrentRouteName,
            recording = {
                metadata = State.CurrentRecording.metadata,
                frames = framesToSave,
            },
            keyframeExtracted = extractionApplied,
        }
        table.insert(State.SavedRoutes, route)
        print("[GhostWalk] Route saved: " .. State.CurrentRouteName)
    else
        print("[GhostWalk] No recording to save!")
    end
end)

createButton(routeBtnRow, "📤 Export", Colors.Green, function()
    if #State.CurrentRecording.frames > 0 then
        -- Convert recording to compact JSON format
        local exportData = {
            v = "2.0", -- Version
            name = State.CurrentRouteName,
            meta = {
                t = State.CurrentRecording.metadata.duration,
                h = State.CurrentRecording.metadata.avatarHeight,
                n = #State.CurrentRecording.frames,
            },
            frames = {}
        }
        
        -- Compress frame data (use short keys)
        for i, f in ipairs(State.CurrentRecording.frames) do
            local compactFrame = {
                t = math.floor(f.timestamp * 1000) / 1000, -- 3 decimal places
                p = {
                    math.floor(f.position.X * 10) / 10,
                    math.floor(f.position.Y * 10) / 10,
                    math.floor(f.position.Z * 10) / 10,
                },
                r = {
                    math.floor(f.rotation[1] * 100) / 100,
                    math.floor(f.rotation[2] * 100) / 100,
                    math.floor(f.rotation[3] * 100) / 100,
                },
                g = f.isGrounded and 1 or 0,
            }
            -- Only add type if not MOVE (save space)
            if f.type == "JUMP" then
                compactFrame.j = f.jumpPhase == "START" and 1 or (f.jumpPhase == "PEAK" and 2 or 3)
            end
            -- Add velocity if significant
            if f.velocity and f.velocity.Magnitude > 1 then
                compactFrame.v = {
                    math.floor(f.velocity.X),
                    math.floor(f.velocity.Y),
                    math.floor(f.velocity.Z),
                }
            end
            table.insert(exportData.frames, compactFrame)
        end
        
        -- Encode to JSON
        local success, json = pcall(function()
            return HttpService:JSONEncode(exportData)
        end)
        
        if success then
            -- Copy to clipboard
            if setclipboard then
                setclipboard(json)
                print("[GhostWalk] ✅ Route exported to clipboard! (" .. #json .. " bytes)")
                print("[GhostWalk] Frames: " .. #exportData.frames .. ", Duration: " .. exportData.meta.t .. "s")
            else
                print("[GhostWalk] ⚠️ Clipboard not available. JSON printed to console:")
                print(json)
            end
        else
            print("[GhostWalk] ❌ Export failed: " .. tostring(json))
        end
    else
        print("[GhostWalk] No recording to export!")
    end
end)

-- Second row for Import
createLabel(routesPage, "Import Route")

local importBtnRow = Instance.new("Frame")
importBtnRow.Size = UDim2.new(1, -10, 0, 45)
importBtnRow.BackgroundTransparency = 1
importBtnRow.Parent = routesPage

local importBtnLayout = Instance.new("UIListLayout", importBtnRow)
importBtnLayout.FillDirection = Enum.FillDirection.Horizontal
importBtnLayout.Padding = UDim.new(0, 10)

createButton(importBtnRow, "📥 Import from Clipboard", Colors.Accent, function()
    -- Try to read from clipboard
    local clipboardData = nil
    if getclipboard then
        local success, data = pcall(getclipboard)
        if success then
            clipboardData = data
        end
    end
    
    if not clipboardData or clipboardData == "" then
        print("[GhostWalk] ❌ Clipboard is empty or not accessible!")
        return
    end
    
    -- Try to parse JSON  
    local success, importData = pcall(function()
        return HttpService:JSONDecode(clipboardData)
    end)
    
    if not success then
        print("[GhostWalk] ❌ Invalid JSON format: " .. tostring(importData))
        return
    end
    
    -- Validate structure
    if not importData.v or not importData.frames or #importData.frames == 0 then
        print("[GhostWalk] ❌ Invalid route format!")
        return
    end
    
    -- Convert compact format back to full format
    local frames = {}
    for _, cf in ipairs(importData.frames) do
        local frame = {
            timestamp = cf.t,
            position = Vector3.new(cf.p[1], cf.p[2], cf.p[3]),
            rotation = {cf.r[1], cf.r[2], cf.r[3]},
            isGrounded = cf.g == 1,
            type = "MOVE",
        }
        
        -- Restore jump type
        if cf.j then
            frame.type = "JUMP"
            if cf.j == 1 then frame.jumpPhase = "START"
            elseif cf.j == 2 then frame.jumpPhase = "PEAK"
            else frame.jumpPhase = "FALL" end
        end
        
        -- Restore velocity
        if cf.v then
            frame.velocity = Vector3.new(cf.v[1], cf.v[2], cf.v[3])
        else
            frame.velocity = Vector3.new(0, 0, 0)
        end
        
        table.insert(frames, frame)
    end
    
    -- Load into current recording
    State.CurrentRecording = {
        metadata = {
            version = importData.v,
            recordedAt = os.time(),
            avatarHeight = importData.meta.h or 3,
            totalFrames = #frames,
            duration = importData.meta.t or 0,
        },
        frames = frames,
    }
    
    State.CurrentRouteName = importData.name or "Imported Route"
    
    -- Update UI
    if routeNameLabel then
        routeNameLabel.Text = "Route: " .. State.CurrentRouteName
    end
    if routeStatsLabel then
        routeStatsLabel.Text = string.format("Frames: %d | Duration: %.1fs", #frames, importData.meta.t or 0)
    end
    
    print("[GhostWalk] ✅ Route imported successfully!")
    print("[GhostWalk] Name: " .. State.CurrentRouteName)
    print("[GhostWalk] Frames: " .. #frames .. ", Duration: " .. (importData.meta.t or 0) .. "s")
end)

-- ==================== POPULATE EDITOR TAB ====================
local editorPage = tabPages["Editor"]

-- ===== SAVESTATE SYSTEM GUI =====
createLabel(editorPage, "⚡ Savestates (TAS Practice)")

-- Quick Save/Load buttons
local savestateBtnRow = Instance.new("Frame")
savestateBtnRow.Size = UDim2.new(1, -10, 0, 45)
savestateBtnRow.BackgroundTransparency = 1
savestateBtnRow.Parent = editorPage

local savestateBtnLayout = Instance.new("UIListLayout", savestateBtnRow)
savestateBtnLayout.FillDirection = Enum.FillDirection.Horizontal
savestateBtnLayout.Padding = UDim.new(0, 10)

createButton(savestateBtnRow, "💾 Quick Save (F5)", Colors.Green, function()
    local ss = quickSave()
    if ss then
        print("[GhostWalk] Savestate created: " .. ss.name)
        refreshSavestateList()
    end
end)

createButton(savestateBtnRow, "📂 Quick Load (F9)", Colors.Accent, function()
    if quickLoad() then
        print("[GhostWalk] Loaded last savestate!")
    else
        print("[GhostWalk] No savestate to load!")
    end
end)

createButton(savestateBtnRow, "🗑️ Clear All", Colors.Red, function()
    State.Savestates = {}
    State.CurrentSavestateIndex = 0
    refreshSavestateList()
    print("[GhostWalk] All savestates cleared!")
end)

-- Savestate counter
local savestateCountLabel = Instance.new("TextLabel")
savestateCountLabel.Size = UDim2.new(1, -10, 0, 25)
savestateCountLabel.BackgroundTransparency = 1
savestateCountLabel.Text = "Savestates: 0 / " .. State.MaxSavestates
savestateCountLabel.TextColor3 = Colors.TextSecondary
savestateCountLabel.Font = Enum.Font.Gotham
savestateCountLabel.TextSize = 12
savestateCountLabel.TextXAlignment = Enum.TextXAlignment.Left
savestateCountLabel.Parent = editorPage

-- Savestates List Container
createLabel(editorPage, "Saved Checkpoints")

local savestateListFrame = Instance.new("ScrollingFrame")
savestateListFrame.Size = UDim2.new(1, -10, 0, 120)
savestateListFrame.BackgroundColor3 = Colors.Card
savestateListFrame.ScrollBarThickness = 4
savestateListFrame.ScrollBarImageColor3 = Colors.Accent
savestateListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
savestateListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
savestateListFrame.Parent = editorPage
Instance.new("UICorner", savestateListFrame).CornerRadius = UDim.new(0, 8)

local savestateListLayout = Instance.new("UIListLayout", savestateListFrame)
savestateListLayout.SortOrder = Enum.SortOrder.LayoutOrder
savestateListLayout.Padding = UDim.new(0, 4)

local savestateListPadding = Instance.new("UIPadding", savestateListFrame)
savestateListPadding.PaddingLeft = UDim.new(0, 5)
savestateListPadding.PaddingRight = UDim.new(0, 5)
savestateListPadding.PaddingTop = UDim.new(0, 5)
savestateListPadding.PaddingBottom = UDim.new(0, 5)

-- Empty state message
local noSavestatesLabel = Instance.new("TextLabel")
noSavestatesLabel.Name = "NoSavestates"
noSavestatesLabel.Size = UDim2.new(1, 0, 0, 40)
noSavestatesLabel.BackgroundTransparency = 1
noSavestatesLabel.Text = "No savestates yet.\nPress F5 to create one!"
noSavestatesLabel.TextColor3 = Colors.TextMuted
noSavestatesLabel.Font = Enum.Font.Gotham
noSavestatesLabel.TextSize = 11
noSavestatesLabel.Parent = savestateListFrame

-- Function to refresh savestate list UI
function refreshSavestateList()
    -- Clear existing items (except NoSavestates label)
    for _, child in ipairs(savestateListFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    -- Update counter
    savestateCountLabel.Text = "Savestates: " .. #State.Savestates .. " / " .. State.MaxSavestates
    
    -- Show/hide empty message
    local noSS = savestateListFrame:FindFirstChild("NoSavestates")
    if noSS then
        noSS.Visible = #State.Savestates == 0
    end
    
    -- Create savestate items
    for i, ss in ipairs(State.Savestates) do
        local item = Instance.new("Frame")
        item.Size = UDim2.new(1, -10, 0, 35)
        item.BackgroundColor3 = (i == State.CurrentSavestateIndex) and Colors.CardActive or Colors.CardHover
        item.LayoutOrder = i
        item.Parent = savestateListFrame
        Instance.new("UICorner", item).CornerRadius = UDim.new(0, 6)
        
        -- Savestate info
        local infoLabel = Instance.new("TextLabel")
        infoLabel.Size = UDim2.new(0.6, -5, 1, 0)
        infoLabel.Position = UDim2.new(0, 8, 0, 0)
        infoLabel.BackgroundTransparency = 1
        infoLabel.Text = string.format("#%d %s", i, ss.name)
        infoLabel.TextColor3 = Colors.TextPrimary
        infoLabel.Font = Enum.Font.Gotham
        infoLabel.TextSize = 11
        infoLabel.TextXAlignment = Enum.TextXAlignment.Left
        infoLabel.TextTruncate = Enum.TextTruncate.AtEnd
        infoLabel.Parent = item
        
        -- Load button
        local loadBtn = Instance.new("TextButton")
        loadBtn.Size = UDim2.new(0, 45, 0, 25)
        loadBtn.Position = UDim2.new(1, -100, 0.5, -12)
        loadBtn.BackgroundColor3 = Colors.Accent
        loadBtn.Text = "Load"
        loadBtn.TextColor3 = Colors.TextPrimary
        loadBtn.Font = Enum.Font.GothamBold
        loadBtn.TextSize = 10
        loadBtn.Parent = item
        Instance.new("UICorner", loadBtn).CornerRadius = UDim.new(0, 4)
        
        loadBtn.MouseButton1Click:Connect(function()
            if loadSavestate(i) then
                print("[GhostWalk] Loaded savestate #" .. i)
                refreshSavestateList()
            end
        end)
        
        -- Delete button
        local delBtn = Instance.new("TextButton")
        delBtn.Size = UDim2.new(0, 30, 0, 25)
        delBtn.Position = UDim2.new(1, -50, 0.5, -12)
        delBtn.BackgroundColor3 = Colors.Red
        delBtn.BackgroundTransparency = 0.3
        delBtn.Text = "✕"
        delBtn.TextColor3 = Colors.TextPrimary
        delBtn.Font = Enum.Font.GothamBold
        delBtn.TextSize = 12
        delBtn.Parent = item
        Instance.new("UICorner", delBtn).CornerRadius = UDim.new(0, 4)
        
        delBtn.MouseButton1Click:Connect(function()
            if deleteSavestate(i) then
                print("[GhostWalk] Deleted savestate #" .. i)
                refreshSavestateList()
            end
        end)
    end
end

-- ===== FRAME STATISTICS =====
createLabel(editorPage, "Frame Statistics")

local statsFrame = Instance.new("Frame")
statsFrame.Size = UDim2.new(1, -10, 0, 100)
statsFrame.BackgroundColor3 = Colors.Card
statsFrame.Parent = editorPage
Instance.new("UICorner", statsFrame).CornerRadius = UDim.new(0, 8)

local statsText = Instance.new("TextLabel")
statsText.Name = "StatsText"
statsText.Size = UDim2.new(1, -20, 1, -20)
statsText.Position = UDim2.new(0, 10, 0, 10)
statsText.BackgroundTransparency = 1
statsText.Text = "No recording loaded.\nRecord something first!"
statsText.TextColor3 = Colors.TextSecondary
statsText.Font = Enum.Font.Code
statsText.TextSize = 11
statsText.TextXAlignment = Enum.TextXAlignment.Left
statsText.TextYAlignment = Enum.TextYAlignment.Top
statsText.Parent = statsFrame

-- ===== KEYFRAME EXTRACTION TOGGLE =====
createLabel(editorPage, "Optimization")

createToggle(editorPage, "Use Keyframe Extraction (smaller files)", Config.Recording.KeyframeExtraction, function(v)
    Config.Recording.KeyframeExtraction = v
end)

createSlider(editorPage, "Keyframe Threshold (studs)", 1, 20, Config.Recording.KeyframeThreshold * 10, function(v)
    Config.Recording.KeyframeThreshold = v / 10
end)

-- Update editor stats when recording stops
local function updateEditorStats()
    if statsFrame and statsFrame:FindFirstChild("StatsText") then
        local frames = State.CurrentRecording.frames
        if #frames > 0 then
            local jumpCount, platformCount, moveCount = 0, 0, 0
            for _, f in ipairs(frames) do
                if f.type == "JUMP" then jumpCount = jumpCount + 1
                elseif f.type == "PLATFORM" then platformCount = platformCount + 1
                else moveCount = moveCount + 1 end
            end
            
            -- Calculate keyframe count if extraction enabled
            local keyframeInfo = ""
            if Config.Recording.KeyframeExtraction then
                local keyframes = extractKeyframes(frames, Config.Recording.KeyframeThreshold)
                local reduction = math.floor((1 - #keyframes / #frames) * 100)
                keyframeInfo = string.format("\nKeyframes: %d (-%d%% size)", #keyframes, reduction)
            end
            
            statsFrame.StatsText.Text = string.format(
                "Total Frames: %d\nDuration: %.1fs\n\nMOVE: %d | JUMP: %d | PLATFORM: %d%s",
                #frames, State.CurrentRecording.metadata.duration,
                moveCount, jumpCount, platformCount, keyframeInfo
            )
        end
    end
end

-- ==================== TRAIL SYSTEM ====================
local trailPoints = {}
local trailConnection = nil

local function createTrailPoint(position)
    if not Config.Visuals.ShowTrail then return end
    
    local point = Drawing.new("Circle")
    point.Position = workspace.CurrentCamera:WorldToViewportPoint(position)
    point.Radius = 3
    point.Color = Colors.Accent
    point.Filled = true
    point.Transparency = 1
    point.Visible = true
    
    table.insert(trailPoints, {
        drawing = point,
        worldPos = position,
        createdAt = tick(),
    })
    
    table.insert(_G.GhostWalk.Drawings, point)
end

local function updateTrail()
    local now = tick()
    local fadeTime = Config.Visuals.TrailFadeDuration
    
    for i = #trailPoints, 1, -1 do
        local point = trailPoints[i]
        local age = now - point.createdAt
        
        if age > fadeTime then
            point.drawing:Remove()
            table.remove(trailPoints, i)
        else
            -- Update position and fade
            local screenPos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(point.worldPos)
            point.drawing.Visible = onScreen and Config.Visuals.ShowTrail
            point.drawing.Position = Vector2.new(screenPos.X, screenPos.Y)
            point.drawing.Transparency = 1 - (age / fadeTime)
        end
    end
end

-- Start trail system
trailConnection = RunService.RenderStepped:Connect(function()
    -- Update existing trail points
    updateTrail()
    
    -- Add new trail point if recording
    if State.Mode == "RECORDING" and Config.Visuals.ShowTrail then
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local pos = LocalPlayer.Character.HumanoidRootPart.Position
            -- Only add point every few frames to avoid too many
            if #trailPoints == 0 or (pos - trailPoints[#trailPoints].worldPos).Magnitude > 2 then
                createTrailPoint(pos)
            end
        end
    end
end)
table.insert(_G.GhostWalk.Connections, trailConnection)

-- ==================== FINAL UPDATES ====================

-- Update editor stats after recording
local originalStopRecording = stopRecording
stopRecording = function()
    originalStopRecording()
    updateEditorStats()
    
    -- Update route stats
    if routeStatsLabel then
        routeStatsLabel.Text = string.format("Frames: %d | Duration: %.1fs",
            #State.CurrentRecording.frames,
            State.CurrentRecording.metadata.duration)
    end
end

-- ==================== DONE ====================
print("[GhostWalk] All systems initialized!")
print("[GhostWalk] Ready to use! Press R to record, P to play.")
