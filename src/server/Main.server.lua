local RackGenerator = require(script.Parent.RackGenerator)
local RackLabelService = require(script.Parent.RackLabelService)
local SlotRegistry = require(script.Parent.SlotRegistry)

local generatedRacks = RackGenerator.Generate()
if generatedRacks ~= nil then
	SlotRegistry.Rebuild(generatedRacks)
	RackLabelService.ApplyAll()
end
