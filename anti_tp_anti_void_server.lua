-- VOID HUB - SERVER ANTI TP + ANTI VOID
-- For a Roblox experience you own/control.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VOID_MARGIN = 18
local MAX_TP_DISTANCE = 85

local States = {}

local function getRoot(player)
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(player)
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

local function resetState(player)
	States[player] = {
		AntiTP = true,
		AntiVoid = true,
		LastSafeCFrame = nil,
		LastPosition = nil,
		AllowTeleportUntil = 0,
	}
end

local function allowTeleport(player, duration)
	local state = States[player]

	if state then
		state.AllowTeleportUntil =
			os.clock() + (duration or 1)
	end
end

local function restore(player, state)
	local root = getRoot(player)

	if not root
		or not state.LastSafeCFrame then
		return
	end

	root.AssemblyLinearVelocity =
		Vector3.zero

	root.AssemblyAngularVelocity =
		Vector3.zero

	player.Character:PivotTo(
		state.LastSafeCFrame
	)

	state.LastPosition =
		state.LastSafeCFrame.Position
end

local function setupCharacter(player)
	local state = States[player]

	if not state then
		resetState(player)
		state = States[player]
	end

	task.wait(1)

	local root = getRoot(player)

	if root then
		state.LastPosition =
			root.Position

		state.LastSafeCFrame =
			root.CFrame

		allowTeleport(
			player,
			2
		)
	end
end

Players.PlayerAdded:Connect(function(player)

	resetState(player)

	player.CharacterAdded:Connect(function()
		setupCharacter(player)
	end)

	if player.Character then
		task.spawn(
			setupCharacter,
			player
		)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	States[player] = nil
end)

for _, player in ipairs(
	Players:GetPlayers()
) do

	resetState(player)

	player.CharacterAdded:Connect(function()
		setupCharacter(player)
	end)

	if player.Character then
		task.spawn(
			setupCharacter,
			player
		)
	end
end

RunService.Heartbeat:Connect(function()

	for player, state in pairs(States) do

		local root =
			getRoot(player)

		local humanoid =
			getHumanoid(player)

		if root
			and humanoid
			and humanoid.Health > 0 then

			local destroyHeight =
				workspace.FallenPartsDestroyHeight

			local nearVoid =
				root.Position.Y
				<= destroyHeight
				+ VOID_MARGIN

			--------------------------------------------------
			-- ANTI VOID
			--------------------------------------------------

			if state.AntiVoid
				and nearVoid
				and state.LastSafeCFrame then

				restore(
					player,
					state
				)

				continue
			end

			--------------------------------------------------
			-- ANTI TP
			--------------------------------------------------

			if state.AntiTP
				and state.LastPosition
				and os.clock()
					> state.AllowTeleportUntil then

				local distance =
					(
						root.Position
						- state.LastPosition
					).Magnitude

				if distance >
					MAX_TP_DISTANCE
					and state.LastSafeCFrame then

					restore(
						player,
						state
					)

					continue
				end
			end

			--------------------------------------------------
			-- UPDATE SAFE POSITION
			--------------------------------------------------

			if not nearVoid then

				state.LastSafeCFrame =
					root.CFrame
			end

			state.LastPosition =
				root.Position
		end
	end
end)

print(
	"VOID HUB SERVER ANTI TP + ANTI VOID ACTIVE"
)
