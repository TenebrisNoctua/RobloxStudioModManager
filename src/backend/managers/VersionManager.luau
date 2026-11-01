const process = require("@Luwow/process")

const Http = require("@Backend/tools/Http")

const ClientVersionInfo = require("@Backend/classes/ClientVersionInfo")
const StudioDeployLogs = require("@Backend/classes/StudioDeployLogs")
const StateManager = require("@Backend/managers/StateManager")

const REPO_OWNER = "MaximumADHD"
const REPO_NAME = "Roblox-Studio-Mod-Manager"
const REPO_BRANCH = "main"

local Manager = {
	ReleaseTag = "v2026.11.01",
	BaseConfigUrl = `https://raw.githubusercontent.com/{REPO_OWNER}/{REPO_NAME}/{REPO_BRANCH}/Config/`,
	AllowUnsupportedVersions = false
}

--// Types

export type DeployVersion = {
	Id: string,
	Text: string,
	Unsupported: boolean,
}

export type VersionHistory = {
	Versions: { DeployVersion },
	TargetVersion: string,
	AllowTargetSelection: boolean,
	ChannelValid: boolean
}

--// Local Functions

-- The logs newest first, as the Target Version box lists them
local function sortedVersions(logs: { any }): { DeployVersion }
	local ordered = table.clone(logs)
	table.sort(ordered, function(a, b)
		return a.CommitId > b.CommitId
	end)

	local versions = {}
	for _, log in ordered do
		table.insert(versions, {
			Id = log.VersionId,
			Text = tostring(log),
			Unsupported = log.Unsupported
		})
	end
	return versions
end

--// Module Functions

function Manager.fetchVersionHistory(channelName: string, channelToken: string): VersionHistory
	local state = StateManager.get()
	local deployLogs = StudioDeployLogs.get(Manager.AllowUnsupportedVersions, channelName, channelToken)

	local isDefaultChannel = deployLogs.ChannelName == "LIVE" or deployLogs.ChannelName == "zbeta"
	local channelValid = deployLogs.ChannelName == channelName or deployLogs.ChannelName == "zbeta"

	if channelValid then
		if channelName ~= "" then
			state.ChannelData.ChannelName = channelName
		end
		if channelToken ~= "" then
			state.ChannelData.ChannelToken = channelToken
		end
	else
		state.ChannelData.ChannelName = "LIVE"
		state.ChannelData.ChannelToken = ""
	end

	return {
		Versions = if deployLogs:HasHistory() then sortedVersions(deployLogs.CurrentLogs) else {},
		TargetVersion = state.TargetVersion,
		AllowTargetSelection = deployLogs:HasHistory() and isDefaultChannel,
		ChannelValid = channelValid
	}
end

function Manager.setTargetVersion(versionId: string)
	StateManager.get().TargetVersion = versionId
end

--[[
	The newest version of the saved channel.
	Returns its guid.
]]
function Manager.getCurrentVersion(): string
	local state = StateManager.get()
	local channelData = state.ChannelData
	local logData = StudioDeployLogs.get(Manager.AllowUnsupportedVersions, channelData.ChannelName, channelData.ChannelToken)

	local build = logData:Latest()
	if not build then return "" end

	state.VersionData.LatestGuid_x64 = build.VersionGuid
	return build.VersionGuid
end

--[[
	The target version's info, "" for the newest version of the saved channel.
]]
function Manager.getVersionInfo(targetVersion: string): ClientVersionInfo.ClientVersionInfo
	if targetVersion ~= "" then
		local logData = StudioDeployLogs.get()
		for _, log in logData.CurrentLogs do
			if log.VersionId ~= targetVersion then continue end
			return ClientVersionInfo.fromLog(log)
		end
	end

	local state = StateManager.get()
	local channelData = state.ChannelData
	local logData = StudioDeployLogs.get(Manager.AllowUnsupportedVersions, channelData.ChannelName, channelData.ChannelToken)

	local build = logData:Latest()
	if not build then
		error("Could not find a version of Roblox Studio to install", 0)
	end

	state.VersionData.LatestGuid_x64 = build.VersionGuid
	return ClientVersionInfo.fromLog(build)
end

function Manager.openReleasePage(releaseTag: string)
	process.open(`https://www.github.com/{REPO_OWNER}/{REPO_NAME}/releases/tag/{releaseTag}`)
end

function Manager.getInstalledVersion(): string
	return StateManager.get().VersionData.VersionGuid
end

-- The mod manager's latest release tag, nil when it can't be fetched
function Manager.fetchLatestReleaseTag(): string?
	-- fix later if I add my own release tag system lol
	--local ok, releaseTag = pcall(Http.get, Manager.BaseConfigUrl .. "LatestReleaseTag.txt")
	--if not ok then return nil end
	--return string.match(releaseTag, "^%s*(.-)%s*$")
	return Manager.ReleaseTag
end

function Manager.returnCallbacks()
	return {
		App = {
			GetReleaseTag = function(): string
				return Manager.ReleaseTag
			end
		},
		Main = {
			FetchLatestReleaseTag = Manager.fetchLatestReleaseTag,
			OpenReleasePage = Manager.openReleasePage,
			FetchVersionHistory = Manager.fetchVersionHistory,
			SetTargetVersion = Manager.setTargetVersion,
			GetCurrentVersion = Manager.getCurrentVersion
		},
		Bootstrap = {
			GetInstalledVersion = Manager.getInstalledVersion
		}
	}
end

return Manager
