local UserInputService = require("../Services").UserInputService
local Platform = require("./Platform")
local isLuwow = require("../isLuwow")

local PlatformMap = {
	["ps4"] = Platform.PS4,
	["ps5"] = Platform.PS5,
	["xbox"] = Platform.Xbox,
}

local function getInputPlatform()
	if isLuwow then
		return Platform.Default
	end
	local img: string = UserInputService:GetImageForKeyCode(Enum.KeyCode.ButtonStart)
	for platformString, platform in PlatformMap do
		if img:find(platformString) then
			return platform
		end
	end
	-- fallback to GetStringForKeyCode
	return if UserInputService:GetStringForKeyCode(Enum.KeyCode.ButtonA) == "ButtonCross"
		then Platform.PS5
		else Platform.Xbox
end

return getInputPlatform
