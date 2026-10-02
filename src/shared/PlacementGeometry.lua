--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WarehouseShared = ReplicatedStorage:WaitForChild("WarehouseShared")
local CarryConfig = require(WarehouseShared:WaitForChild("CarryConfig"))

local PlacementGeometry = {}

export type BoundsInfo = {
	pivotToBounds: CFrame,
	size: Vector3,
}

local function projectedHalfHeight(boundsCFrame: CFrame, size: Vector3): number
	return math.abs(boundsCFrame.RightVector.Y) * size.X / 2
		+ math.abs(boundsCFrame.UpVector.Y) * size.Y / 2
		+ math.abs(boundsCFrame.LookVector.Y) * size.Z / 2
end

function PlacementGeometry.GetBoundsInfo(model: Model): BoundsInfo
	local pivot = model:GetPivot()
	local boundsCFrame, boundsSize = model:GetBoundingBox()

	return {
		pivotToBounds = pivot:ToObjectSpace(boundsCFrame),
		size = boundsSize,
	}
end

function PlacementGeometry.IsRotationStep(value: unknown): boolean
	if typeof(value) ~= "number" then
		return false
	end

	return value == value
		and math.abs(value) < math.huge
		and value % 1 == 0
		and value >= 0
		and value < CarryConfig.RotationStepCount
end

function PlacementGeometry.GetYawRotation(rotationStep: number): CFrame
	local yaw = math.rad(rotationStep * CarryConfig.RotationStepDegrees)
	return CFrame.Angles(0, yaw, 0)
end

function PlacementGeometry.GetWorldBounds(candidateCFrame: CFrame, boundsInfo: BoundsInfo): (CFrame, Vector3)
	return candidateCFrame * boundsInfo.pivotToBounds, boundsInfo.size
end

function PlacementGeometry.GetBoundsBottomY(boundsCFrame: CFrame, boundsSize: Vector3): number
	return boundsCFrame.Position.Y - projectedHalfHeight(boundsCFrame, boundsSize)
end

function PlacementGeometry.GetBoundsTopY(boundsCFrame: CFrame, boundsSize: Vector3): number
	return boundsCFrame.Position.Y + projectedHalfHeight(boundsCFrame, boundsSize)
end

function PlacementGeometry.CreateCandidateCFrame(
	surfacePoint: Vector3,
	rotationStep: number,
	boundsInfo: BoundsInfo
): CFrame
	local rotation = PlacementGeometry.GetYawRotation(rotationStep)
	local boundsAtOrigin = rotation * boundsInfo.pivotToBounds
	local bottomAtOrigin = PlacementGeometry.GetBoundsBottomY(boundsAtOrigin, boundsInfo.size)

	return CFrame.new(surfacePoint.X, surfacePoint.Y - bottomAtOrigin, surfacePoint.Z) * rotation
end

function PlacementGeometry.GetShrunkSize(boundsSize: Vector3): Vector3
	local shrink = CarryConfig.PlacementOverlapShrink

	return Vector3.new(
		math.max(boundsSize.X - shrink, 0.01),
		math.max(boundsSize.Y - shrink, 0.01),
		math.max(boundsSize.Z - shrink, 0.01)
	)
end

function PlacementGeometry.IsFiniteVector3(value: Vector3): boolean
	return value.X == value.X
		and value.Y == value.Y
		and value.Z == value.Z
		and math.abs(value.X) < math.huge
		and math.abs(value.Y) < math.huge
		and math.abs(value.Z) < math.huge
end

return PlacementGeometry
