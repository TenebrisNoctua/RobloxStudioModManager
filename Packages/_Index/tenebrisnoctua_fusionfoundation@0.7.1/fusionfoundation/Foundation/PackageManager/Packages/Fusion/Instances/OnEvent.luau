--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Constructs special keys for property tables which connect event listeners to
	an instance.
]]

local Types = require("../Types")
local External = require("../External")
local Runtime = require("../Runtime")

local keyCache: {[string]: Types.SpecialKey} = {}

local function OnEvent(
	eventName: string
): Types.SpecialKey
	local key = keyCache[eventName]
	if key == nil then
		key = {
			type = "SpecialKey",
			kind = "OnEvent",
			stage = "observer",
			apply = function(
				self: Types.SpecialKey,
				scope: Types.Scope<unknown>,
				callback: unknown,
				applyTo: Types.Instance
			)
				if typeof(callback) ~= "function" then
					External.logError("invalidEventHandler", nil, eventName)
				end
				local runtime = Runtime.get()
				local disconnect = runtime.connectEvent(applyTo, eventName, callback :: any)
				if disconnect == nil then
					External.logError("cannotConnectEvent", nil, runtime.className(applyTo), eventName)
				else
					table.insert(scope, disconnect)
				end
			end
		}
		keyCache[eventName] = key
	end
	return key
end

return OnEvent
