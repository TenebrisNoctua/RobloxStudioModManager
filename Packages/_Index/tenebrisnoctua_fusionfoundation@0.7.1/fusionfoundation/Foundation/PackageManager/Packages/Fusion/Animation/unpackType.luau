--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Unpacks an animatable type into an array of numbers.
	If the type is not animatable, an empty array will be returned.

	Numbers are unpacked here, other types by the runtime provider.
]]

local Runtime = require("../Runtime")

local function unpackType(
	value: unknown,
	typeString: string
): {number}
	if typeString == "number" then
		local value = value :: number
		return {value}
	end
	return Runtime.get().unpackType(value, typeString)
end

return unpackType
