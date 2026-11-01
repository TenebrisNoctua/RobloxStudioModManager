const fs = require("@Luwow/fs")
const os = require("@Luwow/os")

const Http = require("@Backend/tools/Http")
const Json = require("@Backend/tools/Json")
const Paths = require("@Backend/tools/Paths")
const Platform = require("@Backend/tools/Platform")
const StudioFFlagDumper = require("@Backend/tools/StudioFFlagDumper")
const Yield = require("@Backend/tools/Yield")

const FVariable = require("@Backend/classes/FVariable")
const StateManager = require("@Backend/managers/StateManager")

const CLIENT_SETTINGS_URL = "https://clientsettingscdn.roblox.com/v2/settings/application/"

const FLAG_TYPES = {
	{ "Flag", "false" },
	{ "Int", "0" },
	{ "String", " " },
	{ "Log", "0" }
}

const FLAG_CLASSES = { "SF", "DF", "F" }

local Manager = {
	-- Every flag, sorted by key, once the editor loaded them
	AllFlags = {} :: { FVariable },
	-- The flags matching the search, sorted by name
	Flags = {} :: { FVariable },
	-- Key -> its override, the flags shown in Overrides
	OverrideLookup = {} :: { [string]: FVariable },
	-- The overrides sorted by name
	Overrides = {} :: { FVariable },
	-- The last custom flag made, until it's overridden
	LastCustomFlag = nil :: FVariable?
}

--// Types

type FVariable = FVariable.FVariable

export type FlagData = {
	Key: string,
	Name: string,
	Type: string,
	Value: string,
	Overridden: boolean
}

--// Local Functions

local function flagRegistry(): { [string]: FVariable }
	return StateManager.get().FlagEditor
end

local function versionRegistry()
	return StateManager.get().VersionData
end

local function startsWith(text: string, prefix: string): boolean
	return string.sub(text, 1, #prefix) == prefix
end

local function endsWith(text: string, suffix: string): boolean
	return #text >= #suffix and string.sub(text, -#suffix) == suffix
end

-- By name, then by key so flags of one name keep their order
local function byName(a: FVariable, b: FVariable): boolean
	if a.Name ~= b.Name then
		return a.Name < b.Name
	end
	return a.Key < b.Key
end

-- A flag's default value from its key's class and type, "??" without a class, nil without a type
local function defaultValue(key: string): string?
	local flagClass = ""
	for _, candidate in FLAG_CLASSES do
		if startsWith(key, candidate) then
			flagClass = candidate
			break
		end
	end

	if flagClass == "" then
		return "??"
	end

	local prefix = string.sub(key, #flagClass + 1)
	for _, flagType in FLAG_TYPES do
		if startsWith(prefix, flagType[1]) then
			return flagType[2]
		end
	end
	return nil
end

local function isNumber(value: string): boolean
	local digits = string.match(value, "^%s*([+-]?%d+)%s*$")
	local number = digits and tonumber(digits)
	return number ~= nil and number >= -2 ^ 31 and number <= 2 ^ 31 - 1
end

local function toFlagData(flag: FVariable): FlagData
	return {
		Key = flag.Key,
		Name = flag.Name,
		Type = flag.Type,
		Value = flag.Value,
		Overridden = flagRegistry()[flag.Key] ~= nil
	}
end

--[[
	The names of the flags Studio has. On Windows, the dumper reads
	the Windows executable, on MacOS, the client settings are used.
]]
local function loadFlagNames(): { [string]: boolean }
	local flagNames = {}
	if Platform.isMac() then return flagNames end
	
	local studioDir = Paths.getStudioDirectory()
	local flagDump = Paths.join(studioDir, "FFlags.json")

	local versionData = versionRegistry()
	local lastFlagScanVersion = versionData.LastFlagScanVersion
	local versionGuid = versionData.VersionGuid

	if lastFlagScanVersion ~= versionGuid or not fs.exists(flagDump) then
		local cppFlags = StudioFFlagDumper.DumpCppFlags(Paths.getStudioPath())
		for _, flag in cppFlags do
			flagNames[flag] = true
		end

		fs.writeFile(flagDump, Json.encode(Json.array(cppFlags)))

		versionData.LastFlagScanVersion = versionGuid
		StateManager.save()
		
		-- The executable was read whole to find the names
		os.releaseMemory()
		return flagNames
	end

	for _, name in Json.decode(fs.readFile(flagDump)) do
		flagNames[name] = true
	end
	return flagNames
end

-- The client's flags and their values, without the place filters
local function fetchClientSettings(): { [string]: string }
	local json = {}
	local data = Json.decode(Http.get(CLIENT_SETTINGS_URL .. Platform.getClientSettingsApplication()))

	for key, value in data.applicationSettings or {} do
		if not endsWith(key, "_PlaceFilter") then
			json[key] = tostring(value)
		end
	end
	return json
end

-- addFlagOverride: a boolean flag is flipped the first time it's overridden, unless it's being loaded
local function addFlagOverride(flag: FVariable, init: boolean?)
	local key = flag.Key

	if not Manager.OverrideLookup[key] then
		if not init and flag:IsType("Flag") then
			local value = string.lower(flag.Value)
			if value == "true" or value == "false" then
				flag:SetValue(if value == "true" then "false" else "true")
			end
		end

		Manager.OverrideLookup[key] = flag
	end

	if not init then
		Manager.LastCustomFlag = nil
		flagRegistry()[key] = flag
	end
end

--// Module Functions

--[[
	The flags Studio has, with the values the client
	settings give them, and the saved overrides. Returns how many flags there
	are. Downloads, and dumps Studio's flags after an update, yielding meanwhile.
]]
function Manager.fetchAllFlags(): number
	local registry = flagRegistry()
	local flagNames = loadFlagNames()

	-- Initialize flag browser
	local json = fetchClientSettings()

	for key in flagNames do
		Yield.ifNeeded()
		if json[key] == nil then
			local value = defaultValue(key)
			if value then
				json[key] = value
			end
		end
	end

	local flagSetup = {}

	for customFlag in flagNames do
		if json[customFlag] == nil then
			local flag = registry[customFlag]
			if flag and flag.Custom then
				table.insert(flagSetup, flag)
			end
		end
	end

	for key, value in json do
		Yield.ifNeeded()
		local flag = registry[key] or FVariable.new(key, value)
		if flag.Type ~= "" then
			table.insert(flagSetup, flag)
		end
	end

	table.sort(flagSetup, function(a, b)
		return a.Key < b.Key
	end)
	Manager.AllFlags = flagSetup

	-- Initialize override list
	table.clear(Manager.OverrideLookup)
	for _, flag in registry do
		addFlagOverride(flag, true)
	end

	Manager.searchFlags("")

	-- The downloaded settings and the dump's names are garbage now, so release their memory.
	os.releaseMemory()
	return #Manager.AllFlags
end

function Manager.searchFlags(search: string): number
	local matches = {}
	for _, flag in Manager.AllFlags do
		if search == "" or string.find(string.lower(flag.Name), search, 1, true) then
			table.insert(matches, flag)
		end
	end
	table.sort(matches, byName)

	Manager.Flags = matches
	return #matches
end

function Manager.getFlag(index: number): FlagData?
	local flag = Manager.Flags[index]
	return if flag then toFlagData(flag) else nil
end

function Manager.fetchOverrides(): number
	local sorted = {}
	for _, flag in Manager.OverrideLookup do
		table.insert(sorted, flag)
	end
	table.sort(sorted, byName)

	Manager.Overrides = sorted
	return #sorted
end

function Manager.getOverride(index: number): FlagData?
	local flag = Manager.Overrides[index]
	return if flag then toFlagData(flag) else nil
end

function Manager.overrideFlag(key: string)
	for _, flag in Manager.Flags do
		if flag.Key == key then
			addFlagOverride(flag)
			return
		end
	end
end

function Manager.removeOverride(key: string)
	local flag = Manager.OverrideLookup[key]
	if not flag then
		return
	end

	flag:Clear()
	Manager.OverrideLookup[key] = nil
	flagRegistry()[key] = nil
end

function Manager.removeAllOverrides()
	local registry = flagRegistry()
	for key, flag in registry do
		flag:Clear()
		registry[key] = nil
	end
	table.clear(Manager.OverrideLookup)
end

function Manager.setOverrideValue(key: string, value: string): string
	local flag = Manager.OverrideLookup[key]
	if not flag then
		return value
	end

	if flag:IsType("Int") and not isNumber(value) then
		return flag.Reset
	end

	flag:SetValue(value)
	return value
end

function Manager.addCustomFlag(flagType: string, name: string)
	local flagValue = ""
	for _, entry in FLAG_TYPES do
		if endsWith(flagType, entry[1]) then
			flagValue = entry[2]
			break
		end
	end

	local flagName = flagType .. name
	local newFlag = FVariable.new(flagName, flagValue, true)

	flagRegistry()[flagName] = newFlag
	Manager.LastCustomFlag = newFlag

	addFlagOverride(newFlag)
end

--[[
	Writes the overrides as ClientAppSettings.json,
	into Roblox's ClientSettings folder, where Studio reads it now, and on
	Windows into Studio's own as well. On MacOS Studio's app is left as it is.
]]
function Manager.applyFlags()
	local json = Json.object()
	for flagName, flag in flagRegistry() do
		json[flagName] = flag.Value
	end

	local file = string.gsub(Json.encode(json, "  "), "\n", "\r\n")
	if not Platform.isMac() then
		fs.writeFile(Paths.join(Paths.getStudioClientSettingsDirectory(), "ClientAppSettings.json"), file)
	end
	fs.writeFile(Paths.join(Paths.getClientSettingsDirectory(), "ClientAppSettings.json"), file)
end

function Manager.closed()
	StateManager.save()
end

-- The callbacks the frontend uses
function Manager.returnCallbacks()
	return {
		FlagEditor = {
			FetchAllFlags = Manager.fetchAllFlags,
			SearchFlags = Manager.searchFlags,
			GetFlag = Manager.getFlag,
			FetchOverrides = Manager.fetchOverrides,
			GetOverride = Manager.getOverride,
			OverrideFlag = Manager.overrideFlag,
			RemoveOverride = Manager.removeOverride,
			RemoveAllOverrides = Manager.removeAllOverrides,
			SetOverrideValue = Manager.setOverrideValue,
			AddCustomFlag = Manager.addCustomFlag,
			Closed = Manager.closed
		}
	}
end

return Manager
