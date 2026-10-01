--!strict

local SlotRegistry = require(script.Parent.SlotRegistry)

local SURFACE_GUI_NAME = "SlotSurfaceGui"
local TEXT_LABEL_NAME = "SlotText"
local PIXELS_PER_STUD = 100
local UPWARD_NORMAL_THRESHOLD = 0.99

local RackLabelService = {}

type SlotEntry = {
	SlotId: string,
	Instance: BasePart,
	BayIndex: number,
	FloorIndex: number,
	SlotIndex: number,
	RackSide: string,
}

local function warnForInstance(instance: Instance, message: string)
	warn(string.format("[RackLabelService] %s: %s", instance:GetFullName(), message))
end

local function findMatchingStickers(floor: Instance, slotIndex: number): { Instance }
	local matches: { Instance } = {}

	for _, child in floor:GetChildren() do
		local stickerIndexText = string.match(child.Name, "^Sticker(%d+)$")
		if stickerIndexText ~= nil and tonumber(stickerIndexText) == slotIndex then
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

local function getOrCreateSurfaceGui(sticker: BasePart): SurfaceGui?
	local existing, isUnique = findNamedDescendant(sticker, SURFACE_GUI_NAME)
	if not isUnique then
		return nil
	end

	if existing ~= nil then
		if not existing:IsA("SurfaceGui") then
			warnForInstance(existing, string.format("%s must be a SurfaceGui", SURFACE_GUI_NAME))
			return nil
		end
		if existing.Parent ~= sticker then
			warnForInstance(existing, string.format("%s must be a direct child of the Sticker", SURFACE_GUI_NAME))
			return nil
		end

		return existing
	end

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = SURFACE_GUI_NAME
	surfaceGui.Parent = sticker
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

local function resolveFace(sticker: BasePart, rackSide: string): Enum.NormalId?
	local size = sticker.Size
	if size.X >= size.Y or size.X >= size.Z then
		warnForInstance(
			sticker,
			string.format(
				"expected local X to be the unique minimum Size axis, got (%.3f, %.3f, %.3f)",
				size.X,
				size.Y,
				size.Z
			)
		)
		return nil
	end

	if rackSide == "R" then
		return Enum.NormalId.Right
	end
	if rackSide == "L" then
		return Enum.NormalId.Right
	end

	warnForInstance(sticker, string.format("unsupported RackSide %s", tostring(rackSide)))
	return nil
end

local function getFaceNormal(sticker: BasePart, face: Enum.NormalId): Vector3
	if face == Enum.NormalId.Right then
		return sticker.CFrame.RightVector
	end
	if face == Enum.NormalId.Left then
		return -sticker.CFrame.RightVector
	end
	if face == Enum.NormalId.Top then
		return sticker.CFrame.UpVector
	end
	if face == Enum.NormalId.Bottom then
		return -sticker.CFrame.UpVector
	end
	if face == Enum.NormalId.Front then
		return sticker.CFrame.LookVector
	end

	return -sticker.CFrame.LookVector
end

local function isFloorLabel(sticker: BasePart, face: Enum.NormalId): boolean
	local faceNormal = getFaceNormal(sticker, face)
	return faceNormal:Dot(Vector3.yAxis) >= UPWARD_NORMAL_THRESHOLD
end

local function resolveFloorAndBay(entry: SlotEntry): (Instance?, Model?)
	local slot = entry.Instance
	local floor = slot.Parent
	if floor == nil then
		warnForInstance(slot, "cannot determine parent Floor")
		return nil, nil
	end

	local floorIndexText = string.match(floor.Name, "^Floor(%d+)$")
	if floorIndexText == nil or tonumber(floorIndexText) ~= entry.FloorIndex then
		warnForInstance(
			slot,
			string.format("cannot determine matching parent Floor%d from %s", entry.FloorIndex, floor:GetFullName())
		)
		return nil, nil
	end

	local bay = floor.Parent
	if bay == nil or not bay:IsA("Model") then
		warnForInstance(floor, "cannot determine parent Bay Model")
		return nil, nil
	end

	local bayIndexText = string.match(bay.Name, "^Bay_(%d+)$")
	if bayIndexText == nil or tonumber(bayIndexText) ~= entry.BayIndex then
		warnForInstance(
			floor,
			string.format("cannot determine matching parent Bay_%03d from %s", entry.BayIndex, bay:GetFullName())
		)
		return nil, nil
	end

	return floor, bay
end

local function applyEntry(entry: SlotEntry): boolean
	if typeof(entry.SlotId) ~= "string" or entry.SlotId == "" then
		warnForInstance(entry.Instance, "missing SlotId")
		return false
	end

	local floor, bay = resolveFloorAndBay(entry)
	if floor == nil or bay == nil then
		return false
	end

	local stickers = findMatchingStickers(floor, entry.SlotIndex)
	if #stickers == 0 then
		warnForInstance(floor, string.format("missing Sticker%d for %s", entry.SlotIndex, entry.SlotId))
		return false
	end
	if #stickers > 1 then
		local paths: { string } = {}
		for _, sticker in stickers do
			table.insert(paths, sticker:GetFullName())
		end
		warnForInstance(
			floor,
			string.format("duplicate Sticker%d for %s: %s", entry.SlotIndex, entry.SlotId, table.concat(paths, ", "))
		)
		return false
	end

	local sticker = stickers[1]
	if not sticker:IsA("BasePart") then
		warnForInstance(sticker, string.format("Sticker%d must be a BasePart", entry.SlotIndex))
		return false
	end

	sticker:SetAttribute("SlotId", entry.SlotId)

	local face = resolveFace(sticker, entry.RackSide)
	if face == nil then
		return false
	end

	local surfaceGui = getOrCreateSurfaceGui(sticker)
	if surfaceGui == nil then
		return false
	end

	local textLabel = getOrCreateTextLabel(surfaceGui)
	if textLabel == nil then
		return false
	end

	surfaceGui.Adornee = sticker
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = PIXELS_PER_STUD
	surfaceGui.AlwaysOnTop = false
	surfaceGui.Face = face

	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.Position = UDim2.fromScale(0, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
	textLabel.Rotation = if isFloorLabel(sticker, face) then 180 else 0
	textLabel.Text = entry.SlotId

	return true
end

function RackLabelService.ApplyAll()
	local appliedCount = 0

	for _, entry in SlotRegistry.GetAll() do
		if applyEntry(entry :: SlotEntry) then
			appliedCount += 1
		end
	end

	print(string.format("[RackLabelService] Applied %d slot labels", appliedCount))
end

return RackLabelService
