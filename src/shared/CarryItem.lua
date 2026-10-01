--!strict

local CarryItem = {}

function CarryItem.GetRootPart(item: Model): BasePart?
	if item.PrimaryPart ~= nil then
		return item.PrimaryPart
	end

	local body = item:FindFirstChild("Body")
	if body ~= nil and body:IsA("BasePart") then
		return body
	end

	return nil
end

function CarryItem.FindCarryableModel(instance: Instance?): Model?
	local current = instance

	while current ~= nil do
		if current:IsA("Model") and current:GetAttribute("Carryable") == true then
			return current
		end

		current = current.Parent
	end

	return nil
end

return CarryItem
