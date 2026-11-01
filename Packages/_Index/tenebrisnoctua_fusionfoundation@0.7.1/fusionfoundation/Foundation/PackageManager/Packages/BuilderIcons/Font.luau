local BuilderIconsFallback = require("./BuilderIconsFallback")
local isLuwow = require("./isLuwow")

if isLuwow then
	local regular = table.freeze({ Family = "BuilderIcons", Weight = "Regular", Style = "Normal" })
	local filled = table.freeze({ Family = "BuilderIcons", Weight = "Bold", Style = "Normal" })
	return {
		Regular = regular,
		Filled = filled,
		Fallback = {
			Regular = regular,
			Filled = filled,
		},
	}
end

local familyAsset = "rbxasset://LuaPackages/Packages/_Index/BuilderIcons/BuilderIcons/BuilderIcons.json"
local fallbackAsset = `rbxassetid://{BuilderIconsFallback}`

return {
	Regular = Font.new(familyAsset, Enum.FontWeight.Regular),
	Filled = Font.new(familyAsset, Enum.FontWeight.Bold),
	Fallback = {
		Regular = Font.new(fallbackAsset, Enum.FontWeight.Regular),
		Filled = Font.new(fallbackAsset, Enum.FontWeight.Bold),
	},
}
