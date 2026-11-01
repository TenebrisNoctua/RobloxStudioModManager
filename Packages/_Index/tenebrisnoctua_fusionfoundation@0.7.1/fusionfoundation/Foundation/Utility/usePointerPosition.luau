--!nonstrict
local Datatypes = require("./Luwow/Datatypes")
local Vector2 = Datatypes.Vector2

local Instances = require("./Luwow/Instances")
local unwrap = require("./unwrap")
local Wrappers = require("./Wrappers")
local Types = require("./Types")

local Signal = Wrappers.Signal
local Connection = Wrappers.Connection

type UsedAs<T> = Types.UsedAs<T>
type Scope = Types.Scope
type Use = Types.Use

return function(scope: Scope, guiObject: UsedAs<GuiObject?>): UsedAs<UsedAs<Vector2>>
	return scope:Computed(function(use: Use, innerScope: Scope) 
		local guiObjectWrapped = unwrap(guiObject, use)
		if not guiObjectWrapped then return end
		
		local guiObject = unwrap(guiObjectWrapped, use)
		if not guiObject then return end
		
		local position = innerScope:Value(Vector2.zero)
		
		local function setPositionFromInput(input: InputObject)
			if input.Position.X > 0 or input.Position.Y > 0 then
				position:set(Vector2.new(input.Position.X, input.Position.Y))
			end
		end
		
		local connections: { RBXScriptConnection? } = {
			Instances.connectEvent(guiObject, "InputBegan", setPositionFromInput),
			Instances.connectEvent(guiObject, "InputChanged", setPositionFromInput),
			Instances.connectEvent(guiObject, "InputEnded", setPositionFromInput),
		}
		
		table.insert(innerScope, function() 
			for _, connection in connections do
				if connection then
					Connection.Disconnect(connection)
				end
			end
		end)
		
		return position
	end)
end