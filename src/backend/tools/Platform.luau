const os = require("@Luwow/os")

local Platform = {
	-- Stands in for the system the program runs on.
	Override = nil :: ("windows" | "macos")?
}

--// Module Functions

function Platform.isMac(): boolean
	return (Platform.Override or os.platform()) == "macos"
end

--[[
	The build the client settings API reports versions of. 
	MacOS has one Studio build per version, Windows
	has WindowsStudio64.
]]
function Platform.getStudioBinaryType(): string
	return if Platform.isMac() then "MacStudio" else "WindowsStudio64"
end

-- The name Studio's process runs under
function Platform.getStudioProcessName(): string
	return if Platform.isMac() then "RobloxStudio" else "RobloxStudioBeta"
end

-- The client settings application the flag editor reads values from
function Platform.getClientSettingsApplication(): string
	return if Platform.isMac() then "MacDesktopClient" else "PCDesktopClient"
end

--[[
	Where a Mac Studio version's zip is on the CDN, under setup.rbxcdn.com.
]]
function Platform.getMacDownloadFolder(): string
	return if os.arch() == "arm64" then "mac/arm64" else "mac"
end

-- Whether the deploy history names the versions' guids, so an older version can be picked. The Mac one hides them.
function Platform.hasVersionHistory(): boolean
	return not Platform.isMac()
end

return Platform
