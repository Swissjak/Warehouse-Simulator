local CarryService = require(script.Parent.CarryService)
local PalletRegistry = require(script.Parent.PalletRegistry)
local ProductService = require(script.Parent.ProductService)
local RackGenerator = require(script.Parent.RackGenerator)
local RackLabelService = require(script.Parent.RackLabelService)
local RackNumberService = require(script.Parent.RackNumberService)
local SlotRegistry = require(script.Parent.SlotRegistry)

ProductService.Start()
PalletRegistry.Start()
CarryService.Start()

local generatedRacks = RackGenerator.Generate()
if generatedRacks ~= nil then
	SlotRegistry.Rebuild(generatedRacks)
	RackLabelService.ApplyAll()
	RackNumberService.ApplyAll()
end
