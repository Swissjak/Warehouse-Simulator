--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WarehouseShared = ReplicatedStorage:WaitForChild("WarehouseShared")
local ProductCatalog = require(WarehouseShared:WaitForChild("ProductCatalog"))

local ProductService = {}

local BARCODE_SURFACE_NAME = "BarcodeSurface"
local SURFACE_GUI_NAME = "BarcodeGui"
local BACKGROUND_NAME = "Background"
local BARS_NAME = "Bars"
local BARCODE_TEXT_NAME = "BarcodeText"
local RENDERED_BARCODE_ATTRIBUTE = "RenderedBarcode"
local CANVAS_SIZE = Vector2.new(260, 160)

local warnedKeys: { [string]: boolean } = {}
local started = false

local function warnOnce(key: string, message: string)
	if warnedKeys[key] == true then
		return
	end

	warnedKeys[key] = true
	warn(string.format("[ProductService] %s", message))
end

local function getItemId(item: Model): string?
	local itemId = item:GetAttribute("ItemId")
	if typeof(itemId) == "string" and itemId ~= "" then
		return itemId
	end

	return nil
end

local function findUniqueDirectChild(parent: Instance, name: string): (Instance?, boolean)
	local match: Instance? = nil
	for _, child in parent:GetChildren() do
		if child.Name == name then
			if match ~= nil then
				warnOnce(
					string.format("duplicate:%s:%s", parent:GetFullName(), name),
					string.format("%s has multiple direct children named %s", parent:GetFullName(), name)
				)
				return nil, false
			end
			match = child
		end
	end

	return match, true
end

local function getOrCreateSurfaceGui(surface: BasePart): SurfaceGui?
	local existing, isUnique = findUniqueDirectChild(surface, SURFACE_GUI_NAME)
	if not isUnique then
		return nil
	end
	if existing ~= nil then
		if not existing:IsA("SurfaceGui") then
			warnOnce(
				"class:" .. existing:GetFullName(),
				string.format("%s must be a SurfaceGui", existing:GetFullName())
			)
			return nil
		end
		return existing
	end

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = SURFACE_GUI_NAME
	surfaceGui.Parent = surface
	return surfaceGui
end

local function getOrCreateFrame(parent: Instance, name: string): Frame?
	local existing, isUnique = findUniqueDirectChild(parent, name)
	if not isUnique then
		return nil
	end
	if existing ~= nil then
		if not existing:IsA("Frame") then
			warnOnce("class:" .. existing:GetFullName(), string.format("%s must be a Frame", existing:GetFullName()))
			return nil
		end
		return existing
	end

	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Parent = parent
	return frame
end

local function getOrCreateTextLabel(parent: Instance, name: string): TextLabel?
	local existing, isUnique = findUniqueDirectChild(parent, name)
	if not isUnique then
		return nil
	end
	if existing ~= nil then
		if not existing:IsA("TextLabel") then
			warnOnce(
				"class:" .. existing:GetFullName(),
				string.format("%s must be a TextLabel", existing:GetFullName())
			)
			return nil
		end
		return existing
	end

	local textLabel = Instance.new("TextLabel")
	textLabel.Name = name
	textLabel.Parent = parent
	return textLabel
end

local function appendModule(modules: { boolean }, isBar: boolean)
	table.insert(modules, isBar)
end

local function buildVisualPattern(barcode: string): { boolean }
	local modules: { boolean } = {}
	for _, isBar in { false, false, true, false, true, false } do
		appendModule(modules, isBar)
	end

	for characterIndex = 1, #barcode do
		local characterByte = string.byte(barcode, characterIndex)
		appendModule(modules, false)
		for bitIndex = 7, 0, -1 do
			local divisor = 2 ^ bitIndex
			appendModule(modules, math.floor(characterByte / divisor) % 2 == 1)
		end
		appendModule(modules, false)
	end

	for _, isBar in { true, false, true, true, false, true, false, false } do
		appendModule(modules, isBar)
	end

	return modules
end

local function rebuildBars(bars: Frame, barcode: string)
	for _, child in bars:GetChildren() do
		child:Destroy()
	end

	local modules = buildVisualPattern(barcode)
	local moduleCount = #modules
	local moduleIndex = 1
	local barIndex = 0
	while moduleIndex <= moduleCount do
		if not modules[moduleIndex] then
			moduleIndex += 1
			continue
		end

		local startIndex = moduleIndex
		while moduleIndex <= moduleCount and modules[moduleIndex] do
			moduleIndex += 1
		end

		barIndex += 1
		local bar = Instance.new("Frame")
		bar.Name = string.format("Bar_%03d", barIndex)
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		bar.Position = UDim2.fromScale((startIndex - 1) / moduleCount, 0)
		bar.Size = UDim2.fromScale((moduleIndex - startIndex) / moduleCount, 1)
		bar.ZIndex = 3
		bar.Parent = bars
	end
end

local function clearRuntimePresentation(item: Model)
	item:SetAttribute("Barcode", nil)
	item:SetAttribute("DisplayName", nil)

	local surface = item:FindFirstChild(BARCODE_SURFACE_NAME)
	if surface == nil or not surface:IsA("BasePart") then
		return
	end

	for _, child in surface:GetChildren() do
		if child.Name == SURFACE_GUI_NAME then
			child:Destroy()
		end
	end
end

local function applyLabel(surface: BasePart, product: ProductCatalog.ProductInfo): boolean
	local surfaceGui = getOrCreateSurfaceGui(surface)
	if surfaceGui == nil then
		return false
	end
	local background = getOrCreateFrame(surfaceGui, BACKGROUND_NAME)
	if background == nil then
		return false
	end
	local bars = getOrCreateFrame(background, BARS_NAME)
	if bars == nil then
		return false
	end
	local barcodeText = getOrCreateTextLabel(background, BARCODE_TEXT_NAME)
	if barcodeText == nil then
		return false
	end

	surfaceGui.Adornee = surface
	surfaceGui.Face = Enum.NormalId.Back
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	surfaceGui.CanvasSize = CANVAS_SIZE
	surfaceGui.AlwaysOnTop = false
	surfaceGui.LightInfluence = 0

	background.Size = UDim2.fromScale(1, 1)
	background.Position = UDim2.fromScale(0, 0)
	background.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	background.BackgroundTransparency = 0
	background.BorderColor3 = Color3.fromRGB(0, 0, 0)
	background.BorderSizePixel = 2
	background.ZIndex = 1

	bars.Size = UDim2.fromScale(0.88, 0.56)
	bars.Position = UDim2.fromScale(0.06, 0.08)
	bars.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	bars.BackgroundTransparency = 0
	bars.BorderSizePixel = 0
	bars.ClipsDescendants = true
	bars.ZIndex = 2

	barcodeText.Size = UDim2.fromScale(0.9, 0.24)
	barcodeText.Position = UDim2.fromScale(0.05, 0.7)
	barcodeText.BackgroundTransparency = 1
	barcodeText.BorderSizePixel = 0
	barcodeText.Font = Enum.Font.GothamBold
	barcodeText.TextColor3 = Color3.fromRGB(0, 0, 0)
	barcodeText.TextScaled = true
	barcodeText.Text = product.Barcode
	barcodeText.ZIndex = 2

	if surfaceGui:GetAttribute(RENDERED_BARCODE_ATTRIBUTE) ~= product.Barcode or #bars:GetChildren() == 0 then
		rebuildBars(bars, product.Barcode)
		surfaceGui:SetAttribute(RENDERED_BARCODE_ATTRIBUTE, product.Barcode)
	end

	return true
end

function ProductService.GetProduct(item: Model): ProductCatalog.ProductInfo?
	if item:GetAttribute("ItemType") ~= "Box" then
		return nil
	end

	local itemId = getItemId(item)
	return if itemId ~= nil then ProductCatalog.Get(itemId) else nil
end

function ProductService.ApplyToItem(itemValue: unknown): boolean
	if typeof(itemValue) ~= "Instance" or not itemValue:IsA("Model") then
		return false
	end

	local item = itemValue :: Model
	if item:GetAttribute("ItemType") ~= "Box" then
		return false
	end

	local itemId = getItemId(item)
	if itemId == nil then
		clearRuntimePresentation(item)
		warnOnce(
			"missing-item-id:" .. item:GetFullName(),
			string.format("%s has no non-empty ItemId", item:GetFullName())
		)
		return false
	end

	local product = ProductCatalog.Get(itemId)
	if product == nil then
		clearRuntimePresentation(item)
		warnOnce("unknown-item-id:" .. itemId, string.format("unknown ItemId %s on %s", itemId, item:GetFullName()))
		return false
	end

	item:SetAttribute("Barcode", product.Barcode)
	item:SetAttribute("DisplayName", product.DisplayName)

	local surface = item:FindFirstChild(BARCODE_SURFACE_NAME)
	if surface == nil or not surface:IsA("BasePart") then
		warnOnce(
			"missing-surface:" .. item:GetFullName(),
			string.format("%s is missing a direct BasePart named %s", item:GetFullName(), BARCODE_SURFACE_NAME)
		)
		return false
	end

	return applyLabel(surface, product)
end

function ProductService.ApplyAll(root: Instance): number
	local appliedCount = 0
	local function applyIfBox(instance: Instance)
		if
			instance:IsA("Model")
			and instance:GetAttribute("ItemType") == "Box"
			and getItemId(instance) ~= nil
			and ProductService.ApplyToItem(instance)
		then
			appliedCount += 1
		end
	end

	applyIfBox(root)
	for _, descendant in root:GetDescendants() do
		applyIfBox(descendant)
	end

	return appliedCount
end

function ProductService.Start()
	if started then
		return
	end
	started = true

	local warehouse = Workspace:FindFirstChild("Warehouse")
	if warehouse == nil then
		warnOnce("missing-warehouse", "Workspace.Warehouse was not found")
		return
	end

	ProductService.ApplyAll(warehouse)
end

return ProductService
