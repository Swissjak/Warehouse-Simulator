--!strict

local CarryConfig = {
	InteractionDistance = 8,
	ServerDistanceTolerance = 1,
	CarryDistance = 3.5,
	RequestCooldown = 0.15,
	PlacementRayDistance = 30,
	PlacementSurfaceNormalMinY = 0.7,
	PlacementOverlapShrink = 0.1,
	PlacementSurfaceProbeAbove = 0.5,
	PlacementSurfaceProbeBelow = 0.75,
	PlacementSurfaceHeightTolerance = 0.2,
	PlacementOrientationDotTolerance = 0.9999,
	RotationStepDegrees = 90,
	RotationStepCount = 4,
	GhostTransparency = 0.65,
	RemotesFolderName = "Remotes",
	RemoteEventName = "CarryRequest",
	CarryingAttributeName = "IsCarryingItem",
}

return table.freeze(CarryConfig)
