--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Packs an array of numbers into a given animatable data type.
	If the type is not animatable, nil will be returned.

	Numbers are packed here, other types by the runtime provider.
]]

local Types = require("../Types")
local Runtime = require("../Runtime")

local function packType(
	numbers: {number},
	typeString: string
): Types.Animatable?
	if typeString == "number" then
		return numbers[1]
	end
	return Runtime.get().packType(numbers, typeString)
end

return packType
