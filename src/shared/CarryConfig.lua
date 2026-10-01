--!strict

local CarryConfig = {
	InteractionDistance = 8,
	ServerDistanceTolerance = 1,
	CarryDistance = 3.5,
	RequestCooldown = 0.15,
	RemotesFolderName = "Remotes",
	RemoteEventName = "CarryRequest",
	CarryingAttributeName = "IsCarryingItem",
}

return table.freeze(CarryConfig)
