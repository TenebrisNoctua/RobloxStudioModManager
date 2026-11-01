const Http = require("@Backend/tools/Http")
const Json = require("@Backend/tools/Json")
const Platform = require("@Backend/tools/Platform")

-- TODO: Change to class ClientVersionInfo when/if native classes are out
local ClientVersionInfo = {}
ClientVersionInfo.__index = ClientVersionInfo

--// Types

export type ClientVersionHttpError = {
	Code: number,
	Message: string
}

export type ClientVersionInfo = setmetatable<
	{
		Version: string,
		VersionGuid: string,
		ChannelName: string,
		Errors: { ClientVersionHttpError },
	},
	typeof(ClientVersionInfo)
>

--// Module Functions

function ClientVersionInfo.new(version: string, versionGuid: string, channelName: string?): ClientVersionInfo
	return setmetatable({
		Version = version,
		VersionGuid = versionGuid,
		ChannelName = channelName or "",
		Errors = {},
	}, ClientVersionInfo)
end

-- The info of a deploy log
function ClientVersionInfo.fromLog(log: { VersionId: string, VersionGuid: string }): ClientVersionInfo
	return ClientVersionInfo.new(log.VersionId, log.VersionGuid)
end

--[[
	The channel's current version, from the client settings API. Raises when
	the request fails, such as for an unknown channel or a bad token.
]]
function ClientVersionInfo.get(channel: string?, binaryType: string?, channelToken: string?): ClientVersionInfo
	local channelName = channel or "LIVE"
	local headers = {}
	if channelToken and channelToken ~= "" then
		headers["roblox-channel-token"] = channelToken
	end

	local url = `https://clientsettings.roblox.com/v2/client-version/{binaryType or Platform.getStudioBinaryType()}`
	if string.lower(channelName) ~= "live" then
		url ..= `/channel/{channelName}`
	end

	local response = Json.decode(Http.get(url, headers))
	local info = ClientVersionInfo.new(response.version or "", response.clientVersionUpload or "", channelName)

	for _, httpError in response.errors or {} do
		table.insert(info.Errors, { Code = httpError.code or 0, Message = httpError.message or "" })
	end
	return info
end

function ClientVersionInfo.Success(self: ClientVersionInfo): boolean
	return #self.Errors == 0
end

return ClientVersionInfo
