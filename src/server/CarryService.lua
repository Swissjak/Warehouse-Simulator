--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WarehouseShared = ReplicatedStorage:WaitForChild("WarehouseShared")
local CarryConfig = require(WarehouseShared:WaitForChild("CarryConfig"))
local CarryItem = require(WarehouseShared:WaitForChild("CarryItem"))

local CarryService = {}

type PartState = {
	part: BasePart,
	canCollide: boolean,
	massless: boolean,
}

type HoldState = {
	item: Model,
	root: BasePart,
	anchor: BasePart,
	parts: { PartState },
	destroyingConnection: RBXScriptConnection?,
}

local heldByPlayer: { [Player]: HoldState } = {}
local holderByItem: { [Model]: Player } = {}
local deathConnections: { [Player]: RBXScriptConnection } = {}
local playerConnections: { [Player]: { RBXScriptConnection } } = {}
local started = false

local function getItemLabel(item: Model): string
	local itemId = item:GetAttribute("ItemId")
	if typeof(itemId) == "string" and itemId ~= "" then
		return itemId
	end

	return item.Name
end

local function setRootCFrame(item: Model, root: BasePart, targetCFrame: CFrame)
	local rootToPivot = root.CFrame:ToObjectSpace(item:GetPivot())
	item:PivotTo(targetCFrame * rootToPivot)
end

local function setServerNetworkOwnership(parts: { PartState })
	for _, partState in parts do
		local part = partState.part
		if not part.Anchored then
			local canSetOwnership = part:CanSetNetworkOwnership()
			if canSetOwnership then
				part:SetNetworkOwner(nil)
			end
		end
	end
end

local function restorePartStates(parts: { PartState })
	for _, partState in parts do
		local part = partState.part
		if part.Parent ~= nil then
			part.CanCollide = partState.canCollide
			part.Massless = partState.massless

			if not part.Anchored then
				local canSetOwnership = part:CanSetNetworkOwnership()
				if canSetOwnership then
					part:SetNetworkOwnershipAuto()
				end
			end
		end
	end
end

local function clearHeldState(player: Player, itemWasDestroyed: boolean)
	local state = heldByPlayer[player]
	if state == nil then
		return
	end

	heldByPlayer[player] = nil
	if holderByItem[state.item] == player then
		holderByItem[state.item] = nil
	end
	player:SetAttribute(CarryConfig.CarryingAttributeName, false)

	if state.destroyingConnection ~= nil then
		state.destroyingConnection:Disconnect()
		state.destroyingConnection = nil
	end

	if state.anchor.Parent ~= nil then
		state.anchor:Destroy()
	end

	if not itemWasDestroyed then
		restorePartStates(state.parts)
	end
end

local function dropHeldItem(player: Player, placeInFront: boolean, shouldLog: boolean)
	local state = heldByPlayer[player]
	if state == nil then
		return
	end

	local item = state.item
	local itemLabel = getItemLabel(item)

	if state.anchor.Parent ~= nil then
		state.anchor:Destroy()
	end

	if placeInFront and item.Parent ~= nil and state.root.Parent ~= nil then
		local character = player.Character
		local humanoidRootPart = if character ~= nil
			then character:FindFirstChild("HumanoidRootPart")
			else nil

		if humanoidRootPart ~= nil and humanoidRootPart:IsA("BasePart") then
			setRootCFrame(
				item,
				state.root,
				humanoidRootPart.CFrame * CFrame.new(0, 0, -CarryConfig.CarryDistance)
			)
		end
	end

	clearHeldState(player, false)

	if shouldLog then
		print(string.format("[CarryService] %s dropped %s", player.Name, itemLabel))
	end
end

local function collectPartStates(item: Model): { PartState }
	local parts: { PartState } = {}

	for _, descendant in item:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, {
				part = descendant,
				canCollide = descendant.CanCollide,
				massless = descendant.Massless,
			})
		end
	end

	return parts
end

local function isPickupValid(player: Player, item: Model): (boolean, BasePart?)
	local character = player.Character
	if character == nil then
		return false, nil
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart == nil or not humanoidRootPart:IsA("BasePart") then
		return false, nil
	end

	if item.Parent == nil or not item:IsDescendantOf(Workspace) then
		return false, nil
	end
	if item:GetAttribute("Carryable") ~= true then
		return false, nil
	end

	local root = CarryItem.GetRootPart(item)
	if root == nil or not root:IsDescendantOf(item) then
		return false, nil
	end

	local maximumDistance = CarryConfig.InteractionDistance + CarryConfig.ServerDistanceTolerance
	if (humanoidRootPart.Position - root.Position).Magnitude > maximumDistance then
		return false, nil
	end
	if heldByPlayer[player] ~= nil then
		return false, nil
	end
	if holderByItem[item] ~= nil then
		return false, nil
	end

	return true, root
end

local function pickupItem(player: Player, item: Model)
	local isValid, root = isPickupValid(player, item)
	if not isValid or root == nil then
		return
	end

	local character = player.Character :: Model
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart
	local parts = collectPartStates(item)
	if #parts == 0 then
		return
	end

	local anchor = Instance.new("Part")
	anchor.Name = "CarryAnchor"
	anchor.Size = Vector3.new(0.25, 0.25, 0.25)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Massless = true
	anchor.CFrame = humanoidRootPart.CFrame * CFrame.new(0, 0, -CarryConfig.CarryDistance)
	anchor.Parent = character

	local characterWeld = Instance.new("WeldConstraint")
	characterWeld.Name = "CarryCharacterWeld"
	characterWeld.Part0 = humanoidRootPart
	characterWeld.Part1 = anchor
	characterWeld.Parent = anchor

	setRootCFrame(item, root, anchor.CFrame)

	for _, partState in parts do
		partState.part.CanCollide = false
		partState.part.Massless = true
	end
	setServerNetworkOwnership(parts)

	local itemWeld = Instance.new("WeldConstraint")
	itemWeld.Name = "CarryItemWeld"
	itemWeld.Part0 = anchor
	itemWeld.Part1 = root
	itemWeld.Parent = anchor

	local state: HoldState = {
		item = item,
		root = root,
		anchor = anchor,
		parts = parts,
		destroyingConnection = nil,
	}
	heldByPlayer[player] = state
	holderByItem[item] = player
	player:SetAttribute(CarryConfig.CarryingAttributeName, true)

	state.destroyingConnection = item.Destroying:Connect(function()
		clearHeldState(player, true)
	end)

	print(string.format("[CarryService] %s picked up %s", player.Name, getItemLabel(item)))
end

local function getOrCreateRemoteEvent(): RemoteEvent
	local remotes = WarehouseShared:FindFirstChild(CarryConfig.RemotesFolderName)
	if remotes == nil then
		remotes = Instance.new("Folder")
		remotes.Name = CarryConfig.RemotesFolderName
		remotes.Parent = WarehouseShared
	elseif not remotes:IsA("Folder") then
		error(string.format("[CarryService] %s must be a Folder", remotes:GetFullName()))
	end

	local remote = remotes:FindFirstChild(CarryConfig.RemoteEventName)
	if remote == nil then
		remote = Instance.new("RemoteEvent")
		remote.Name = CarryConfig.RemoteEventName
		remote.Parent = remotes
	elseif not remote:IsA("RemoteEvent") then
		error(string.format("[CarryService] %s must be a RemoteEvent", remote:GetFullName()))
	end

	return remote :: RemoteEvent
end

local function connectCharacter(player: Player, character: Model)
	local previousDeathConnection = deathConnections[player]
	if previousDeathConnection ~= nil then
		previousDeathConnection:Disconnect()
		deathConnections[player] = nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		deathConnections[player] = humanoid.Died:Connect(function()
			dropHeldItem(player, false, true)
		end)
	end
end

local function connectPlayer(player: Player)
	player:SetAttribute(CarryConfig.CarryingAttributeName, false)

	local connections = {
		player.CharacterAdded:Connect(function(character)
			connectCharacter(player, character)
		end),
		player.CharacterRemoving:Connect(function()
			dropHeldItem(player, false, true)
		end),
	}
	playerConnections[player] = connections

	if player.Character ~= nil then
		connectCharacter(player, player.Character)
	end
end

local function disconnectPlayer(player: Player)
	dropHeldItem(player, false, true)

	local connections = playerConnections[player]
	if connections ~= nil then
		for _, connection in connections do
			connection:Disconnect()
		end
		playerConnections[player] = nil
	end

	local deathConnection = deathConnections[player]
	if deathConnection ~= nil then
		deathConnection:Disconnect()
		deathConnections[player] = nil
	end
end

function CarryService.Start()
	if started then
		return
	end
	started = true

	local remote = getOrCreateRemoteEvent()
	remote.OnServerEvent:Connect(function(player: Player, action: unknown, itemValue: unknown)
		if action == "Drop" then
			dropHeldItem(player, true, true)
			return
		end

		if action ~= "Pickup" or typeof(itemValue) ~= "Instance" or not itemValue:IsA("Model") then
			return
		end

		pickupItem(player, itemValue)
	end)

	Players.PlayerAdded:Connect(connectPlayer)
	Players.PlayerRemoving:Connect(disconnectPlayer)

	for _, player in Players:GetPlayers() do
		connectPlayer(player)
	end
end

return CarryService
