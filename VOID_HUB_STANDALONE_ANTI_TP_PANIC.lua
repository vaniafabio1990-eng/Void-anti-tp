-- VOID HUB - STANDALONE ANTI-TP PANIC
-- Defensive local detector only.
-- Detects extreme forced-looking teleports / void drops.
-- Auto-rejoins after 2 critical events within 5 seconds.
-- Uses normal Roblox TeleportService. No attack/retaliation logic.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local SAMPLE_INTERVAL = 0.05
local RAPID_DISTANCE = 150
local CRITICAL_DISTANCE = 400
local VOID_DROP_Y = -300
local MASSIVE_VOID_DROP_Y = -700
local TELEPORT_SPEED = 2500
local PANIC_WINDOW = 5
local PANIC_COUNT = 2

local autoEscape = true
local escapeInProgress = false
local lastPosition = nil
local lastSampleAt = os.clock()
local lastIncidentAt = -100
local criticalTimes = {}
local incidentCount = 0

local gui = Instance.new("ScreenGui")
gui.Name = "VOID_HUB_ANTI_TP"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100000
gui.Parent = PlayerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(360, 180)
frame.Position = UDim2.new(0, 20, 0.5, -90)
frame.BackgroundColor3 = Color3.fromRGB(25, 30, 51)
frame.BorderSizePixel = 0
frame.Parent = gui

local c = Instance.new("UICorner")
c.CornerRadius = UDim.new(0, 10)
c.Parent = frame

local s = Instance.new("UIStroke")
s.Color = Color3.fromRGB(89, 101, 164)
s.Thickness = 1
s.Transparency = 0.25
s.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 28)
title.Position = UDim2.fromOffset(10, 8)
title.BackgroundTransparency = 1
title.Text = "VOID HUB • ANTI-TP PANIC"
title.TextColor3 = Color3.fromRGB(245, 247, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 52)
status.Position = UDim2.fromOffset(10, 40)
status.BackgroundTransparency = 1
status.Text = "Status: ARMED\nWaiting for movement..."
status.TextColor3 = Color3.fromRGB(220, 225, 245)
status.Font = Enum.Font.Code
status.TextSize = 12
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.Parent = frame

local toggle = Instance.new("TextButton")
toggle.Size = UDim2.fromOffset(160, 34)
toggle.Position = UDim2.fromOffset(10, 104)
toggle.BackgroundColor3 = Color3.fromRGB(38, 44, 72)
toggle.BorderSizePixel = 0
toggle.Text = "AUTO ESCAPE: ON"
toggle.TextColor3 = Color3.fromRGB(245, 247, 255)
toggle.Font = Enum.Font.GothamBold
toggle.TextSize = 12
toggle.Parent = frame
local tc = Instance.new("UICorner")
tc.CornerRadius = UDim.new(0, 8)
tc.Parent = toggle

local rejoin = Instance.new("TextButton")
rejoin.Size = UDim2.fromOffset(160, 34)
rejoin.Position = UDim2.fromOffset(190, 104)
rejoin.BackgroundColor3 = Color3.fromRGB(38, 44, 72)
rejoin.BorderSizePixel = 0
rejoin.Text = "REJOIN NOW"
rejoin.TextColor3 = Color3.fromRGB(245, 247, 255)
rejoin.Font = Enum.Font.GothamBold
rejoin.TextSize = 12
rejoin.Parent = frame
local rc = Instance.new("UICorner")
rc.CornerRadius = UDim.new(0, 8)
rc.Parent = rejoin

local info = Instance.new("TextLabel")
info.Size = UDim2.new(1, -20, 0, 30)
info.Position = UDim2.fromOffset(10, 144)
info.BackgroundTransparency = 1
info.Text = "2 critical TP/void events within 5s = emergency rejoin"
info.TextColor3 = Color3.fromRGB(170, 180, 215)
info.Font = Enum.Font.Code
info.TextSize = 10
info.TextXAlignment = Enum.TextXAlignment.Left
info.Parent = frame

local function notify(text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "VOID HUB • ANTI-TP",
            Text = text,
            Duration = 4
        })
    end)
end

local function getRoot()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function prune(now)
    local kept = {}
    for _, t in ipairs(criticalTimes) do
        if now - t <= PANIC_WINDOW then
            table.insert(kept, t)
        end
    end
    criticalTimes = kept
end

local function normalRejoin(reason)
    if escapeInProgress then return end
    escapeInProgress = true
    status.Text = "Status: ESCAPING\n" .. tostring(reason)
    notify("Repeated critical teleport/void pattern detected. Rejoining.")

    task.delay(0.35, function()
        local ok, err = pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)

        if not ok then
            escapeInProgress = false
            status.Text = "Status: REJOIN FAILED\n" .. string.sub(tostring(err), 1, 90)
        end
    end)
end

toggle.Activated:Connect(function()
    autoEscape = not autoEscape
    toggle.Text = autoEscape and "AUTO ESCAPE: ON" or "AUTO ESCAPE: OFF"
end)

rejoin.Activated:Connect(function()
    normalRejoin("manual")
end)

LocalPlayer.CharacterAdded:Connect(function()
    lastPosition = nil
    lastSampleAt = os.clock()
    criticalTimes = {}

    task.delay(0.8, function()
        if not escapeInProgress then
            status.Text = "Status: ARMED\nRespawn monitoring active"
        end
    end)
end)

task.spawn(function()
    while gui.Parent do
        task.wait(SAMPLE_INTERVAL)

        if escapeInProgress then
            continue
        end

        local root = getRoot()
        if not root then
            lastPosition = nil
            continue
        end

        local now = os.clock()
        local pos = root.Position

        if not lastPosition then
            lastPosition = pos
            lastSampleAt = now
            continue
        end

        local dt = math.max(now - lastSampleAt, 0.001)
        local delta = pos - lastPosition
        local distance = delta.Magnitude
        local yDelta = delta.Y
        local calculatedSpeed = distance / dt
        local linearVelocity = root.AssemblyLinearVelocity.Magnitude

        local positionSetLike = distance >= RAPID_DISTANCE and linearVelocity < 25
        local strongTeleport = distance >= CRITICAL_DISTANCE or calculatedSpeed >= TELEPORT_SPEED
        local strongVoid = yDelta <= VOID_DROP_Y
        local massiveVoid = yDelta <= MASSIVE_VOID_DROP_Y

        local critical =
            (positionSetLike and strongVoid)
            or massiveVoid
            or (strongTeleport and strongVoid)

        if critical and now - lastIncidentAt >= 0.18 then
            lastIncidentAt = now
            incidentCount += 1

            prune(now)
            table.insert(criticalTimes, now)

            status.Text = string.format(
                "CRITICAL #%d • %.0f studs / %.3fs\nY %.0f • %.0f studs/s • %d/%d in %.0fs",
                incidentCount,
                distance,
                dt,
                yDelta,
                calculatedSpeed,
                #criticalTimes,
                PANIC_COUNT,
                PANIC_WINDOW
            )

            notify(string.format(
                "Critical TP/void detected: %.0f studs, Y %.0f",
                distance,
                yDelta
            ))

            if autoEscape and #criticalTimes >= PANIC_COUNT then
                normalRejoin(
                    tostring(#criticalTimes)
                    .. " critical TP/void events in "
                    .. tostring(PANIC_WINDOW)
                    .. "s"
                )
            end
        end

        lastPosition = pos
        lastSampleAt = now
    end
end)

print("VOID HUB STANDALONE ANTI-TP PANIC LOADED")
