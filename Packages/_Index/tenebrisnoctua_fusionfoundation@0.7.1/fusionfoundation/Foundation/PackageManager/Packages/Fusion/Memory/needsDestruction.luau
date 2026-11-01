--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Returns true if the given value is not automatically memory managed, and
	requires manual cleanup.
]]

local Runtime = require("../Runtime")

local function needsDestruction(
	x: unknown
): boolean
	return Runtime.get().isInstance(x)
end

return needsDestruction