--!strict

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local WarehouseShared = ReplicatedStorage:WaitForChild("WarehouseShared")
local CarryConfig = require(WarehouseShared:WaitForChild("CarryConfig"))
local CarryItem = require(WarehouseShared:WaitForChild("CarryItem"))

local InteractionController = {}

local ACTION_NAME = "WarehouseCarryInteraction"
local started = false
local currentTarget: Model? = nil
local lastRequestTime = 0

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

local highlight = Instance.new("Highlight")
highlight.Name = "CarryTargetHighlight"
highlight.DepthMode = Enum.HighlightDepthMode.Occluded
highlight.FillColor = Color3.fromRGB(255, 196, 64)
highlight.FillTransparency = 0.75
highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
highlight.OutlineTransparency = 0
highlight.Enabled = false

local function setTarget(target: Model?)
	if currentTarget == target then
		return
	end

	currentTarget = target
	highlight.Adornee = target
	highlight.Enabled = target ~= nil
end

local function findTarget(): Model?
	if player:GetAttribute(CarryConfig.CarryingAttributeName) == true then
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
	local result = Workspace:Raycast(
		ray.Origin,
		ray.Direction * CarryConfig.InteractionDistance,
		raycastParams
	)
	if result == nil then
		return nil
	end

	local item = CarryItem.FindCarryableModel(result.Instance)
	if item == nil or CarryItem.GetRootPart(item) == nil then
		return nil
	end

	return item
end

local function onInteraction(
	_actionName: string,
	inputState: Enum.UserInputState,
	_inputObject: InputObject
): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end

	local now = os.clock()
	if now - lastRequestTime < CarryConfig.RequestCooldown then
		return Enum.ContextActionResult.Sink
	end
	lastRequestTime = now

	local remotes = WarehouseShared:FindFirstChild(CarryConfig.RemotesFolderName)
	local remote = if remotes ~= nil
		then remotes:FindFirstChild(CarryConfig.RemoteEventName)
		else nil
	if remote == nil or not remote:IsA("RemoteEvent") then
		return Enum.ContextActionResult.Sink
	end

	if player:GetAttribute(CarryConfig.CarryingAttributeName) == true then
		remote:FireServer("Drop")
	elseif currentTarget ~= nil then
		remote:FireServer("Pickup", currentTarget)
	end

	return Enum.ContextActionResult.Sink
end

function InteractionController.Start()
	if started then
		return
	end
	started = true

	highlight.Parent = Workspace

	RunService.RenderStepped:Connect(function()
		setTarget(findTarget())
	end)

	ContextActionService:BindAction(ACTION_NAME, onInteraction, false, Enum.KeyCode.E)
end

return InteractionController
