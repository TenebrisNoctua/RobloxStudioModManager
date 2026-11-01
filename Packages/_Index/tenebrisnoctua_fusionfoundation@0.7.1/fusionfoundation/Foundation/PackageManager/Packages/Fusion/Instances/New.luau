--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
	Constructs and returns a new instance, with options for setting properties,
	event handlers and other attributes on the instance right away.

	The runtime provider creates the instance, along with any defaults it gives
	the class.
]]

local Types = require("../Types")
local External = require("../External")
local Runtime = require("../Runtime")
local applyInstanceProps = require("./applyInstanceProps")

type Component = (Types.PropertyTable) -> Types.Instance

local function New(
	scope: Types.Scope<unknown>,
	className: string
)
	if (className :: any) == nil then
		local scope = (scope :: any) :: string
		External.logError("scopeMissing", nil, "instances using New", "myScope:New \"" .. scope .. "\" { ... }")
	end

	-- This might look appealing to try and cache. But please don't. The scope
	-- upvalue is shared between the two curried function calls, so this will
	-- open incredible cross-codebase wormholes like you've never seen before.
	return function(
		props: Types.PropertyTable
	): Types.Instance
		local instance = Runtime.get().newInstance(className)
		if instance == nil then
			External.logError("cannotCreateClass", nil, className)
		end

		table.insert(scope, instance)
		applyInstanceProps(scope, props, instance)

		return instance
	end
end

return New
