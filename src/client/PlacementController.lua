--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local WarehouseShared = ReplicatedStorage:WaitForChild("WarehouseShared")
local CarryConfig = require(WarehouseShared:WaitForChild("CarryConfig"))
local CarryItem = require(WarehouseShared:WaitForChild("CarryItem"))
local PlacementGeometry = require(WarehouseShared:WaitForChild("PlacementGeometry"))
local PlacementRules = require(WarehouseShared:WaitForChild("PlacementRules"))
local PalletPlacementRules = require(WarehouseShared:WaitForChild("PalletPlacementRules"))

local PlacementController = {}

type LocalPartState = {
	part: BasePart,
	localTransparencyModifier: number,
}

local VALID_COLOR = Color3.fromRGB(60, 220, 90)
local INVALID_COLOR = Color3.fromRGB(235, 70, 70)
local RUNTIME_CARRY_NAMES: { [string]: boolean } = {
	CarryAnchor = true,
	CarryCharacterWeld = true,
	CarryItemWeld = true,
}

local started = false
local carryRemote: RemoteEvent? = nil
local heldItem: Model? = nil
local heldItemDestroyingConnection: RBXScriptConnection? = nil
local heldPartStates: { LocalPartState } = {}
local ghost: Model? = nil
local ghostHighlight: Highlight? = nil
local ghostParts: { BasePart } = {}
local displayedValidity: boolean? = nil
local boundsInfo: PlacementGeometry.BoundsInfo? = nil
local candidateCFrame: CFrame? = nil
local candidatePallet: Model? = nil
local candidateIsValid = false
local rotationStep = 0
local lastPlaceRequestTime = 0
local cachedGeneratedRacks: Instance? = nil
local slotParts: { BasePart } = {}

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude
overlapParams.MaxParts = 0

local function refreshSlotParts()
	slotParts = {}
	cachedGeneratedRacks = nil

	local warehouse = Workspace:FindFirstChild("Warehouse")
	local generatedRacks = if warehouse ~= nil then warehouse:FindFirstChild("GeneratedRacks") else nil
	if generatedRacks == nil then
		return
	end
	cachedGeneratedRacks = generatedRacks

	for _, descendant in generatedRacks:GetDescendants() do
		if
			descendant:IsA("BasePart")
			and typeof(descendant:GetAttribute("SlotId")) == "string"
			and PlacementRules.GetSlotMaxHeight(descendant) ~= nil
		then
			table.insert(slotParts, descendant)
		end
	end
end

local function getSlotParts(): { BasePart }
	if cachedGeneratedRacks == nil or cachedGeneratedRacks.Parent == nil or #slotParts == 0 then
		refreshSlotParts()
	end

	return slotParts
end

local function destroyGhost()
	if ghost ~= nil then
		ghost:Destroy()
	end

	ghost = nil
	ghostHighlight = nil
	ghostParts = {}
	displayedValidity = nil
	boundsInfo = nil
	candidateCFrame = nil
	candidatePallet = nil
	candidateIsValid = false
end

local function restoreHeldItemVisibility()
	for _, partState in heldPartStates do
		if partState.part.Parent ~= nil then
			partState.part.LocalTransparencyModifier = partState.localTransparencyModifier
		end
	end

	heldPartStates = {}
end

local function hideHeldItemLocally(item: Model)
	restoreHeldItemVisibility()

	for _, descendant in item:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(heldPartStates, {
				part = descendant,
				localTransparencyModifier = descendant.LocalTransparencyModifier,
			})
			descendant.LocalTransparencyModifier = 1
		end
	end
end

local function shouldRemoveFromGhost(instance: Instance): boolean
	return instance:IsA("Script")
		or instance:IsA("LocalScript")
		or instance:IsA("ModuleScript")
		or instance:IsA("Constraint")
		or instance:IsA("JointInstance")
		or instance:IsA("WeldConstraint")
		or RUNTIME_CARRY_NAMES[instance.Name] == true
end

local function prepareGhost(model: Model): { BasePart }
	for _, descendant in model:GetDescendants() do
		if shouldRemoveFromGhost(descendant) then
			descendant:Destroy()
		end
	end

	local parts: { BasePart } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			descendant.Transparency = math.max(descendant.Transparency, CarryConfig.GhostTransparency)
		end
	end

	return parts
end

local function setGhostColor(isValid: boolean)
	local highlight = ghostHighlight
	if highlight == nil then
		return
	end
	if displayedValidity == isValid then
		return
	end
	displayedValidity = isValid

	local color = if isValid then VALID_COLOR else INVALID_COLOR
	highlight.FillColor = color
	highlight.OutlineColor = color
	for _, part in ghostParts do
		part.Color = color
	end
end

local function createGhost(item: Model): boolean
	destroyGhost()
	rotationStep = 0

	local succeeded, clonedInstance = pcall(function()
		return item:Clone()
	end)
	if not succeeded or clonedInstance == nil or not clonedInstance:IsA("Model") then
		warn(string.format("[PlacementController] Could not clone %s for placement preview", item:GetFullName()))
		return false
	end

	local newGhost = clonedInstance :: Model
	newGhost.Name = "PlacementGhost"
	if newGhost.PrimaryPart == nil then
		local root = CarryItem.GetRootPart(newGhost)
		if root ~= nil then
			newGhost.PrimaryPart = root
		end
	end
	local preparedParts = prepareGhost(newGhost)
	if #preparedParts == 0 then
		newGhost:Destroy()
		warn(string.format("[PlacementController] %s preview has no BaseParts", item:GetFullName()))
		return false
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "PlacementHighlight"
	highlight.Adornee = newGhost
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillTransparency = 0.45
	highlight.OutlineTransparency = 0
	highlight.Parent = newGhost

	newGhost.Parent = Workspace

	ghost = newGhost
	ghostHighlight = highlight
	ghostParts = preparedParts
	boundsInfo = PlacementGeometry.GetBoundsInfo(newGhost)
	setGhostColor(false)

	return true
end

local function setHeldItem(item: Model?)
	if heldItem == item and ghost ~= nil then
		return
	end

	restoreHeldItemVisibility()
	if heldItemDestroyingConnection ~= nil then
		heldItemDestroyingConnection:Disconnect()
		heldItemDestroyingConnection = nil
	end

	heldItem = item
	destroyGhost()
	rotationStep = 0

	if item ~= nil and item.Parent ~= nil then
		refreshSlotParts()
		heldItemDestroyingConnection = item.Destroying:Connect(function()
			restoreHeldItemVisibility()
			heldItem = nil
			heldItemDestroyingConnection = nil
			destroyGhost()
		end)

		if createGhost(item) then
			hideHeldItemLocally(item)
		end
	end
end

local function hasCollidableOverlap(boundsCFrame: CFrame, boundsSize: Vector3): boolean
	local parts = Workspace:GetPartBoundsInBox(boundsCFrame, PlacementGeometry.GetShrunkSize(boundsSize), overlapParams)

	for _, part in parts do
		if part.CanCollide then
			return true
		end
	end

	return false
end

local function updateCandidate()
	local currentGhost = ghost
	local currentItem = heldItem
	local currentBoundsInfo = boundsInfo
	local camera = Workspace.CurrentCamera
	if currentGhost == nil or currentItem == nil or currentBoundsInfo == nil or camera == nil then
		candidateCFrame = nil
		candidatePallet = nil
		candidateIsValid = false
		return
	end
	if currentItem.Parent == nil then
		setHeldItem(nil)
		return
	end

	local character = player.Character
	local ignoredInstances: { Instance } = { currentItem, currentGhost }
	if character ~= nil then
		table.insert(ignoredInstances, character)
	end
	raycastParams.FilterDescendantsInstances = ignoredInstances

	local viewportCenter = camera.ViewportSize / 2
	local ray = camera:ViewportPointToRay(viewportCenter.X, viewportCenter.Y)
	local result = Workspace:Raycast(ray.Origin, ray.Direction * CarryConfig.PlacementRayDistance, raycastParams)
	local palletInfo = if result ~= nil then PalletPlacementRules.FindPalletInfo(result.Instance) else nil
	local raycastSupport = if result ~= nil then CarryItem.FindCarryableModel(result.Instance) else nil
	local stackSupport = if raycastSupport ~= nil
			and palletInfo == nil
			and PlacementRules.HaveMatchingItemIds(currentItem, raycastSupport)
		then raycastSupport
		else nil
	local surfacePoint = if result ~= nil
		then result.Position
		else ray.Origin + ray.Direction * CarryConfig.PlacementRayDistance
	local newCandidateCFrame = if palletInfo ~= nil
		then PalletPlacementRules.CreateCandidateCFrame(palletInfo.loadArea, rotationStep, currentBoundsInfo)
		elseif stackSupport ~= nil
		then PlacementRules.CreateStackCandidateCFrame(stackSupport, rotationStep, currentBoundsInfo)
		else PlacementGeometry.CreateCandidateCFrame(surfacePoint, rotationStep, currentBoundsInfo)
	currentGhost:PivotTo(newCandidateCFrame)
	candidateCFrame = newCandidateCFrame
	candidatePallet = if palletInfo ~= nil then palletInfo.model else nil

	local surfaceIsValid = if palletInfo ~= nil
		then result ~= nil
		else result ~= nil
			and result.Normal.Y >= CarryConfig.PlacementSurfaceNormalMinY
			and result.Instance.CanCollide
			and (raycastSupport == nil or stackSupport ~= nil)

	local humanoidRootPart = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local distanceIsValid = humanoidRootPart ~= nil
		and humanoidRootPart:IsA("BasePart")
		and (humanoidRootPart.Position - newCandidateCFrame.Position).Magnitude <= CarryConfig.PlacementDistance

	local candidateBoundsCFrame, candidateBoundsSize =
		PlacementGeometry.GetWorldBounds(newCandidateCFrame, currentBoundsInfo)
	local overlapIgnoredInstances = table.clone(ignoredInstances)
	if stackSupport ~= nil then
		table.insert(overlapIgnoredInstances, stackSupport)
	end
	overlapParams.FilterDescendantsInstances = overlapIgnoredInstances
	local overlapIsValid = not hasCollidableOverlap(candidateBoundsCFrame, candidateBoundsSize)
	if palletInfo ~= nil then
		local footprintIsValid = PalletPlacementRules.DoesFootprintFit(
			palletInfo.loadArea,
			candidateBoundsCFrame,
			candidateBoundsSize
		)
		local heightIsValid = PalletPlacementRules.IsHeightValid(
			palletInfo,
			candidateBoundsCFrame,
			candidateBoundsSize
		)
		local palletIsEmpty = PalletPlacementRules.IsEmpty(palletInfo, ignoredInstances)

		candidateIsValid = surfaceIsValid
			and distanceIsValid
			and footprintIsValid
			and heightIsValid
			and palletIsEmpty
			and overlapIsValid
		setGhostColor(candidateIsValid)
		return
	end

	local candidateBottomY = PlacementGeometry.GetBoundsBottomY(candidateBoundsCFrame, candidateBoundsSize)
	local candidateTopY = PlacementGeometry.GetBoundsTopY(candidateBoundsCFrame, candidateBoundsSize)
	local itemId = PlacementRules.GetItemId(currentItem)
	local stackBottomY = if stackSupport ~= nil and itemId ~= nil
		then PlacementRules.FindStackBottomY(stackSupport, itemId, ignoredInstances)
		else candidateBottomY
	local slotProbePosition = Vector3.new(
		candidateBoundsCFrame.Position.X,
		stackBottomY + CarryConfig.SlotProbeInset,
		candidateBoundsCFrame.Position.Z
	)
	local slot = PlacementRules.FindContainingSlot(getSlotParts(), slotProbePosition)
	local slotMaxHeight = if slot ~= nil then PlacementRules.GetSlotMaxHeight(slot) else nil
	local effectiveMaxHeight = slotMaxHeight or CarryConfig.DefaultFreeStackMaxHeight
	local stackHeight = candidateTopY - stackBottomY
	local heightIsValid = stackHeight <= effectiveMaxHeight + CarryConfig.StackHeightTolerance

	candidateIsValid = surfaceIsValid and distanceIsValid and overlapIsValid and heightIsValid
	setGhostColor(candidateIsValid)
end

function PlacementController.Rotate()
	if ghost == nil then
		return
	end

	rotationStep = (rotationStep + 1) % CarryConfig.RotationStepCount
	updateCandidate()
end

function PlacementController.TryPlace()
	if not candidateIsValid or candidateCFrame == nil or carryRemote == nil then
		return
	end

	local now = os.clock()
	if now - lastPlaceRequestTime < CarryConfig.RequestCooldown then
		return
	end
	lastPlaceRequestTime = now

	carryRemote:FireServer("Place", candidateCFrame, rotationStep, candidatePallet)
end

function PlacementController.Start()
	if started then
		return
	end
	started = true

	local remotes = WarehouseShared:WaitForChild(CarryConfig.RemotesFolderName)
	local remote = remotes:WaitForChild(CarryConfig.RemoteEventName)
	if not remote:IsA("RemoteEvent") then
		error(string.format("[PlacementController] %s must be a RemoteEvent", remote:GetFullName()))
	end
	carryRemote = remote

	remote.OnClientEvent:Connect(function(eventName: unknown, itemValue: unknown)
		if eventName ~= "HeldChanged" then
			return
		end

		if typeof(itemValue) == "Instance" and itemValue:IsA("Model") then
			setHeldItem(itemValue)
		else
			setHeldItem(nil)
		end
	end)

	RunService.RenderStepped:Connect(updateCandidate)
end

return PlacementController
