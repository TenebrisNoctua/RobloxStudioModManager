--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Constructs special keys for property tables which connect property change
	listeners to an instance.
]]

local Types = require("../Types")
local External = require("../External")
local Runtime = require("../Runtime")

local keyCache: {[string]: Types.SpecialKey} = {}

local function OnChange(
	propertyName: string
): Types.SpecialKey
	local key = keyCache[propertyName]
	if key == nil then
		key = {
			type = "SpecialKey",
			kind = "OnChange",
			stage = "observer",
			apply = function(
				self: Types.SpecialKey,
				scope: Types.Scope<unknown>,
				callback: unknown,
				applyTo: Types.Instance
			)
				if typeof(callback) ~= "function" then
					External.logError("invalidChangeHandler", nil, propertyName)
				end
				local callback = callback :: (...unknown) -> (...unknown)
				local runtime = Runtime.get()
				local disconnect = runtime.connectPropertyChanged(applyTo, propertyName, function()
					callback(runtime.getProperty(applyTo, propertyName), applyTo)
				end)
				if disconnect == nil then
					External.logError("cannotConnectChange", nil, runtime.className(applyTo), propertyName)
				else
					table.insert(scope, disconnect)
				end
			end
		}
		keyCache[propertyName] = key
	end
	return key
end

return OnChange
