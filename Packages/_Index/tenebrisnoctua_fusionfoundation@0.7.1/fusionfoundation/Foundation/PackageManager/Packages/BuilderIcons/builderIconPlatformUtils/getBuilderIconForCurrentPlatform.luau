local Platform = require("./Platform")
local getInputPlatform = require("./getInputPlatform")
local PlatformIconMap = require("./PlatformIconMap")
local UserInputService = require("../Services").UserInputService
local GuiService = require("../Services").GuiService
local isLuwow = require("../isLuwow")

local ConsoleToEnginePlatformEnum = if isLuwow
	then {}
	else {
		[Platform.PS4] = Enum.Platform.PS4,
		[Platform.PS5] = Enum.Platform.PS5,
		[Platform.Xbox] = Enum.Platform.XBoxOne,
	}

local function getPlatform(): Enum.Platform?
	if isLuwow then
		return nil
	end

	local success, platform = pcall(UserInputService.GetPlatform, UserInputService)

	if success then
		return platform
	end

	-- fallback (only supports console)
	local isConsole = GuiService:IsTenFootInterface()
	local inputPlatform = getInputPlatform()

	return if isConsole then ConsoleToEnginePlatformEnum[inputPlatform] else nil
end

local function getBuilderIconForCurrentPlatform(): string?
	local platform = getPlatform()

	return PlatformIconMap[platform]
end

return getBuilderIconForCurrentPlatform
