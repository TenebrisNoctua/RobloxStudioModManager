local KeycodeMappings = require("./KeycodeMappings")
local Platform = require("./Platform")
local getInputPlatform = require("./getInputPlatform")

local function getBuilderIconForKeycode(keyCode: Enum.KeyCode | string): string
	local platform = getInputPlatform()
	local key = if typeof(keyCode) == "string" then keyCode else keyCode.Name
	local mappedIcon = KeycodeMappings[platform][key]
	if mappedIcon then
		return mappedIcon
	end

	-- fallback on exact key name -> mappings when there is no gamepad mapping
	assert(KeycodeMappings[Platform.Default][key], `{key} has no associated BuilderIcon`)
	return KeycodeMappings[Platform.Default][key]
end

return getBuilderIconForKeycode
