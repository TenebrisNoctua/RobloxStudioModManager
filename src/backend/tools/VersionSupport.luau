const Base64 = require("@Backend/tools/Base64")
const Http = require("@Backend/tools/Http")
const Json = require("@Backend/tools/Json")

const URL = "https://raw.githubusercontent.com/MaximumADHD/Roblox-FFlag-Tracker/refs/heads/main/FVariables/FString/S/FStringStudioEmergencyMessageV4.json"

local VersionSupport = {}

--// Types

-- The minor versions Studio no longer supports, 0 to 0 when it couldn't be loaded
export type UnsupportedRange = {
	Min: number,
	Max: number
}

--// Local Functions

-- The PCStudioApp LIVE value, however the flag's tracker splits it
local function findBlob(data: { [string]: any }): string?
	local value = data.Value
	local metadataType = data.Type

	if metadataType == "Unified" then
		return value
	elseif metadataType == "Channels" then
		return value and value.LIVE
	elseif metadataType == "Platforms" then
		return value and value.PCStudioApp
	elseif metadataType == "ChannelsAndPlatforms" then
		return value and value.LIVE and value.LIVE.PCStudioApp
	end
	return nil
end

local function minorVersion(version: string): number
	return tonumber(string.match(version, "^%d+%.(%d+)")) or error(`bad version {version}`, 0)
end

--// Module Functions

function VersionSupport.getUnsupportedRange(): UnsupportedRange
	local range = { Min = 0, Max = 0 }

	local ok, err = pcall(function()
		local data = Json.decode(Http.get(URL))
		local blob = findBlob(data)
		if not blob or blob == "" then
			return
		end

		local support = Json.decode(Base64.decode(blob))
		range.Min = minorVersion(support.versionStart)
		range.Max = minorVersion(support.versionEnd)
	end)

	if not ok then
		-- TODO: Handle this more explicitly?
		print(`Could not load version support data: {err}`)
	end
	return range
end

return VersionSupport
