--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WarehouseShared = ReplicatedStorage:WaitForChild("WarehouseShared")
local CarryConfig = require(WarehouseShared:WaitForChild("CarryConfig"))
local CarryItem = require(WarehouseShared:WaitForChild("CarryItem"))
local PlacementGeometry = require(WarehouseShared:WaitForChild("PlacementGeometry"))

local PalletPlacementRules = {}

export type PalletInfo = {
	model: Model,
	loadArea: BasePart,
	maxHeight: number,
}

export type FirstLayerCandidate = {
	xIndex: number,
	zIndex: number,
	localX: number,
	localZ: number,
}

export type FirstLayerCandidateSet = {
	countX: number,
	countZ: number,
	footprintX: number,
	footprintZ: number,
	candidates: { FirstLayerCandidate },
}

local function isPositiveFiniteNumber(value: unknown): boolean
	return typeof(value) == "number"
		and value == value
		and math.abs(value) < math.huge
		and value > 0
end

function PalletPlacementRules.GetPalletInfo(model: Model): PalletInfo?
	if model.Parent == nil or not model:IsDescendantOf(Workspace) then
		return nil
	end
	if model:GetAttribute("PackingEnabled") ~= true then
		return nil
	end

	local loadArea = model:FindFirstChild("LoadArea")
	if loadArea == nil or not loadArea:IsA("BasePart") then
		return nil
	end

	local maxHeight = model:GetAttribute("MaxHeight")
	if not isPositiveFiniteNumber(maxHeight) then
		return nil
	end

	return {
		model = model,
		loadArea = loadArea,
		maxHeight = maxHeight :: number,
	}
end

function PalletPlacementRules.FindPalletInfo(instance: Instance?): PalletInfo?
	if instance == nil or not instance:IsA("BasePart") then
		return nil
	end

	local current: Instance? = instance
	while current ~= nil do
		if current:IsA("Model") and current:GetAttribute("PackingEnabled") == true then
			return PalletPlacementRules.GetPalletInfo(current)
		end
		current = current.Parent
	end

	return nil
end

function PalletPlacementRules.GetAssociatedPalletInfo(item: Model): PalletInfo?
	if item.Parent == nil or not item:IsDescendantOf(Workspace) then
		return nil
	end
	if item:GetAttribute("Carryable") ~= true then
		return nil
	end
	if item:GetAttribute("PackedOnPallet") ~= true then
		return nil
	end

	local association = item:FindFirstChild(CarryConfig.PackedPalletObjectName)
	if association == nil or not association:IsA("ObjectValue") then
		return nil
	end

	local pallet = association.Value
	if pallet == nil or not pallet:IsA("Model") then
		return nil
	end

	return PalletPlacementRules.GetPalletInfo(pallet)
end

function PalletPlacementRules.FindPalletBelowPosition(
	worldPosition: Vector3,
	ignoredInstances: { Instance }
): PalletInfo?
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = ignoredInstances
	raycastParams.IgnoreWater = true

	local probeOffset = CarryConfig.PalletFootprintTolerance
	local result = Workspace:Raycast(
		worldPosition + Vector3.new(0, probeOffset, 0),
		Vector3.new(0, -CarryConfig.PalletCargoProbeDistance, 0),
		raycastParams
	)
	if result == nil then
		return nil
	end

	return PalletPlacementRules.FindPalletInfo(result.Instance)
end

function PalletPlacementRules.GetCandidateOrientation(loadArea: BasePart, rotationStep: number): CFrame
	return loadArea.CFrame.Rotation * PlacementGeometry.GetYawRotation(rotationStep)
end

function PalletPlacementRules.CreateCandidateCFrame(
	loadArea: BasePart,
	rotationStep: number,
	boundsInfo: PlacementGeometry.BoundsInfo,
	localX: number,
	localZ: number
): CFrame
	local orientation = PalletPlacementRules.GetCandidateOrientation(loadArea, rotationStep)
	local boundsAtOrigin = orientation * boundsInfo.pivotToBounds
	local bottomAtOrigin = PlacementGeometry.GetBoundsBottomY(boundsAtOrigin, boundsInfo.size)
	local boundsOffset = boundsAtOrigin.Position
	local planePosition = loadArea.CFrame:PointToWorldSpace(Vector3.new(localX, 0, localZ))
	local pivotPosition = Vector3.new(
		planePosition.X - boundsOffset.X,
		planePosition.Y - bottomAtOrigin,
		planePosition.Z - boundsOffset.Z
	)

	return CFrame.new(pivotPosition) * orientation
end

function PalletPlacementRules.CreateVerticalCandidateCFrame(
	palletInfo: PalletInfo,
	support: Model,
	rotationStep: number,
	boundsInfo: PlacementGeometry.BoundsInfo
): CFrame
	local supportBoundsCFrame, supportBoundsSize = support:GetBoundingBox()
	local supportTopY = PlacementGeometry.GetBoundsTopY(supportBoundsCFrame, supportBoundsSize)
	local orientation = PalletPlacementRules.GetCandidateOrientation(palletInfo.loadArea, rotationStep)
	local boundsAtOrigin = orientation * boundsInfo.pivotToBounds
	local bottomAtOrigin = PlacementGeometry.GetBoundsBottomY(boundsAtOrigin, boundsInfo.size)
	local boundsOffset = boundsAtOrigin.Position
	local pivotPosition = Vector3.new(
		supportBoundsCFrame.Position.X - boundsOffset.X,
		supportTopY - bottomAtOrigin,
		supportBoundsCFrame.Position.Z - boundsOffset.Z
	)

	return CFrame.new(pivotPosition) * orientation
end

local function getFootprintExtents(
	loadArea: BasePart,
	boundsCFrame: CFrame,
	boundsSize: Vector3
): (number, number, number, number)
	local halfBounds = boundsSize / 2
	local minimumX = math.huge
	local maximumX = -math.huge
	local minimumZ = math.huge
	local maximumZ = -math.huge

	for xSign = -1, 1, 2 do
		for ySign = -1, 1, 2 do
			for zSign = -1, 1, 2 do
				local corner = Vector3.new(
					halfBounds.X * xSign,
					halfBounds.Y * ySign,
					halfBounds.Z * zSign
				)
				local worldCorner = boundsCFrame:PointToWorldSpace(corner)
				local localCorner = loadArea.CFrame:PointToObjectSpace(worldCorner)
				minimumX = math.min(minimumX, localCorner.X)
				maximumX = math.max(maximumX, localCorner.X)
				minimumZ = math.min(minimumZ, localCorner.Z)
				maximumZ = math.max(maximumZ, localCorner.Z)
			end
		end
	end

	return minimumX, maximumX, minimumZ, maximumZ
end

function PalletPlacementRules.DoesFootprintFit(
	loadArea: BasePart,
	boundsCFrame: CFrame,
	boundsSize: Vector3
): boolean
	local minimumX, maximumX, minimumZ, maximumZ = getFootprintExtents(
		loadArea,
		boundsCFrame,
		boundsSize
	)

	local halfArea = loadArea.Size / 2
	local tolerance = CarryConfig.PalletFootprintTolerance
	return minimumX >= -halfArea.X - tolerance
		and maximumX <= halfArea.X + tolerance
		and minimumZ >= -halfArea.Z - tolerance
		and maximumZ <= halfArea.Z + tolerance
end

function PalletPlacementRules.DoesFootprintFitSupport(
	supportBoundsCFrame: CFrame,
	supportBoundsSize: Vector3,
	candidateBoundsCFrame: CFrame,
	candidateBoundsSize: Vector3
): boolean
	local halfSupport = supportBoundsSize / 2
	local halfCandidate = candidateBoundsSize / 2
	local tolerance = CarryConfig.PalletFootprintTolerance

	for xSign = -1, 1, 2 do
		for ySign = -1, 1, 2 do
			for zSign = -1, 1, 2 do
				local candidateCorner = Vector3.new(
					halfCandidate.X * xSign,
					halfCandidate.Y * ySign,
					halfCandidate.Z * zSign
				)
				local worldCorner = candidateBoundsCFrame:PointToWorldSpace(candidateCorner)
				local supportLocalCorner = supportBoundsCFrame:PointToObjectSpace(worldCorner)
				if
					math.abs(supportLocalCorner.X) > halfSupport.X + tolerance
					or math.abs(supportLocalCorner.Z) > halfSupport.Z + tolerance
				then
					return false
				end
			end
		end
	end

	return true
end

local function addCandidateCoordinate(coordinates: { number }, value: number, minimum: number, maximum: number)
	local epsilon = CarryConfig.PalletCandidateCoordinateEpsilon
	if minimum > maximum then
		return
	end
	if value < minimum - epsilon or value > maximum + epsilon then
		return
	end

	local clampedValue = math.clamp(value, minimum, maximum)
	for _, existingValue in coordinates do
		if math.abs(existingValue - clampedValue) <= epsilon then
			return
		end
	end

	table.insert(coordinates, clampedValue)
end

local function getFirstLayerCargo(palletInfo: PalletInfo): { Model }
	local loadArea = palletInfo.loadArea
	local tolerance = CarryConfig.StackContactTolerance
	local queryHeight = palletInfo.maxHeight + tolerance * 2
	local queryCFrame = loadArea.CFrame * CFrame.new(0, queryHeight / 2 - tolerance, 0)
	local querySize = Vector3.new(
		loadArea.Size.X + tolerance * 2,
		queryHeight,
		loadArea.Size.Z + tolerance * 2
	)
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { palletInfo.model }
	overlapParams.MaxParts = 0

	local cargoModels: { Model } = {}
	local seenCargo: { [Model]: boolean } = {}
	for _, part in Workspace:GetPartBoundsInBox(queryCFrame, querySize, overlapParams) do
		local cargo = CarryItem.FindCarryableModel(part)
		if cargo == nil or seenCargo[cargo] == true then
			continue
		end
		seenCargo[cargo] = true

		local associatedPalletInfo = PalletPlacementRules.GetAssociatedPalletInfo(cargo)
		if associatedPalletInfo == nil or associatedPalletInfo.model ~= palletInfo.model then
			continue
		end

		local boundsCFrame, boundsSize = cargo:GetBoundingBox()
		local cargoBottomY = PlacementGeometry.GetBoundsBottomY(boundsCFrame, boundsSize)
		if math.abs(cargoBottomY - loadArea.Position.Y) <= tolerance then
			table.insert(cargoModels, cargo)
		end
	end

	return cargoModels
end

function PalletPlacementRules.BuildFirstLayerCandidates(
	palletInfo: PalletInfo,
	rotationStep: number,
	boundsInfo: PlacementGeometry.BoundsInfo
): FirstLayerCandidateSet
	local loadArea = palletInfo.loadArea
	local centeredCFrame = PalletPlacementRules.CreateCandidateCFrame(
		loadArea,
		rotationStep,
		boundsInfo,
		0,
		0
	)
	local centeredBoundsCFrame, centeredBoundsSize = PlacementGeometry.GetWorldBounds(centeredCFrame, boundsInfo)
	local minimumX, maximumX, minimumZ, maximumZ = getFootprintExtents(
		loadArea,
		centeredBoundsCFrame,
		centeredBoundsSize
	)
	local footprintX = maximumX - minimumX
	local footprintZ = maximumZ - minimumZ
	local halfFootprintX = footprintX / 2
	local halfFootprintZ = footprintZ / 2
	local halfArea = loadArea.Size / 2
	local minimumCenterX = -halfArea.X + halfFootprintX
	local maximumCenterX = halfArea.X - halfFootprintX
	local minimumCenterZ = -halfArea.Z + halfFootprintZ
	local maximumCenterZ = halfArea.Z - halfFootprintZ
	local candidateXs: { number } = {}
	local candidateZs: { number } = {}

	if minimumCenterX <= maximumCenterX then
		addCandidateCoordinate(candidateXs, minimumCenterX, minimumCenterX, maximumCenterX)
		addCandidateCoordinate(candidateXs, 0, minimumCenterX, maximumCenterX)
		addCandidateCoordinate(candidateXs, maximumCenterX, minimumCenterX, maximumCenterX)
	end
	if minimumCenterZ <= maximumCenterZ then
		addCandidateCoordinate(candidateZs, minimumCenterZ, minimumCenterZ, maximumCenterZ)
		addCandidateCoordinate(candidateZs, 0, minimumCenterZ, maximumCenterZ)
		addCandidateCoordinate(candidateZs, maximumCenterZ, minimumCenterZ, maximumCenterZ)
	end

	local gap = CarryConfig.PalletPackingGap
	for _, cargo in getFirstLayerCargo(palletInfo) do
		local cargoBoundsCFrame, cargoBoundsSize = cargo:GetBoundingBox()
		local cargoMinimumX, cargoMaximumX, cargoMinimumZ, cargoMaximumZ = getFootprintExtents(
			loadArea,
			cargoBoundsCFrame,
			cargoBoundsSize
		)
		addCandidateCoordinate(
			candidateXs,
			cargoMinimumX - gap - halfFootprintX,
			minimumCenterX,
			maximumCenterX
		)
		addCandidateCoordinate(
			candidateXs,
			cargoMaximumX + gap + halfFootprintX,
			minimumCenterX,
			maximumCenterX
		)
		addCandidateCoordinate(
			candidateZs,
			cargoMinimumZ - gap - halfFootprintZ,
			minimumCenterZ,
			maximumCenterZ
		)
		addCandidateCoordinate(
			candidateZs,
			cargoMaximumZ + gap + halfFootprintZ,
			minimumCenterZ,
			maximumCenterZ
		)
	end
	table.sort(candidateXs)
	table.sort(candidateZs)

	local candidates: { FirstLayerCandidate } = {}
	for zIndex, localZ in candidateZs do
		for xIndex, localX in candidateXs do
			local candidateCFrame = PalletPlacementRules.CreateCandidateCFrame(
				loadArea,
				rotationStep,
				boundsInfo,
				localX,
				localZ
			)
			local candidateBoundsCFrame, candidateBoundsSize = PlacementGeometry.GetWorldBounds(
				candidateCFrame,
				boundsInfo
			)
			if PalletPlacementRules.DoesFootprintFit(loadArea, candidateBoundsCFrame, candidateBoundsSize) then
				table.insert(candidates, {
					xIndex = xIndex,
					zIndex = zIndex,
					localX = localX,
					localZ = localZ,
				})
			end
		end
	end

	return {
		countX = #candidateXs,
		countZ = #candidateZs,
		footprintX = footprintX,
		footprintZ = footprintZ,
		candidates = candidates,
	}
end

function PalletPlacementRules.IsCandidateIndex(value: unknown): boolean
	return typeof(value) == "number"
		and value == value
		and math.abs(value) < math.huge
		and value % 1 == 0
		and value >= 1
end

function PalletPlacementRules.GetFirstLayerCandidate(
	candidateSet: FirstLayerCandidateSet,
	xIndex: number,
	zIndex: number
): FirstLayerCandidate?
	if xIndex > candidateSet.countX or zIndex > candidateSet.countZ then
		return nil
	end

	for _, candidate in candidateSet.candidates do
		if candidate.xIndex == xIndex and candidate.zIndex == zIndex then
			return candidate
		end
	end

	return nil
end

function PalletPlacementRules.GetPalletBottomY(pallet: Model): number
	local boundsCFrame, boundsSize = pallet:GetBoundingBox()
	return PlacementGeometry.GetBoundsBottomY(boundsCFrame, boundsSize)
end

function PalletPlacementRules.IsHeightValid(
	palletInfo: PalletInfo,
	candidateBoundsCFrame: CFrame,
	candidateBoundsSize: Vector3
): boolean
	local palletBottomY = PalletPlacementRules.GetPalletBottomY(palletInfo.model)
	local candidateTopY = PlacementGeometry.GetBoundsTopY(candidateBoundsCFrame, candidateBoundsSize)
	local totalLoadedHeight = candidateTopY - palletBottomY

	return totalLoadedHeight <= palletInfo.maxHeight + CarryConfig.StackHeightTolerance
end

function PalletPlacementRules.HasForbiddenOverlap(
	boundsCFrame: CFrame,
	boundsSize: Vector3,
	ignoredInstances: { Instance }
): boolean
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = ignoredInstances
	overlapParams.MaxParts = 0

	local querySize = PlacementGeometry.GetShrunkSize(boundsSize)
	for _, part in Workspace:GetPartBoundsInBox(boundsCFrame, querySize, overlapParams) do
		local cargo = CarryItem.FindCarryableModel(part)
		if cargo ~= nil or part.CanCollide then
			return true
		end
	end

	return false
end

return PalletPlacementRules
