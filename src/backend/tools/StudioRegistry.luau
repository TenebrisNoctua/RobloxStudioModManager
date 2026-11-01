const os = require("@Luwow/os")
const process = require("@Luwow/process")

const CLASSES_KEY = "HKCU/SOFTWARE/Classes"

local StudioRegistry = {
	-- Where the classes below are registered, such as a scratch key for tests
	ClassesOverride = nil :: string?
}

--// Local Functions

local function absolutePath(path: string): string
	local normalized = string.gsub(path, "\\", "/")
	if string.match(normalized, "^%a:/") or string.sub(normalized, 1, 2) == "//" then
		return normalized
	end
	return process.cwd() .. "/" .. normalized
end

local function quoted(path: string): string
	return '"' .. string.gsub(string.gsub(path, '"', ""), "/", "\\") .. '"'
end

--// Module Functions

--[[
	The executable, then the arguments it takes itself: runscript's script and
	config, or runpackage's package. They're what comes before process.args in
	process.commandLine. Returns the command and the executable, for the icon.
]]
function StudioRegistry.getLaunchCommand(): (string, string)
	local commandLine = process.commandLine()
	local executable = process.executablePath()
	local command = quoted(executable)

	for index = 1, #commandLine - #process.args() do
		command ..= " " .. quoted(absolutePath(commandLine[index]))
	end
	return command, (string.gsub(executable, "/", "\\"))
end

--[[
	This function does the following:
		   
	1: The File Protocol to open .rbxl/.rbxlx files through the mod manager.

	2: The URI Protocol to open places from the website through the mod manager.
	
	3: The URI Protocol to route OAuth2 login requests to where we write RobloxStudioBeta.exe
]]
function StudioRegistry.updateProtocols(studioPath: string)
	local classes = StudioRegistry.ClassesOverride or CLASSES_KEY
	local modManager, modManagerExe = StudioRegistry.getLaunchCommand()
	local studio = string.gsub(studioPath, "/", "\\")

	local function key(...: string): string
		return table.concat({ classes, ... }, "/")
	end

	-- Register the base "Roblox.Place" open protocol.
	os.setRegistryValue(key("Roblox.Place"), nil, "Roblox Place")
	os.setRegistryValue(key("Roblox.Place", "shell", "open", "command"), nil, `{modManager} -task EditFile -localPlaceFile "%1"`)

	-- Pass the .rbxl and .rbxlx file formats to Roblox.Place
	for _, extension in { ".rbxl", ".rbxlx" } do
		os.setRegistryValue(key(extension), nil, "Roblox.Place")
		os.createRegistryKey(key(extension, "Roblox.Place", "ShellNew"))
	end

	-- Setup the URI protocol for opening the mod manager through the website.
	os.setRegistryValue(key("roblox-studio"), nil, "URL: Roblox Protocol")
	os.setRegistryValue(key("roblox-studio"), "URL Protocol", "")
	os.setRegistryValue(key("roblox-studio", "shell", "open", "command"), nil, `{modManager} %1`)

	-- Setup authentication route.
	os.setRegistryValue(key("roblox-studio-auth"), nil, "URL: Roblox Protocol")
	os.setRegistryValue(key("roblox-studio-auth"), "URL Protocol", "")
	os.setRegistryValue(key("roblox-studio-auth", "shell", "open", "command"), nil, `"{studio}" %1`)

	-- Set the default icon for all protocols.
	for _, app in { "Roblox.Place", "roblox-studio", "roblox-studio-auth" } do
		os.setRegistryValue(key(app, "DefaultIcon"), nil, `{modManagerExe},0`)
	end
end

return StudioRegistry
