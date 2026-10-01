--!strict

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local GENERATED_FOLDER_NAME = "GeneratedRacks"
local NUMBER_PLATES_FOLDER_NAME = "NumberPlates"
local SURFACE_GUI_NAME = "RackNumberSurfaceGui"
local TEXT_LABEL_NAME = "RackNumberText"
local PLATE_CENTER_HEIGHT = 14.04
local ENDPOINT_INSET = 0.24
local PIXELS_PER_STUD = 100
local OUTWARD_FACE = Enum.NormalId.Right

local RackNumberService = {}

type GeneratedRack = {
	rackId: number,
	instance: Instance,
}

type PlatePlacement = {
	name: string,
	rackEnd: string,
	localX: number,
	yaw: number,
}

local function warnForInstance(instance: Instance, message: string)
	warn(string.format("[RackNumberService] %s: %s", instance:GetFullName(), message))
end

local function isPositiveInteger(value: unknown): boolean
	return typeof(value) == "number" and value == value and math.abs(value) < math.huge and value > 0 and value % 1 == 0
end

local function findDirectChildrenNamed(parent: Instance, name: string): { Instance }
	local matches: { Instance } = {}

	for _, child in parent:GetChildren() do
		if child.Name == name then
			table.insert(matches, child)
		end
	end

	return matches
end

local function findNamedDescendant(root: Instance, name: string): (Instance?, boolean)
	local match: Instance? = nil

	for _, descendant in root:GetDescendants() do
		if descendant.Name == name then
			if match ~= nil then
				warnForInstance(root, string.format("multiple descendants named %s", name))
				return nil, false
			end

			match = descendant
		end
	end

	return match, true
end

local function getNumberPlateTemplate(): BasePart?
	local rackAssets = ServerStorage:FindFirstChild("RackAssets")
	if rackAssets == nil then
		warn("[RackNumberService] Missing ServerStorage.RackAssets")
		return nil
	end

	local template = rackAssets:FindFirstChild("NumberPlate")
	if template == nil then
		warn("[RackNumberService] Missing ServerStorage.RackAssets.NumberPlate")
		return nil
	end
	if not template:IsA("BasePart") then
		warn(string.format("[RackNumberService] %s must be a BasePart", template:GetFullName()))
		return nil
	end

	local size = template.Size
	if size.X >= size.Y or size.X >= size.Z then
		warn(
			string.format(
				"[RackNumberService] %s must have local X as its unique minimum Size axis; got (%.3f, %.3f, %.3f)",
				template:GetFullName(),
				size.X,
				size.Y,
				size.Z
			)
		)
		return nil
	end

	return template
end

local function getOrCreateNumberPlatesFolder(rack: Instance): Folder?
	local matches = findDirectChildrenNamed(rack, NUMBER_PLATES_FOLDER_NAME)
	if #matches > 1 then
		warnForInstance(rack, string.format("multiple direct children named %s", NUMBER_PLATES_FOLDER_NAME))
		return nil
	end

	local existing = matches[1]
	if existing ~= nil then
		if not existing:IsA("Folder") then
			warnForInstance(existing, string.format("%s must be a Folder", NUMBER_PLATES_FOLDER_NAME))
			return nil
		end

		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = NUMBER_PLATES_FOLDER_NAME
	folder.Parent = rack
	return folder
end

local function getOrCreatePlate(folder: Folder, plateName: string, template: BasePart): BasePart?
	local matches = findDirectChildrenNamed(folder, plateName)
	if #matches > 1 then
		warnForInstance(folder, string.format("multiple direct children named %s", plateName))
		return nil
	end

	local existing = matches[1]
	if existing ~= nil then
		if not existing:IsA("BasePart") then
			warnForInstance(existing, string.format("%s must be a BasePart", plateName))
			return nil
		end

		return existing
	end

	local plate = template:Clone() :: BasePart
	plate.Name = plateName
	plate.Parent = folder
	return plate
end

local function getOrCreateSurfaceGui(plate: BasePart): SurfaceGui?
	local existing, isUnique = findNamedDescendant(plate, SURFACE_GUI_NAME)
	if not isUnique then
		return nil
	end

	if existing ~= nil then
		if not existing:IsA("SurfaceGui") then
			warnForInstance(existing, string.format("%s must be a SurfaceGui", SURFACE_GUI_NAME))
			return nil
		end
		if existing.Parent ~= plate then
			warnForInstance(existing, string.format("%s must be a direct child of the NumberPlate", SURFACE_GUI_NAME))
			return nil
		end

		return existing
	end

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = SURFACE_GUI_NAME
	surfaceGui.Parent = plate
	return surfaceGui
end

local function getOrCreateTextLabel(surfaceGui: SurfaceGui): TextLabel?
	local existing, isUnique = findNamedDescendant(surfaceGui, TEXT_LABEL_NAME)
	if not isUnique then
		return nil
	end

	if existing ~= nil then
		if not existing:IsA("TextLabel") then
			warnForInstance(existing, string.format("%s must be a TextLabel", TEXT_LABEL_NAME))
			return nil
		end
		if existing.Parent ~= surfaceGui then
			warnForInstance(
				existing,
				string.format("%s must be a direct child of %s", TEXT_LABEL_NAME, SURFACE_GUI_NAME)
			)
			return nil
		end

		return existing
	end

	local textLabel = Instance.new("TextLabel")
	textLabel.Name = TEXT_LABEL_NAME
	textLabel.Parent = surfaceGui
	return textLabel
end

local function buildRackZonesById(rackZones: Instance): { [number]: { BasePart } }
	local zonesByRackId: { [number]: { BasePart } } = {}

	for _, child in rackZones:GetChildren() do
		if not child:IsA("BasePart") then
			continue
		end

		local rackIdAttribute = child:GetAttribute("RackId")
		if not isPositiveInteger(rackIdAttribute) then
			warnForInstance(child, "RackId must be a positive integer Number")
			continue
		end

		local rackId = rackIdAttribute :: number
		local candidates = zonesByRackId[rackId]
		if candidates == nil then
			candidates = {}
			zonesByRackId[rackId] = candidates
		end
		table.insert(candidates, child)
	end

	return zonesByRackId
end

local function collectGeneratedRacks(generatedRacks: Instance): { GeneratedRack }
	local racks: { GeneratedRack } = {}

	for _, child in generatedRacks:GetChildren() do
		local rackIdText = string.match(child.Name, "^Rack_(%d+)$")
		if rackIdText == nil then
			warnForInstance(child, "invalid generated rack name; expected Rack_<number>")
			continue
		end

		local rackIdFromName = tonumber(rackIdText)
		local rackIdAttribute = child:GetAttribute("RackId")
		if not isPositiveInteger(rackIdAttribute) then
			warnForInstance(child, "RackId must be a positive integer Number")
			continue
		end
		if rackIdFromName ~= rackIdAttribute then
			warnForInstance(
				child,
				string.format("RackId attribute %s does not match generated rack name", tostring(rackIdAttribute))
			)
			continue
		end

		table.insert(racks, {
			rackId = rackIdAttribute :: number,
			instance = child,
		})
	end

	table.sort(racks, function(left, right)
		return left.rackId < right.rackId
	end)

	return racks
end

local function applyPlate(
	folder: Folder,
	template: BasePart,
	zone: BasePart,
	rackId: number,
	placement: PlatePlacement
): boolean
	local plate = getOrCreatePlate(folder, placement.name, template)
	if plate == nil then
		return false
	end

	local localY = zone.Size.Y / 2 + PLATE_CENTER_HEIGHT
	plate.CFrame = zone.CFrame * CFrame.new(placement.localX, localY, 0) * CFrame.Angles(0, placement.yaw, 0)
	plate:SetAttribute("RackId", rackId)
	plate:SetAttribute("RackEnd", placement.rackEnd)

	local surfaceGui = getOrCreateSurfaceGui(plate)
	if surfaceGui == nil then
		return false
	end

	local textLabel = getOrCreateTextLabel(surfaceGui)
	if textLabel == nil then
		return false
	end

	surfaceGui.Adornee = plate
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = PIXELS_PER_STUD
	surfaceGui.AlwaysOnTop = false
	surfaceGui.Face = OUTWARD_FACE

	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.Position = UDim2.fromScale(0, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	textLabel.Rotation = 0
	textLabel.Text = tostring(rackId)

	return true
end

function RackNumberService.ApplyAll()
	local appliedPlateCount = 0
	local appliedRackCount = 0

	local warehouse = Workspace:FindFirstChild("Warehouse")
	if warehouse == nil then
		warn("[RackNumberService] Missing Workspace.Warehouse")
		print("[RackNumberService] Applied 0 rack number plates across 0 racks")
		return
	end

	local generatedRacks = warehouse:FindFirstChild(GENERATED_FOLDER_NAME)
	if generatedRacks == nil then
		warn("[RackNumberService] Missing Workspace.Warehouse.GeneratedRacks")
		print("[RackNumberService] Applied 0 rack number plates across 0 racks")
		return
	end

	local rackZones = warehouse:FindFirstChild("RackZones")
	if rackZones == nil then
		warn("[RackNumberService] Missing Workspace.Warehouse.RackZones")
		print("[RackNumberService] Applied 0 rack number plates across 0 racks")
		return
	end

	local template = getNumberPlateTemplate()
	if template == nil then
		print("[RackNumberService] Applied 0 rack number plates across 0 racks")
		return
	end

	local zonesByRackId = buildRackZonesById(rackZones)
	local generatedRackEntries = collectGeneratedRacks(generatedRacks)

	for _, generatedRack in generatedRackEntries do
		local zoneCandidates = zonesByRackId[generatedRack.rackId]
		if zoneCandidates == nil or #zoneCandidates == 0 then
			warnForInstance(
				generatedRack.instance,
				string.format("RackZone for RackId %d was not found", generatedRack.rackId)
			)
			continue
		end
		if #zoneCandidates > 1 then
			local paths: { string } = {}
			for _, zone in zoneCandidates do
				table.insert(paths, zone:GetFullName())
			end
			warnForInstance(
				generatedRack.instance,
				string.format("multiple RackZones for RackId %d: %s", generatedRack.rackId, table.concat(paths, ", "))
			)
			continue
		end

		local zone = zoneCandidates[1]
		if zone.Size.X <= ENDPOINT_INSET * 2 then
			warnForInstance(zone, "Size.X is too short for rack number plate inset")
			continue
		end

		local numberPlatesFolder = getOrCreateNumberPlatesFolder(generatedRack.instance)
		if numberPlatesFolder == nil then
			continue
		end

		local halfLength = zone.Size.X / 2
		local placements: { PlatePlacement } = {
			{
				name = "Start",
				rackEnd = "Start",
				localX = -halfLength + ENDPOINT_INSET,
				yaw = math.pi,
			},
			{
				name = "End",
				rackEnd = "End",
				localX = halfLength - ENDPOINT_INSET,
				yaw = 0,
			},
		}

		local rackPlateCount = 0
		for _, placement in placements do
			if applyPlate(numberPlatesFolder, template, zone, generatedRack.rackId, placement) then
				rackPlateCount += 1
			end
		end

		appliedPlateCount += rackPlateCount
		if rackPlateCount > 0 then
			appliedRackCount += 1
		end
	end

	print(
		string.format(
			"[RackNumberService] Applied %d rack number plates across %d racks",
			appliedPlateCount,
			appliedRackCount
		)
	)
end

return RackNumberService
