const fs = require("@Luwow/fs")
const process = require("@Luwow/process")

const Paths = require("@Backend/tools/Paths")
const Platform = require("@Backend/tools/Platform")

const StateManager = require("@Backend/managers/StateManager")
const BootstrapManager = require("@Backend/managers/BootstrapManager")

local Manager = {}

--// Local Functions

local function startsWith(text: string, prefix: string): boolean
	return string.sub(text, 1, #prefix) == prefix
end

-- Every file under the folder, Directory.GetFiles with SearchOption.AllDirectories
local function allFiles(folder: string, into: { string }?): { string }
	local files = into or {}
	for _, entry in fs.listdir(folder) do
		local path = folder .. "/" .. entry.name
		if entry.type == "dir" then
			allFiles(path, files)
		elseif entry.type == "file" then
			table.insert(files, path)
		end
	end
	return files
end

local function parentOf(path: string): string
	return string.match(path, "^(.*)/[^/]*$") or path
end

local function sameContents(a: string, b: string, size: number): boolean
	return fs.stat(b).size == size and fs.readFile(a) == fs.readFile(b)
end

local function copyModFiles()
	-- On macOS the files go into Studio's app, which a missing Studio mustn't be made as
	if Platform.isMac() and not Paths.isStudioInstalled() then
		return
	end
	local modPath = Paths.getModDirectory()

	for _, file in allFiles(modPath) do
		local ok, problem = pcall(function()
			local size = fs.stat(file).size
			local dir, name = string.match(file, "^(.*)/([^/]*)$")
			local filePath = file
			local delete = false

			if size == 0 and startsWith(name, "DELETE") then
				local realName = string.match(string.sub(name, 7), "^%s*(.-)$")
				filePath = dir .. "/" .. realName
				delete = true
			end

			local relativeFile = Paths.getModTarget(string.sub(filePath, #modPath + 2))
			local relativeDir = parentOf(relativeFile)
			if not fs.exists(relativeDir) then
				fs.mkdir(relativeDir, true)
			end

			if fs.exists(relativeFile) then
				if sameContents(file, relativeFile, size) then
					return
				end

				if delete then
					fs.remove(relativeFile)
					return
				end

				fs.copy(file, relativeFile, true)
			elseif not delete then
				fs.copy(file, relativeFile, true)
			end
		end)

		if not ok then
			print(`Failed to overwrite {file}! {problem}`)
		end
	end
end

local function studioCommand(arguments: { string }): { string }
	local command = if Platform.isMac() then { "open", "-a", Paths.getStudioDirectory() } else { Paths.getStudioPath() }
	if Platform.isMac() and #arguments > 0 then
		table.insert(command, "--args")
	end
	for _, argument in arguments do
		table.insert(command, argument)
	end
	return command
end

local function studioArguments(args: { string }): { string }
	local firstArg = args[1]
	if firstArg and startsWith(firstArg, "roblox-studio") then
		-- Arguments were passed by URI.
		return { firstArg }
	end

	-- Arguments were passed directly.
	return table.clone(args)
end

--// Module Functions

-- Whether the mod manager was started with arguments, such as by a place file or the website
function Manager.hasLaunchArguments(): boolean
	return #process.args() > 0
end

--[[
	Brings Studio up to date with the mod manager's
	patches, copies the mod files over and starts Studio with the launch
	arguments. Returns whether Studio was started.
]]
function Manager.launchStudio(forceReinstall: boolean, bootstrapper: any): boolean
	local state = StateManager.get()
	local args = process.args()

	local overrideGuid = ""
	if args[1] and startsWith(args[1], "version-") then
		overrideGuid = args[1]
	end

	BootstrapManager.bootstrap(bootstrapper, state.TargetVersion, {
		ForceInstall = forceReinstall,
		ApplyModManagerPatches = true,
		OverrideGuid = overrideGuid,
	})

	copyModFiles()

	local versionRegistry = state.VersionData
	versionRegistry.LastExecutedVersion = versionRegistry.VersionGuid

	local ok, problem = pcall(process.spawn, studioCommand(studioArguments(args)))
	StateManager.save()

	if not ok then
		print(`[LaunchManager] Couldn't start Roblox Studio: {problem}`)
		return false
	end
	return true
end

function Manager.openModFolder()
	process.open(Paths.getModDirectory())
end

function Manager.openStudioDirectory()
	if Platform.isMac() then
		if Paths.isStudioInstalled() then
			process.run({ "open", "-R", Paths.getStudioDirectory() })
		else
			process.open(Paths.getRootDirectory())
		end
		return
	end
	process.open(Paths.getStudioDirectory())
end

function Manager.returnCallbacks()
	return {
		Main = {
			HasLaunchArguments = Manager.hasLaunchArguments,
			LaunchStudio = Manager.launchStudio,
			OpenModFolder = Manager.openModFolder,
			OpenStudioDirectory = Manager.openStudioDirectory,
		}
	}
end

return Manager
