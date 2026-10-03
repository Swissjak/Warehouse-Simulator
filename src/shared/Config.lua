--!strict

local Config = {
	ScannerToggleKey = Enum.KeyCode.Q,
	ScannerMaxDistance = 12,
	ScannerRequestCooldown = 0.2,
	ScannerResultDisplayDuration = 2.5,
	ScannerRemotesFolderName = "Remotes",
	ScannerRemoteEventName = "ScannerRequest",
}

return table.freeze(Config)
