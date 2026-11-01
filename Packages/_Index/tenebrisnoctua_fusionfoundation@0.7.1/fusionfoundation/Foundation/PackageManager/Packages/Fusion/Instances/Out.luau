--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	A special key for property tables, which allows users to extract values from
	an instance into an automatically-updated Value object.
]]

local Types = require("../Types")
local External = require("../External")
local Runtime = require("../Runtime")
-- Memory
local checkLifetime = require("../Memory/checkLifetime")
-- State
local castToState = require("../State/castToState")

local keyCache: {[string]: Types.SpecialKey} = {}

local function Out(
	propertyName: string
): Types.SpecialKey
	local key = keyCache[propertyName]
	if key == nil then
		key = {
			type = "SpecialKey",
			kind = "Out",
			stage = "observer",
			apply = function(
				self: Types.SpecialKey,
				scope: Types.Scope<unknown>,
				value: unknown,
				applyTo: Types.Instance
			)
				if not castToState(value) then
					External.logError("invalidOutType")
				end
				local value = value :: Types.StateObject<unknown>
				if value.kind ~= "Value" then
					External.logError("invalidOutType")
				end
				local value = value :: Types.Value<unknown>

				checkLifetime.bOutlivesA(
					scope, applyTo,
					value.scope, value.oldestTask,
					checkLifetime.formatters.propertyOutputsTo, propertyName
				)

				local runtime = Runtime.get()
				local disconnect = runtime.connectPropertyChanged(applyTo, propertyName, function()
					value:set(runtime.getProperty(applyTo, propertyName))
				end)
				if disconnect == nil then
					External.logError("invalidOutProperty", nil, runtime.className(applyTo), propertyName)
				end
				value:set(runtime.getProperty(applyTo, propertyName))
				table.insert(scope, disconnect)
			end
		}
		keyCache[propertyName] = key
	end
	return key
end

return Out
