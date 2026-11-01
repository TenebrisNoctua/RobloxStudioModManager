--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Abstraction layer between Fusion internals and the runtime Fusion runs on,
	such as Roblox or Luwow. The runtime provider gives the primitives Fusion
	builds instances and animations from, and is also the external provider
	for scheduling and logging.

	Providers live in the Runtimes folder, one module per runtime.
]]

local Types = require("./Types")
local External = require("./External")

local detectedProvider: Types.RuntimeProvider
do
	local description = _RUNTIME :: any
	if typeof(description) == "table" and description.name == "luwow" then
		detectedProvider = require("./Runtimes/Luwow") :: any
	else
		detectedProvider = require("./Runtimes/Roblox") :: any
	end
end

local currentProvider: Types.RuntimeProvider? = nil

local Runtime = {}

--[[
	Returns the provider for the runtime this code is running on.
]]
function Runtime.detect(): Types.RuntimeProvider
	return detectedProvider
end

--[[
	Swaps to a new runtime provider, which also becomes the external provider.
	Returns the old provider, so it can be used again later.
]]
function Runtime.setProvider(
	newProvider: Types.RuntimeProvider?
): Types.RuntimeProvider?
	local oldProvider = currentProvider
	currentProvider = newProvider
	External.setExternalProvider(newProvider)
	return oldProvider
end

--[[
	Returns the current runtime provider. Throws if none is set.
]]
function Runtime.get(): Types.RuntimeProvider
	local provider = currentProvider
	if provider == nil then
		return External.logError("noRuntime")
	end
	return provider
end

return Runtime
