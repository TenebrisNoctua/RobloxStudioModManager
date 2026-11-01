const fs = require("@Luwow/fs")
const os = require("@Luwow/os")

const Platform = require("@Backend/tools/Platform")

const MOD_FOLDERS = {
	"BuiltInPlugins",
	"ClientSettings",
	"content/avatar",
	"content/fonts",
	"content/models",
	"content/scripts",
	"content/sky",
	"content/sounds",
	"content/textures",
	"content/translations"
}

const MAC_STUDIO_APP = "RobloxStudio.app"

local Paths = {
	-- Overrides for the folders below, such as for tests.
	RootOverride = nil :: string?,
	-- Studio's folder on Windows. Its RobloxStudio.app on MacOS.
	StudioOverride = nil :: string?,
	-- Roblox's own folder.
	RobloxOverride = nil :: string?
}

--// Local Functions

-- %LocalAppData%, with forward slashes
local function localAppData(): string
	local folder = os.getEnv("LOCALAPPDATA")
	if not folder or folder == "" then
		error("LOCALAPPDATA isn't set", 0)
	end
	return (string.gsub(folder, "\\", "/"))
end

-- ~/Library/Application Support, MacOS's place for an app's own files
local function applicationSupport(): string
	return os.homeDirectory() .. "/Library/Application Support"
end

local function ensureFolder(path: string): string
	if not fs.exists(path) then
		fs.mkdir(path, true)
	end
	return path
end

local function startsWith(text: string, prefix: string): boolean
	return string.sub(text, 1, #prefix) == prefix
end

--// Module Functions

function Paths.join(...: string): string
	return table.concat({ ... }, "/")
end

function Paths.getRootDirectory(): string
	if Paths.RootOverride then
		return ensureFolder(Paths.RootOverride)
	end
	local base = if Platform.isMac() then applicationSupport() else localAppData()
	return ensureFolder(Paths.join(base, "Roblox Studio Mod Manager"))
end

--[[
	The folder Studio is installed in on Windows. 
	On MacOS it's Studio's app, kept with the mod manager's files
	rather than in Applications, and made by installing it.
]]
function Paths.getStudioDirectory(): string
	if Platform.isMac() then
		return Paths.StudioOverride or Paths.join(Paths.getRootDirectory(), MAC_STUDIO_APP)
	end
	return ensureFolder(Paths.StudioOverride or Paths.join(localAppData(), "Roblox Studio"))
end

function Paths.getStudioPath(): string
	if Platform.isMac() then
		return Paths.join(Paths.getStudioDirectory(), "Contents", "MacOS", "RobloxStudio")
	end
	return Paths.join(Paths.getStudioDirectory(), "RobloxStudioBeta.exe")
end

function Paths.isStudioInstalled(): boolean
	return fs.exists(Paths.getStudioPath())
end

function Paths.getStudioContentDirectory(): string
	if Platform.isMac() then
		return Paths.join(Paths.getStudioDirectory(), "Contents", "Resources")
	end
	return Paths.getStudioDirectory()
end

function Paths.getStudioClientSettingsDirectory(): string
	return ensureFolder(Paths.join(Paths.getStudioDirectory(), "ClientSettings"))
end

function Paths.getDownloadsDirectory(): string
	if Platform.isMac() then
		return ensureFolder(Paths.join(Paths.getRootDirectory(), "downloads"))
	end
	return ensureFolder(Paths.join(Paths.getStudioDirectory(), "downloads"))
end

--[[
	Roblox's ClientSettings folder, where Studio reads ClientAppSettings.json
	from: %LocalAppData%/Roblox/ClientSettings on Windows,
	~/Library/Roblox/ClientSettings on macOS. Made when it doesn't exist yet.
]]
function Paths.getClientSettingsDirectory(): string
	local roblox = Paths.RobloxOverride
		or if Platform.isMac() then Paths.join(os.homeDirectory(), "Library", "Roblox") else Paths.join(localAppData(), "Roblox")
	return ensureFolder(Paths.join(roblox, "ClientSettings"))
end

function Paths.getModDirectory(): string
	local root = Paths.join(Paths.getRootDirectory(), "ModFiles")
	if not fs.exists(root) then
		fs.mkdir(root, true)
		for _, folder in MOD_FOLDERS do
			fs.mkdir(Paths.join(root, folder), true)
		end
	end
	return root
end

--[[
	Where a mod file goes, from its path in the mod folder such as
	"content/sky/x.png". On Windows that's the same path in Studio's folder;
	on MacOS the ClientSettings go to Roblox's own folder and the rest into
	the app's Resources.
]]
function Paths.getModTarget(relativePath: string): string
	local path = string.gsub(relativePath, "\\", "/")
	if Platform.isMac() then
		if startsWith(path, "ClientSettings/") then
			return Paths.join(Paths.getClientSettingsDirectory(), string.sub(path, #"ClientSettings/" + 1))
		end
		return Paths.join(Paths.getStudioContentDirectory(), path)
	end
	return Paths.join(Paths.getStudioDirectory(), path)
end

return Paths
