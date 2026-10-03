--!strict

local ScannerTarget = {}

function ScannerTarget.FindPhysicalBoxModel(instance: Instance?): Model?
	local current = instance

	while current ~= nil do
		if current:IsA("Model") and current:GetAttribute("ItemType") == "Box" then
			return current
		end

		current = current.Parent
	end

	return nil
end

function ScannerTarget.GetItemId(item: Model): string?
	local itemId = item:GetAttribute("ItemId")
	if typeof(itemId) == "string" and itemId ~= "" then
		return itemId
	end

	return nil
end

function ScannerTarget.IsScanCandidate(item: Model): boolean
	return item:GetAttribute("ItemType") == "Box" and ScannerTarget.GetItemId(item) ~= nil
end

return table.freeze(ScannerTarget)
