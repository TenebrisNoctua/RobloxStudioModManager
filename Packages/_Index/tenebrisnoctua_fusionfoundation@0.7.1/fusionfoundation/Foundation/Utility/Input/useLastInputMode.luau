local InputMode = require("./InputMode")
local getInputMode = require("./getInputMode")

local Types = require("../Types")
local Wrappers = require("../Wrappers")

local UserInputService = Wrappers.Services.UserInputService

type UsedAs<T> = Types.UsedAs<T>
type Scope = Types.Scope

type InputMode = InputMode.InputMode

local function getLastInputMode(): InputMode?
	return getInputMode(UserInputService:GetLastInputType())
end

return function(scope: Scope): UsedAs<InputMode?>
	local lastInputMode = scope:Value(getLastInputMode())

	local connection = UserInputService.LastInputTypeChanged:Connect(function()
		lastInputMode:set(getLastInputMode())
	end)
	table.insert(scope, function()
		connection:Disconnect()
	end)

	return lastInputMode
end
