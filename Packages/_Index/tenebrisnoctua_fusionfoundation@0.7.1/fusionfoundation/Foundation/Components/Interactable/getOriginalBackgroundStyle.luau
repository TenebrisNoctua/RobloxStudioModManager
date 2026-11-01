local Datatypes = require("../../Utility/Luwow/Datatypes")
local Color3 = Datatypes.Color3

local unwrap = require("../../Utility/unwrap")
local Types = require("../../Utility/Types")

type UsedAs<T> = Types.UsedAs<T>
type ColorStyle = Types.ColorStyle

local function getOriginalBackgroundStyle(
	backgroundColor: UsedAs<Color3>?,
	backgroundTransparency: UsedAs<number>?
): ColorStyle
	return {
		Color3 = unwrap(backgroundColor),
		Transparency = unwrap(backgroundTransparency)
	}
end

return getOriginalBackgroundStyle
