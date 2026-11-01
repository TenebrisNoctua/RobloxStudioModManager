local DeployLog = {}
DeployLog.__index = DeployLog

--// Types

export type DeployLog = setmetatable<
	{
		VersionGuid: string,
		MajorRev: number,
		Version: number,
		Patch: number,
		CommitId: number,
		VersionId: string,
		Unsupported: boolean
	},
	typeof(DeployLog)
>

--// Module Functions

-- A log from a version id such as "0.690.0.6900612", nil when it isn't four numbers
function DeployLog.fromVersionId(versionId: string, versionGuid: string): DeployLog?
	local majorRev, version, patch, commitId = string.match(versionId, "^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
	if not majorRev then return nil end
	
	return setmetatable({
		VersionGuid = versionGuid,
		MajorRev = tonumber(majorRev) :: number,
		Version = tonumber(version) :: number,
		Patch = tonumber(patch) :: number,
		CommitId = tonumber(commitId) :: number,
		VersionId = `{tonumber(majorRev)}.{tonumber(version)}.{tonumber(patch)}.{tonumber(commitId)}`,
		Unsupported = false
	}, DeployLog)
end

function DeployLog.__tostring(self: DeployLog): string
	return self.VersionId
end

return DeployLog
