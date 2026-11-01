--[[
	Whether Foundation is running on Luwow rather than Roblox. Luwow describes
	itself with the _RUNTIME global, which Roblox doesn't have.
]]

local description = _RUNTIME :: any
local isLuwow = typeof(description) == "table"
	and typeof(description.name) == "string"
	and string.lower(description.name) == "luwow"

return isLuwow
