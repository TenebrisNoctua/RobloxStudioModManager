local PackageManager = require("../PackageManager")

local Dash = PackageManager.getPackage("Dash")

local function isBuilderIcon(icon: string?)
	return icon ~= nil and icon ~= "" and icon:find("[^%l%d%-]") == nil
end

return Dash.memoize(isBuilderIcon)
