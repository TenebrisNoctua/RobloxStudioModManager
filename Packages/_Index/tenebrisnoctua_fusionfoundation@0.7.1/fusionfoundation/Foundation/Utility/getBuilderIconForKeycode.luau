local Datatypes = require("./Luwow/Datatypes")
local Enum = Datatypes.Enum

local PackageManager = require("../PackageManager")

local BuilderIcons = PackageManager.getPackage("BuilderIcons")

local getBuilderIconForKeycode = BuilderIcons.getBuilderIconForKeycode

return function(keycode: Enum.KeyCode): string?
	local success, icon = pcall(function()
		return getBuilderIconForKeycode(keycode)
	end)
	return if success then icon else nil
end
