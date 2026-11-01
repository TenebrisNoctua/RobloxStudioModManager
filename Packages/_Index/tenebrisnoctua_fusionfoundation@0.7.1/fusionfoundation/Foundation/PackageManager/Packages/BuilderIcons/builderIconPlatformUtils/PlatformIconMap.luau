local BuilderIcons = require("../Icon")
local isLuwow = require("../isLuwow")

local EnginePlatform = if isLuwow
	then {
		PS3 = "PS3",
		PS4 = "PS4",
		PS5 = "PS5",
		XBoxOne = "XBoxOne",
		XBox360 = "XBox360",
		Android = "Android",
		IOS = "IOS",
		OSX = "OSX",
		Windows = "Windows",
		MetaOS = "MetaOS",
	} :: any
	else Enum.Platform

local PlatformIconMap = {
	[EnginePlatform.PS3] = BuilderIcons.Playstation,
	[EnginePlatform.PS4] = BuilderIcons.Playstation,
	[EnginePlatform.PS5] = BuilderIcons.Playstation,
	[EnginePlatform.XBoxOne] = BuilderIcons.Xbox,
	[EnginePlatform.XBox360] = BuilderIcons.Xbox,
	[EnginePlatform.Android] = BuilderIcons.Android,
	[EnginePlatform.IOS] = BuilderIcons.Apple,
	[EnginePlatform.OSX] = BuilderIcons.Apple,
	[EnginePlatform.Windows] = BuilderIcons.Microsoft,
	[EnginePlatform.MetaOS] = BuilderIcons.Meta,
}

return PlatformIconMap
