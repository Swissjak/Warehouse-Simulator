--!strict

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local WarehouseShared = ReplicatedStorage:WaitForChild("WarehouseShared")
local Config = require(WarehouseShared:WaitForChild("Config"))
local ScannerTarget = require(WarehouseShared:WaitForChild("ScannerTarget"))

local ScannerController = {}

export type ScanResult = {
	Success: boolean,
	ItemId: string?,
	Barcode: string?,
	DisplayName: string?,
	Reason: string?,
}

local TOGGLE_ACTION_NAME = "WarehouseScannerToggle"
local SCAN_ACTION_NAME = "WarehouseScannerScan"
local SCAN_ACTION_PRIORITY = Enum.ContextActionPriority.High.Value
local UI_NAME = "WarehouseScannerGui"
local HIGHLIGHT_COLOR = Color3.fromRGB(70, 205, 255)

local started = false
local scannerEnabled = false
local currentTarget: Model? = nil
local scannerRemote: RemoteEvent? = nil
local resultRevision = 0
local screenGui: ScreenGui? = nil
local statusLabel: TextLabel? = nil
local productLabel: TextLabel? = nil
local barcodeLabel: TextLabel? = nil
local itemIdLabel: TextLabel? = nil
local scanCompletedEvent = Instance.new("BindableEvent")

ScannerController.ScanCompleted = scanCompletedEvent.Event

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

local highlight = Instance.new("Highlight")
highlight.Name = "ScannerTargetHighlight"
highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
highlight.FillColor = HIGHLIGHT_COLOR
highlight.FillTransparency = 0.78
highlight.OutlineColor = HIGHLIGHT_COLOR
highlight.OutlineTransparency = 0
highlight.Enabled = false

local function createTextLabel(parent: Instance, name: string, positionY: number, height: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(12, positionY)
	label.Size = UDim2.new(1, -24, 0, height)
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.fromRGB(235, 245, 250)
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = parent
	return label
end

local function createUi()
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = UI_NAME
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Enabled = false
	gui.Parent = playerGui
	screenGui = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -24, 0.5, 0)
	panel.Size = UDim2.fromOffset(260, 130)
	panel.BackgroundColor3 = Color3.fromRGB(18, 27, 32)
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = HIGHLIGHT_COLOR
	stroke.Transparency = 0.25
	stroke.Thickness = 1
	stroke.Parent = panel

	local header = createTextLabel(panel, "Header", 8, 20)
	header.Font = Enum.Font.GothamBold
	header.Text = "SCANNER"
	header.TextColor3 = HIGHLIGHT_COLOR
	header.TextSize = 15

	statusLabel = createTextLabel(panel, "Status", 32, 22)
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.Text = "READY"
	statusLabel.TextSize = 16

	productLabel = createTextLabel(panel, "DisplayName", 57, 20)
	barcodeLabel = createTextLabel(panel, "Barcode", 80, 20)
	barcodeLabel.Font = Enum.Font.Code
	itemIdLabel = createTextLabel(panel, "ItemId", 104, 16)
	itemIdLabel.TextColor3 = Color3.fromRGB(150, 170, 180)
	itemIdLabel.TextSize = 12
end

local function showReady()
	if statusLabel ~= nil then
		statusLabel.Text = "READY"
		statusLabel.TextColor3 = Color3.fromRGB(235, 245, 250)
	end
	if productLabel ~= nil then
		productLabel.Text = ""
	end
	if barcodeLabel ~= nil then
		barcodeLabel.Text = ""
	end
	if itemIdLabel ~= nil then
		itemIdLabel.Text = ""
	end
end

local function showResult(result: ScanResult)
	resultRevision += 1
	local revision = resultRevision

	if result.Success then
		if statusLabel ~= nil then
			statusLabel.Text = "SCAN OK"
			statusLabel.TextColor3 = Color3.fromRGB(105, 235, 135)
		end
		if productLabel ~= nil then
			productLabel.Text = result.DisplayName or ""
		end
		if barcodeLabel ~= nil then
			barcodeLabel.Text = result.Barcode or ""
		end
		if itemIdLabel ~= nil then
			itemIdLabel.Text = result.ItemId or ""
		end
	else
		if statusLabel ~= nil then
			statusLabel.Text = "SCAN FAILED"
			statusLabel.TextColor3 = Color3.fromRGB(245, 105, 105)
		end
		if productLabel ~= nil then
			productLabel.Text = ""
		end
		if barcodeLabel ~= nil then
			barcodeLabel.Text = ""
		end
		if itemIdLabel ~= nil then
			itemIdLabel.Text = ""
		end
	end

	task.delay(Config.ScannerResultDisplayDuration, function()
		if resultRevision == revision and scannerEnabled then
			showReady()
		end
	end)
end

local function setTarget(target: Model?)
	if currentTarget == target then
		return
	end

	currentTarget = target
	highlight.Adornee = target
	highlight.Enabled = scannerEnabled and target ~= nil
end

local function findTarget(): Model?
	if not scannerEnabled then
		return nil
	end

	local camera = Workspace.CurrentCamera
	if camera == nil then
		return nil
	end

	local character = player.Character
	if character ~= nil then
		raycastParams.FilterDescendantsInstances = { character }
	else
		raycastParams.FilterDescendantsInstances = {}
	end

	local viewportCenter = camera.ViewportSize / 2
	local ray = camera:ViewportPointToRay(viewportCenter.X, viewportCenter.Y)
	local result = Workspace:Raycast(ray.Origin, ray.Direction * Config.ScannerMaxDistance, raycastParams)
	if result == nil then
		return nil
	end

	local item = ScannerTarget.FindPhysicalBoxModel(result.Instance)
	if item == nil or not ScannerTarget.IsScanCandidate(item) then
		return nil
	end

	return item
end

local function onToggle(
	_actionName: string,
	inputState: Enum.UserInputState,
	_inputObject: InputObject
): Enum.ContextActionResult
	if inputState == Enum.UserInputState.Begin then
		ScannerController.SetEnabled(not scannerEnabled)
	end

	return Enum.ContextActionResult.Sink
end

local function onScan(
	_actionName: string,
	inputState: Enum.UserInputState,
	_inputObject: InputObject
): Enum.ContextActionResult
	if not scannerEnabled then
		return Enum.ContextActionResult.Pass
	end

	if inputState == Enum.UserInputState.Begin then
		ScannerController.TryScan()
	end

	return Enum.ContextActionResult.Sink
end

function ScannerController.SetEnabled(enabled: boolean)
	scannerEnabled = enabled
	resultRevision += 1

	if screenGui ~= nil then
		screenGui.Enabled = enabled
	end

	if enabled then
		showReady()
	else
		setTarget(nil)
		highlight.Enabled = false
	end
end

function ScannerController.IsEnabled(): boolean
	return scannerEnabled
end

function ScannerController.GetTarget(): Model?
	if currentTarget ~= nil and currentTarget.Parent == nil then
		setTarget(nil)
	end

	return currentTarget
end

function ScannerController.TryScan(): boolean
	if not scannerEnabled or scannerRemote == nil then
		return false
	end

	local target = ScannerController.GetTarget()
	scannerRemote:FireServer(target)
	return target ~= nil
end

function ScannerController.Start()
	if started then
		return
	end
	started = true

	createUi()
	highlight.Parent = Workspace

	local remotes = WarehouseShared:WaitForChild(Config.ScannerRemotesFolderName)
	local remote = remotes:WaitForChild(Config.ScannerRemoteEventName)
	if not remote:IsA("RemoteEvent") then
		error(string.format("[ScannerController] %s must be a RemoteEvent", remote:GetFullName()))
	end
	scannerRemote = remote
	remote.OnClientEvent:Connect(function(resultValue: unknown)
		if typeof(resultValue) ~= "table" or typeof(resultValue.Success) ~= "boolean" then
			return
		end

		local result = resultValue :: ScanResult
		scanCompletedEvent:Fire(result)
		if scannerEnabled then
			showResult(result)
		end
	end)

	RunService.RenderStepped:Connect(function()
		setTarget(findTarget())
	end)

	ContextActionService:BindAction(TOGGLE_ACTION_NAME, onToggle, false, Config.ScannerToggleKey)
	ContextActionService:BindActionAtPriority(
		SCAN_ACTION_NAME,
		onScan,
		false,
		SCAN_ACTION_PRIORITY,
		Enum.UserInputType.MouseButton1
	)
end

return ScannerController
