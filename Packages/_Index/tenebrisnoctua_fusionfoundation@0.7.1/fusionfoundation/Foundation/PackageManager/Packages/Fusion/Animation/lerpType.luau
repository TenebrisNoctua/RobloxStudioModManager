--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Linearly interpolates the given animatable types by a ratio.
	If the types are different or not animatable, then the first value will be
	returned for ratios below 0.5, and the second value for 0.5 and above.

	Numbers are interpolated here, other types by the runtime provider.
]]

local Runtime = require("../Runtime")

local function lerpType(
	from: unknown, 
	to: unknown, 
	ratio: number
): unknown
	local typeString = typeof(from)
	if typeof(to) == typeString then
		-- both types must match for interpolation to make sense
		if typeString == "number" then
			local to, from = to :: number, from :: number
			return (to - from) * ratio + from
		end

		local value = Runtime.get().lerpType(from, to, ratio, typeString)
		if value ~= nil then
			return value
		end
	end

	-- fallback case: the types are different or not animatable
	if ratio < 0.5 then
		return from
	else
		return to
	end
end

return lerpType
