const fs = require("@Luwow/fs")

const Json = require("@Backend/tools/Json")
const Paths = require("@Backend/tools/Paths")

const FVariable = require("@Backend/classes/FVariable")

const STATE_FILE = "state.json"

const DEFAULT_VERSION_DATA = {
	Version = "",
	VersionGuid = "",
	VersionOverload = "",
	LastFlagScanVersion = "",
	LastExecutedVersion = "",
	OverrideChannel = "",
	OverrideToken = "",
	LatestGuid_x64 = "",
	LatestGuid_x86 = ""
}

const DEFAULT_CHANNEL_DATA = {
	ChannelName = "LIVE",
	ChannelToken = ""
}

local Manager = {
	Loaded = false,
	-- The decoded state
	State = nil :: State?
}

--// Types

type FVariable = FVariable.FVariable

export type VersionManifest = typeof(DEFAULT_VERSION_DATA)
export type ChannelManifest = typeof(DEFAULT_CHANNEL_DATA)

export type State = {
	TargetVersion: string,
	DisableFlagWarning: boolean,
	VersionData: VersionManifest,
	ChannelData: ChannelManifest,
	FileManifest: { [string]: string },
	-- Flag key -> its override
	FlagEditor: { [string]: FVariable },
	PackageManifest: { [string]: any },
	[string]: any,
}

--// Local Functions

local function statePath(): string
	return Paths.join(Paths.getRootDirectory(), STATE_FILE)
end

-- Fills in the fields a section is missing
local function withDefaults(section: any, defaults: { [string]: any }): { [string]: any }
	local filled = if type(section) == "table" then section else Json.object()
	for key, value in defaults do
		if filled[key] == nil then
			filled[key] = value
		end
	end
	return filled
end

-- The decoded file, with ModManagerState's defaults for what it doesn't have
local function normalize(decoded: any): State
	local state = if type(decoded) == "table" then decoded else Json.object()

	if type(state.TargetVersion) ~= "string" then
		state.TargetVersion = ""
	end
	if type(state.DisableFlagWarning) ~= "boolean" then
		state.DisableFlagWarning = false
	end
	state.VersionData = withDefaults(state.VersionData, DEFAULT_VERSION_DATA)
	state.ChannelData = withDefaults(state.ChannelData, DEFAULT_CHANNEL_DATA)
	state.FileManifest = withDefaults(state.FileManifest, {})
	state.PackageManifest = withDefaults(state.PackageManifest, {})

	local flags = {}
	for key, saved in withDefaults(state.FlagEditor, {}) do
		flags[key] = FVariable.fromSaved(saved)
	end
	state.FlagEditor = flags

	return state
end

--// Module Functions

function Manager.load(): State
	local path = statePath()
	local decoded = nil

	if fs.exists(path) then
		local text = fs.readFile(path)
		if text ~= "" then
			local ok, result = pcall(Json.decode, text)
			if ok then
				decoded = result
			else
				print(`[StateManager] Couldn't read {path}: {result}`)
			end
		end
	end

	-- TODO: The legacy registry state isn't converted, like App.ConvertLegacy does
	Manager.State = normalize(decoded)
	Manager.Loaded = true
	return Manager.State :: State
end

function Manager.get(): State
	return Manager.State or Manager.load()
end

function Manager.save()
	local state = Manager.State
	if not state then
		return
	end

	local saved = table.clone(state)
	local flags = Json.object()
	for key, flag in state.FlagEditor do
		flags[key] = flag:ToSaved()
	end
	saved.FlagEditor = flags

	local text = Json.encode(setmetatable(saved, Json.OBJECT), "  ")
	fs.writeFile(statePath(), (string.gsub(text, "\n", "\r\n")))
end

return Manager
