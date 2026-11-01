const ClientVersionInfo = require("@Backend/classes/ClientVersionInfo")
const DeployLog = require("@Backend/classes/DeployLog")
     
const HistoryCache = require("@Backend/tools/HistoryCache")
const Platform = require("@Backend/tools/Platform")
const VersionSupport = require("@Backend/tools/VersionSupport")

local StudioDeployLogs = {}
StudioDeployLogs.__index = StudioDeployLogs

-- One set of logs for each allowUnsupported, updated as the history or the latest version changes
local logCache: { [boolean]: StudioDeployLogs } = {}

--// Types

type DeployLog = DeployLog.DeployLog
type ClientVersionInfo = ClientVersionInfo.ClientVersionInfo

export type StudioDeployLogs = setmetatable<
	{
		LastDeployHistory: string,
		LastVersionGuid: string,
		ChannelName: string,
		AllowUnsupported: boolean,
		-- In the history's order, the latest version last when it isn't in the history yet
		CurrentLogs: { DeployLog },
	},
	typeof(StudioDeployLogs)
>

--// Local Functions

-- The history's version ids and guids, in the order the JSON lists them
local function readHistory(jsonHistory: string): { { string } }
	local entries = {}
	for versionId, versionGuid in string.gmatch(jsonHistory, '"([%d%.]+)"%s*:%s*"([^"]*)"') do
		table.insert(entries, { versionId, versionGuid :: string })
	end
	return entries
end

-- The given channel's latest version, falling back to LIVE when the channel or token can't be used.
-- zbeta wins when it's up.
local function getLatest(channelName: string, channelToken: string): ClientVersionInfo
	local ok, latest = pcall(ClientVersionInfo.get, channelName, Platform.getStudioBinaryType(), channelToken)
	if not ok then
		-- Invalid channel or token, fallback to LIVE
		latest = ClientVersionInfo.get("LIVE", Platform.getStudioBinaryType())
	end

	local betaOk, latestBeta = pcall(ClientVersionInfo.get, "zbeta")
	if betaOk and latestBeta:Success() then
		latest = latestBeta
	end

	return latest
end

-- Rebuilds the logs from the history, without the unsupported versions unless they're allowed
local function rebuild(logs: StudioDeployLogs, jsonHistory: string, latest: ClientVersionInfo)
	local unsupported = VersionSupport.getUnsupportedRange()
	table.clear(logs.CurrentLogs)

	logs.LastDeployHistory = jsonHistory
	logs.LastVersionGuid = latest.VersionGuid

	for _, entry in readHistory(jsonHistory) do
		local log = DeployLog.fromVersionId(entry[1], entry[2])
		if not log then
			continue
		end
		if not logs.AllowUnsupported and log.Version >= unsupported.Min and log.Version <= unsupported.Max then
			continue
		end
		table.insert(logs.CurrentLogs, log)
	end

	local foundInLogs = false
	for _, log in logs.CurrentLogs do
		if log.VersionGuid == latest.VersionGuid then
			foundInLogs = true
			break
		end
	end

	if not foundInLogs then
		local latestLog = DeployLog.fromVersionId(latest.Version, latest.VersionGuid)
		if latestLog then
			table.insert(logs.CurrentLogs, latestLog)
		end
	end
end

--// Module Functions

--[[
	Studio's deploy logs and the channel they were fetched for. Yields while
	it downloads.
]]
function StudioDeployLogs.get(allowUnsupported: boolean?, channelName: string?, channelToken: string?): StudioDeployLogs
	local allow = allowUnsupported == true
	local logs = logCache[allow]
	if not logs then
		logs = setmetatable({
			LastDeployHistory = "",
			LastVersionGuid = "",
			ChannelName = "",
			AllowUnsupported = allow,
			CurrentLogs = {},
		}, StudioDeployLogs)
		logCache[allow] = logs
	end

	local latest = getLatest(channelName or "LIVE", channelToken or "")
	logs.ChannelName = latest.ChannelName

	-- If a platform has no version history (such as Mac), it uses the latest version available.
	local jsonHistory = if Platform.hasVersionHistory() then HistoryCache.get() else ""
	if logs.LastDeployHistory ~= jsonHistory or latest.VersionGuid ~= logs.LastVersionGuid then
		rebuild(logs, jsonHistory, latest)
	end

	return logs
end

function StudioDeployLogs.HasHistory(self: StudioDeployLogs): boolean
	return #self.CurrentLogs > 0
end

function StudioDeployLogs.Latest(self: StudioDeployLogs): DeployLog?
	return self.CurrentLogs[#self.CurrentLogs]
end

return StudioDeployLogs
