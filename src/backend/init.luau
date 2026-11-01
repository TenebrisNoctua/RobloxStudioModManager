const StateManager = require("@self/managers/StateManager")
const VersionManager = require("@self/managers/VersionManager")
const FlagManager = require("@self/managers/FlagManager")
const BootstrapManager = require("@self/managers/BootstrapManager")
const LaunchManager = require("@self/managers/LaunchManager")

--// Local Functions

-- Merges each manager's callback groups into one table
local function mergeCallbacks(...: { [string]: { [string]: any } }): { [string]: { [string]: any } }
	local callbacks = {}
	for index = 1, select("#", ...) do
		for group, functions in (select(index, ...)) do
			callbacks[group] = callbacks[group] or {}
			for name, callback in functions do
				callbacks[group][name] = callback
			end
		end
	end
	return callbacks
end

local function stateCallbacks()
	return {
		App = {
			Exiting = StateManager.save
		},
		Main = {
			GetFlagWarningDisabled = function(): boolean
				return StateManager.get().DisableFlagWarning
			end,
			SetFlagWarningDisabled = function(disabled: boolean)
				StateManager.get().DisableFlagWarning = disabled
			end
		},
		Bootstrap = {
			Closed = StateManager.save
		}
	}
end

--// Initializer
StateManager.load()

return mergeCallbacks(
	stateCallbacks(),
	VersionManager.returnCallbacks(),
	FlagManager.returnCallbacks(),
	BootstrapManager.returnCallbacks(),
	LaunchManager.returnCallbacks()
)
