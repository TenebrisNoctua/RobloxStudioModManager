local Datatypes = require("./Luwow/Datatypes")
local Enum = Datatypes.Enum

local Types = require("./Types")

local UserInputService = require("./Wrappers").Services.UserInputService

type UsedAs<T> = Types.UsedAs<T>
type Scope = Types.Scope

return function(scope: Scope): UsedAs<Enum.PreferredInput>
	local preferredInput = scope:Value(UserInputService.PreferredInput)
	table.insert(scope, UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function() 
		preferredInput:set(UserInputService.PreferredInput)
	end))

	preferredInput:set(UserInputService.PreferredInput)

	return preferredInput
end