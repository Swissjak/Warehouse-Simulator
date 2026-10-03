--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WarehouseShared = ReplicatedStorage:WaitForChild("WarehouseShared")
local Config = require(WarehouseShared:WaitForChild("Config"))
local ProductCatalog = require(WarehouseShared:WaitForChild("ProductCatalog"))
local ScannerTarget = require(WarehouseShared:WaitForChild("ScannerTarget"))

local ScannerService = {}

export type ScanSuccess = {
	Success: boolean,
	ItemId: string,
	Barcode: string,
	DisplayName: string,
}

export type ScanFailure = {
	Success: boolean,
	Reason: string,
}

local started = false
local lastRequestAt: { [Player]: number } = {}
local scanSucceededEvent = Instance.new("BindableEvent")

ScannerService.ScanSucceeded = scanSucceededEvent.Event

local function makeFailure(reason: string): ScanFailure
	return {
		Success = false,
		Reason = reason,
	}
end

local function getOrCreateRemoteEvent(): RemoteEvent
	local remotes = WarehouseShared:FindFirstChild(Config.ScannerRemotesFolderName)
	if remotes == nil then
		remotes = Instance.new("Folder")
		remotes.Name = Config.ScannerRemotesFolderName
		remotes.Parent = WarehouseShared
	elseif not remotes:IsA("Folder") then
		error(string.format("[ScannerService] %s must be a Folder", remotes:GetFullName()))
	end

	local remote = remotes:FindFirstChild(Config.ScannerRemoteEventName)
	if remote == nil then
		remote = Instance.new("RemoteEvent")
		remote.Name = Config.ScannerRemoteEventName
		remote.Parent = remotes
	elseif not remote:IsA("RemoteEvent") then
		error(string.format("[ScannerService] %s must be a RemoteEvent", remote:GetFullName()))
	end

	return remote :: RemoteEvent
end

local function getCharacterParts(player: Player): (Model?, BasePart?, BasePart?)
	local character = player.Character
	if character == nil or character.Parent == nil then
		return nil, nil, nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return nil, nil, nil
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart == nil or not humanoidRootPart:IsA("BasePart") then
		return nil, nil, nil
	end

	local head = character:FindFirstChild("Head")
	local lineOfSightOrigin = if head ~= nil and head:IsA("BasePart") then head else humanoidRootPart
	return character, humanoidRootPart, lineOfSightOrigin
end

local function getBounds(item: Model): (CFrame?, Vector3?)
	if item:FindFirstChildWhichIsA("BasePart", true) == nil then
		return nil, nil
	end

	local succeeded, boundsCFrame, boundsSize = pcall(function()
		return item:GetBoundingBox()
	end)
	if not succeeded then
		return nil, nil
	end

	return boundsCFrame, boundsSize
end

local function distanceToBounds(point: Vector3, boundsCFrame: CFrame, boundsSize: Vector3): number
	local localPoint = boundsCFrame:PointToObjectSpace(point)
	local halfSize = boundsSize / 2
	local closestLocalPoint = Vector3.new(
		math.clamp(localPoint.X, -halfSize.X, halfSize.X),
		math.clamp(localPoint.Y, -halfSize.Y, halfSize.Y),
		math.clamp(localPoint.Z, -halfSize.Z, halfSize.Z)
	)
	local closestWorldPoint = boundsCFrame:PointToWorldSpace(closestLocalPoint)
	return (point - closestWorldPoint).Magnitude
end

local function hasLineOfSight(character: Model, originPart: BasePart, item: Model, targetPosition: Vector3): boolean
	local direction = targetPosition - originPart.Position
	if direction.Magnitude <= 0.001 then
		return true
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.IgnoreWater = true

	local result = Workspace:Raycast(originPart.Position, direction, raycastParams)
	return result ~= nil and result.Instance:IsDescendantOf(item)
end

local function validateScan(player: Player, targetValue: unknown): (Model?, ScanSuccess?, ScanFailure?)
	local character, humanoidRootPart, lineOfSightOrigin = getCharacterParts(player)
	if character == nil or humanoidRootPart == nil or lineOfSightOrigin == nil then
		return nil, nil, makeFailure("INVALID_CHARACTER")
	end

	if typeof(targetValue) ~= "Instance" then
		return nil, nil, makeFailure("NO_TARGET")
	end

	local item = ScannerTarget.FindPhysicalBoxModel(targetValue)
	if item == nil or item:GetAttribute("ItemType") ~= "Box" then
		return nil, nil, makeFailure("INVALID_ITEM")
	end
	if item.Parent == nil or not item:IsDescendantOf(Workspace) then
		return nil, nil, makeFailure("INVALID_ITEM")
	end

	local itemId = ScannerTarget.GetItemId(item)
	if itemId == nil then
		return nil, nil, makeFailure("INVALID_ITEM")
	end

	local product = ProductCatalog.Get(itemId)
	if product == nil then
		return nil, nil, makeFailure("UNKNOWN_PRODUCT")
	end

	local boundsCFrame, boundsSize = getBounds(item)
	if boundsCFrame == nil or boundsSize == nil then
		return nil, nil, makeFailure("INVALID_ITEM")
	end
	if distanceToBounds(humanoidRootPart.Position, boundsCFrame, boundsSize) > Config.ScannerMaxDistance then
		return nil, nil, makeFailure("TOO_FAR")
	end

	if not hasLineOfSight(character, lineOfSightOrigin, item, boundsCFrame.Position) then
		return nil, nil, makeFailure("BLOCKED")
	end

	local result: ScanSuccess = {
		Success = true,
		ItemId = product.ItemId,
		Barcode = product.Barcode,
		DisplayName = product.DisplayName,
	}
	return item, result, nil
end

local function handleScan(remote: RemoteEvent, player: Player, targetValue: unknown)
	if player.Parent ~= Players then
		return
	end

	local now = os.clock()
	local previousRequestAt = lastRequestAt[player]
	if previousRequestAt ~= nil and now - previousRequestAt < Config.ScannerRequestCooldown then
		remote:FireClient(player, makeFailure("COOLDOWN"))
		return
	end
	lastRequestAt[player] = now

	local item, successResult, failureResult = validateScan(player, targetValue)
	if item == nil or successResult == nil then
		remote:FireClient(player, failureResult or makeFailure("INVALID_ITEM"))
		return
	end

	if item.Parent == nil or not item:IsDescendantOf(Workspace) then
		remote:FireClient(player, makeFailure("INVALID_ITEM"))
		return
	end

	scanSucceededEvent:Fire(player, item, successResult)
	remote:FireClient(player, successResult)
end

function ScannerService.Start()
	if started then
		return
	end
	started = true

	local remote = getOrCreateRemoteEvent()
	remote.OnServerEvent:Connect(function(player: Player, targetValue: unknown)
		handleScan(remote, player, targetValue)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastRequestAt[player] = nil
	end)
end

return ScannerService
