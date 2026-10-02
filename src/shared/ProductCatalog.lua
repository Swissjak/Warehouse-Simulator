--!strict

local ProductCatalog = {}

export type ProductInfo = {
	ItemId: string,
	DisplayName: string,
	Barcode: string,
}

type ProductDefinition = {
	DisplayName: string,
	Barcode: string,
}

-- ItemId is the canonical product identifier used by gameplay and persistence.
-- Barcode is an immutable unique scan/lookup identifier and never the primary persistence key.
-- The rendered gameplay pattern may change independently without changing Barcode.
local definitions: { [string]: ProductDefinition } = {
	TEST_BOX = {
		DisplayName = "Test Product",
		Barcode = "4827619053144",
	},
	TEST_BOX_B = {
		DisplayName = "Test Product B",
		Barcode = "5903927581643",
	},
	TEST_BOX_W = {
		DisplayName = "Test Product W",
		Barcode = "4008472619054",
	},
	TEST_BOX_G = {
		DisplayName = "Test Product G",
		Barcode = "8715642039784",
	},
	TEST_BOX_P = {
		DisplayName = "Test Product P",
		Barcode = "7293158402670",
	},
}

local productsByItemId: { [string]: ProductInfo } = {}
local productsByBarcode: { [string]: ProductInfo } = {}

local function validateNonEmptyString(value: unknown, fieldName: string, itemId: string): string
	if typeof(value) ~= "string" or value == "" then
		error(string.format("[ProductCatalog] %s for %s must be a non-empty string", fieldName, itemId))
	end

	return value
end

for itemId, definition in definitions do
	local validatedItemId = validateNonEmptyString(itemId, "ItemId", tostring(itemId))
	local displayName = validateNonEmptyString(definition.DisplayName, "DisplayName", validatedItemId)
	local barcode = validateNonEmptyString(definition.Barcode, "Barcode", validatedItemId)
	local duplicate = productsByBarcode[barcode]
	if duplicate ~= nil then
		error(
			string.format(
				"[ProductCatalog] duplicate Barcode %s for %s and %s",
				barcode,
				duplicate.ItemId,
				validatedItemId
			)
		)
	end

	local product: ProductInfo = table.freeze({
		ItemId = validatedItemId,
		DisplayName = displayName,
		Barcode = barcode,
	})
	productsByItemId[validatedItemId] = product
	productsByBarcode[barcode] = product
end

table.freeze(productsByItemId)
table.freeze(productsByBarcode)

function ProductCatalog.Get(itemId: string): ProductInfo?
	return productsByItemId[itemId]
end

function ProductCatalog.GetByBarcode(barcode: string): ProductInfo?
	return productsByBarcode[barcode]
end

function ProductCatalog.Exists(itemId: string): boolean
	return productsByItemId[itemId] ~= nil
end

return table.freeze(ProductCatalog)
