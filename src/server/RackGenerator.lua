--!strict

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local SECTION_LENGTH = 20
local GENERATED_FOLDER_NAME = "GeneratedRacks"
local ENDPOINT_TIE_EPSILON = 1e-6
local PLACEMENT_TOLERANCE = 0.01
local TEMPLATE_ORIENTATION_OFFSET = CFrame.Angles(0, math.rad(90), 0)

local RackGenerator = {}

type RackPlan = {
	zone: BasePart,
	rackId: number,
	template: Model,
	sectionCount: number,
	startsAtNegativeEnd: boolean,
}

local function warnForZone(zone: Instance, message: string)
	warn(string.format("[RackGenerator] RackZone %s: %s", zone:GetFullName(), message))
end

local function isFiniteNumber(value: unknown): boolean
	return typeof(value) == "number" and value == value and math.abs(value) < math.huge
end

local function countRackIds(zoneChildren: { Instance }): { [number]: number }
	local counts: { [number]: number } = {}

	for _, child in zoneChildren do
		if child:IsA("BasePart") then
			local rackIdAttribute = child:GetAttribute("RackId")
			if isFiniteNumber(rackIdAttribute) then
				local rackId = rackIdAttribute :: number
				counts[rackId] = (counts[rackId] or 0) + 1
			end
		end
	end

	return counts
end

local function resolveTemplate(rackTemplates: Instance, zone: BasePart, rackType: string, rackSide: string): Model?
	local templateName = "Rack" .. rackType .. rackSide
	local template = rackTemplates:FindFirstChild(templateName)

	if template == nil then
		warnForZone(zone, string.format("missing template %s.%s", rackTemplates:GetFullName(), templateName))
		return nil
	end
	if not template:IsA("Model") then
		warnForZone(zone, string.format("template %s must be a Model", template:GetFullName()))
		return nil
	end

	return template
end


local function buildRackPlan(
	zone: BasePart,
	rackTemplates: Instance,
	rackIdCounts: { [number]: number }
): RackPlan?
	local rackIdAttribute = zone:GetAttribute("RackId")
	if not isFiniteNumber(rackIdAttribute) then
		warnForZone(zone, "RackId must be a finite Number")
		return nil
	end
	local rackId = rackIdAttribute :: number

	if rackIdCounts[rackId] ~= 1 then
		warnForZone(zone, string.format("RackId %s is duplicated", tostring(rackId)))
		return nil
	end

	local rackTypeAttribute = zone:GetAttribute("RackType")
	if rackTypeAttribute ~= "V1" and rackTypeAttribute ~= "V2" then
		warnForZone(zone, "RackType must be the String V1 or V2")
		return nil
	end
	local rackType = rackTypeAttribute :: string
	local rackSideAttribute = zone:GetAttribute("RackSide")
	if rackSideAttribute ~= "L" and rackSideAttribute ~= "R" then
		warnForZone(zone, "RackSide must be the String L or R")
		return nil
	end
	local rackSide = rackSideAttribute :: string

	local storageCategory = zone:GetAttribute("StorageCategory")
	if typeof(storageCategory) ~= "string" or storageCategory == "" then
		warnForZone(zone, "StorageCategory must be a non-empty String")
		return nil
	end

	local zoneLength = zone.Size.X
	if zoneLength <= 0 then
		warnForZone(zone, "Size.X must be greater than zero")
		return nil
	end

	local sectionCount = math.floor(zoneLength / SECTION_LENGTH)
	if sectionCount < 1 then
		warnForZone(zone, string.format("Size.X %.3f is shorter than one section", zoneLength))
		return nil
	end

	local template = resolveTemplate(rackTemplates, zone, rackType, rackSide)
	if template == nil then
		return nil
	end

	local halfLength = zoneLength / 2
	local negativeEndpoint = zone.CFrame:PointToWorldSpace(Vector3.new(-halfLength, 0, 0))
	local positiveEndpoint = zone.CFrame:PointToWorldSpace(Vector3.new(halfLength, 0, 0))
	local startsAtNegativeEnd = negativeEndpoint.Magnitude <= positiveEndpoint.Magnitude + ENDPOINT_TIE_EPSILON

	return {
		zone = zone,
		rackId = rackId,
		template = template,
		sectionCount = sectionCount,
		startsAtNegativeEnd = startsAtNegativeEnd,
	}
end

local function getGeneratedFolder(warehouse: Instance): Folder?
	local existing = warehouse:FindFirstChild(GENERATED_FOLDER_NAME)
	if existing ~= nil then
		if not existing:IsA("Folder") then
			warn(string.format("[RackGenerator] %s must be a Folder", existing:GetFullName()))
			return nil
		end

		existing:ClearAllChildren()
		return existing
	end

	local generatedFolder = Instance.new("Folder")
	generatedFolder.Name = GENERATED_FOLDER_NAME
	generatedFolder.Parent = warehouse
	return generatedFolder
end

local function getBayLocalX(plan: RackPlan, bayIndex: number): number
	local distanceFromStart = SECTION_LENGTH / 2 + (bayIndex - 1) * SECTION_LENGTH
	local halfLength = plan.zone.Size.X / 2

	if plan.startsAtNegativeEnd then
		return -halfLength + distanceFromStart
	end

	return halfLength - distanceFromStart
end

local function validateBayPlacement(plan: RackPlan, bayPivots: { Vector3 })
	local rackAxis = plan.zone.CFrame.RightVector

	for bayIndex = 2, #bayPivots do
		local delta = bayPivots[bayIndex] - bayPivots[bayIndex - 1]
		local spacing = delta.Magnitude
		local alongAxis = delta:Dot(rackAxis)
		local perpendicularDrift = (delta - rackAxis * alongAxis).Magnitude

		if math.abs(spacing - SECTION_LENGTH) > PLACEMENT_TOLERANCE
			or perpendicularDrift > PLACEMENT_TOLERANCE
		then
			warnForZone(plan.zone, string.format(
				"Bay_%03d to Bay_%03d: spacing %.6f, perpendicular drift %.6f",
				bayIndex - 1,
				bayIndex,
				spacing,
				perpendicularDrift
			))
		end
	end
end

local function generateRack(plan: RackPlan, generatedFolder: Folder)
	local rackFolder = Instance.new("Folder")
	rackFolder.Name = "Rack_" .. tostring(plan.rackId)
	rackFolder.Parent = generatedFolder

	local bayPivots: { Vector3 } = {}
	local zone = plan.zone

	for bayIndex = 1, plan.sectionCount do
		local localX = getBayLocalX(plan, bayIndex)
		local bayCFrame = zone.CFrame
			* CFrame.new(localX, zone.Size.Y / 2, 0)
			* TEMPLATE_ORIENTATION_OFFSET

		local bay = plan.template:Clone()
		bay.Name = string.format("Bay_%03d", bayIndex)

		bay:PivotTo(bayCFrame)
		bay.Parent = rackFolder
		table.insert(bayPivots, bay:GetPivot().Position)
	end

	validateBayPlacement(plan, bayPivots)
end

function RackGenerator.Generate()
	local warehouse = Workspace:FindFirstChild("Warehouse")
	if warehouse == nil then
		warn("[RackGenerator] Missing Workspace.Warehouse")
		return
	end

	local rackZones = warehouse:FindFirstChild("RackZones")
	if rackZones == nil then
		warn("[RackGenerator] Missing Workspace.Warehouse.RackZones")
		return
	end

	local rackTemplates = ServerStorage:FindFirstChild("RackTemplates")
	if rackTemplates == nil then
		warn("[RackGenerator] Missing ServerStorage.RackTemplates")
		return
	end

	local zoneChildren = rackZones:GetChildren()
	table.sort(zoneChildren, function(left, right)
		return left.Name < right.Name
	end)

	local rackIdCounts = countRackIds(zoneChildren)
	local plans: { RackPlan } = {}

	for _, child in zoneChildren do
		if not child:IsA("BasePart") then
			warn(string.format("[RackGenerator] Ignoring non-BasePart %s", child:GetFullName()))
			continue
		end

		local plan = buildRackPlan(child, rackTemplates, rackIdCounts)
		if plan ~= nil then
			table.insert(plans, plan)
		end
	end

	table.sort(plans, function(left, right)
		return left.rackId < right.rackId
	end)

	local generatedFolder = getGeneratedFolder(warehouse)
	if generatedFolder == nil then
		return
	end

	local generatedSectionCount = 0
	local generatedRackCount = 0

	for _, plan in plans do
		local succeeded, errorMessage = pcall(generateRack, plan, generatedFolder)
		if succeeded then
			generatedSectionCount += plan.sectionCount
			generatedRackCount += 1
		else
			local partialRack = generatedFolder:FindFirstChild("Rack_" .. tostring(plan.rackId))
			if partialRack ~= nil then
				partialRack:Destroy()
			end
			warnForZone(plan.zone, string.format("generation failed: %s", tostring(errorMessage)))
		end
	end

	print(string.format(
		"[RackGenerator] Generated %d Bay sections across %d RackZones",
		generatedSectionCount,
		generatedRackCount
	))
end

return RackGenerator
