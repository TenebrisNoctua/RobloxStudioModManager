const fs = require("@Luwow/fs")
const process = require("@Luwow/process")
const task = require("@Luwow/task")
const zip = require("@Luwow/zip")

const Http = require("@Backend/tools/Http")
const Json = require("@Backend/tools/Json")
const Paths = require("@Backend/tools/Paths")
const Platform = require("@Backend/tools/Platform")
const Tasks = require("@Backend/tools/Tasks")
const StudioRegistry = require("@Backend/tools/StudioRegistry")

const ClientVersionInfo = require("@Backend/classes/ClientVersionInfo")
const FileManifest = require("@Backend/classes/FileManifest")
const PackageManifest = require("@Backend/classes/PackageManifest")

const StateManager = require("@Backend/managers/StateManager")
const VersionManager = require("@Backend/managers/VersionManager")
const FlagManager = require("@Backend/managers/FlagManager")

const BASE_URL = "https://setup.rbxcdn.com"
const USER_AGENT = "RobloxStudioModManager"

-- How many packages are verified, downloaded and extracted at once
const VERIFY_LIMIT = 8
const DOWNLOAD_LIMIT = 6
const EXTRACT_LIMIT = 4
-- How often the progress is shown, like the BootstrapWindow's DispatcherTimer
const PROGRESS_TICK = 0.1

local Manager = {}

--// Types

type FileManifest = FileManifest.FileManifest
type Package = PackageManifest.Package

-- The StudioBootstrapper's settings
export type BootstrapOptions = {
	ForceInstall: boolean?,
	ApplyModManagerPatches: boolean?,
	-- A version guid installed in place of the target's, from a "version-" launch argument
	OverrideGuid: string?,
	-- False skips closing Studio before installing
	CanShutdownStudio: boolean?,
	CanForceStudioShutdown: boolean?,
	RemapExtraContent: boolean?,
}

-- The frontend's BootstrapStates, the bootstrapper's feeds
type Feed = {
	Status: any,
	Progress: any,
	MaxProgress: any,
	Indeterminate: any,
	Echo: (message: string) -> (),
	Confirm: (message: string, title: string) -> boolean,
	[string]: any,
}

-- One run of the bootstrapper
type Session = {
	Feed: Feed,
	Options: BootstrapOptions,
	Status: string?,
	Progress: number,
	MaxProgress: number,
	Indeterminate: boolean,
	-- Files being downloaded, their sizes count towards the progress
	Downloading: { [string]: boolean },
	Running: boolean,

	-- Set up for the installation
	FileManifest: FileManifest?,
	BySignature: { [string]: { string } },
	WrittenFiles: { [string]: boolean },
	NewManifestEntries: { [string]: string },
	KnownRoots: { [string]: string },
	BadManifests: { string },
	BuildVersion: string,
}

--// Local Functions

local function startsWith(text: string, prefix: string): boolean
	return string.sub(text, 1, #prefix) == prefix
end

local function endsWith(text: string, suffix: string): boolean
	return #text >= #suffix and string.sub(text, -#suffix) == suffix
end

local function echo(session: Session, message: string)
	session.Feed.Echo(message)
end

local function setStatus(session: Session, status: string)
	if session.Status ~= status then
		session.Feed.Status:set(status)
		session.Status = status
	end
end

local function setProgress(session: Session, progress: number, maxProgress: number, indeterminate: boolean)
	session.Progress = progress
	session.MaxProgress = maxProgress
	session.Indeterminate = indeterminate
end

local function showProgress(session: Session)
	local progress = session.Progress
	for path in session.Downloading do
		local ok, stat = pcall(fs.stat, path)
		if ok then
			progress += stat.size
		end
	end

	local feed = session.Feed
	feed.Indeterminate:set(session.Indeterminate)
	feed.MaxProgress:set(session.MaxProgress)
	feed.Progress:set(progress)
end

local function headers(): { [string]: string }
	return { ["User-Agent"] = USER_AGENT }
end

local function packageUrl(session: Session, pkgName: string): string
	return `{BASE_URL}/channel/common/{session.BuildVersion}-{pkgName}`
end

local function appendNewManifestEntry(session: Session, key: string, value: string)
	session.NewManifestEntries[key] = value
end

local function fixFilePath(session: Session, pkgName: string, filePath: string): string
	local pkgDir = string.gsub(pkgName, "%.zip", "")

	if table.find(session.BadManifests, pkgDir) and not startsWith(filePath, pkgDir) then
		filePath = pkgDir .. "\\" .. filePath
	end

	if session.Options.RemapExtraContent then
		filePath = string.gsub(filePath, "ExtraContent", "content")
	end

	return (string.gsub(filePath, "/", "\\"))
end

-- A path of the studio folder, from a registry key
local function studioFile(studioDir: string, fileName: string): string
	return studioDir .. "/" .. string.gsub(fileName, "\\", "/")
end

local function runningStudioProcesses(): { number }
	local studioProcs = {}
	for _, info in process.list(Platform.getStudioProcessName()) do
		if info.hasWindow then
			table.insert(studioProcs, info.pid)
		elseif not process.kill(info.pid) then
			print(`Cannot terminate process {info.pid}!`)
		end
	end
	return studioProcs
end

local function shutdownStudioProcesses(session: Session): boolean
	setStatus(session, "Shutting down Roblox Studio...")

	-- Check if studio processes exist & prompt the user to restart studio
	if #runningStudioProcesses() > 0 then
		local proceed = session.Feed.Confirm(
			"All Roblox Studio processes need to be closed in order to update Roblox Studio!\n"
				.. "Press Ok once you've saved your work, or\n"
				.. "Press Cancel to skip this update temporarily.",
			"Notice"
		)
		if not proceed then
			return false
		end
	end

	-- Close all running processes
	while true do
		local running = runningStudioProcesses()

		-- No processs open, good to go
		if #running == 0 then
			return true
		end

		for _, pid in running do
			if session.Options.CanForceStudioShutdown then
				process.kill(pid)
				continue
			end
			process.focusWindow(pid)
			process.closeWindows(pid)
			task.wait(0.05)
		end

		local retries = 10
		local granularity = 300
		setProgress(session, 0, retries * granularity, false)

		for _ = 1, retries do
			if #runningStudioProcesses() == 0 then
				return true
			end
			task.wait(1)
			session.Progress += granularity
		end
	end
end

-- The KnownRoots.json packages that apply to the version: where they extract to, and the bad manifests
local function fetchKnownRoots(session: Session, installVersion: number)
	table.clear(session.KnownRoots)
	table.clear(session.BadManifests)
	setStatus(session, "Fetching Known Roots...")

	local knownRoots = Json.decode(Http.get(VersionManager.BaseConfigUrl .. "KnownRoots.json"))
	for name, knownRoot in knownRoots do
		if installVersion < (knownRoot.MinVersion or 0) then
			continue
		end

		local extractPath = knownRoot.ExtractTo or ""
		if extractPath ~= "" then
			extractPath ..= "/"
		end

		if knownRoot.BadManifest then
			table.insert(session.BadManifests, name)
		end

		session.KnownRoots[name .. ".zip"] = extractPath
	end
end

local function packageState(pkgName: string): { NumFiles: number, Signature: string }
	local pkgRegistry = StateManager.get().PackageManifest
	local pkgInfo = pkgRegistry[pkgName]
	if type(pkgInfo) ~= "table" then
		pkgInfo = Json.object({ NumFiles = 0, Signature = "" })
		pkgRegistry[pkgName] = pkgInfo
	end
	return pkgInfo
end

local function shouldFetchPackage(session: Session, package: Package): boolean
	local pkgInfo = packageState(package.Name)

	if pkgInfo.Signature == package.Signature and not session.Options.ForceInstall then
		echo(session, `Package '{package.Name}' hasn't changed between builds, skipping.`)
		return false
	end
	return true
end

local function packageExists(session: Session, package: Package): boolean
	echo(session, `Verifying availability of: {package.Name}`)
	return Http.head(packageUrl(session, package.Name), headers()) == 200
end

-- Downloads the package into the downloads folder, its size counting towards the progress meanwhile
local function installPackage(session: Session, package: Package): string
	local zipFileUrl = packageUrl(session, package.Name)
	local zipPath = Paths.join(Paths.getDownloadsDirectory(), package.Name)
	echo(session, `Installing package {zipFileUrl}`)

	session.Downloading[zipPath] = true
	local ok, result = pcall(Http.download, zipFileUrl, zipPath, headers())
	session.Downloading[zipPath] = nil

	if not ok then
		error(result, 0)
	end

	-- If the size of the file we downloaded does not match the packed
	-- size specified in the manifest, then this file isn't valid.
	session.Progress += result
	if result ~= package.PackedSize then
		error(`{package.Name} expected packed size: {package.PackedSize} but got: {result}`, 0)
	end
	return zipPath
end

--[[
	Works out where each of the package's files go, as extractPackage does,
	then extracts them in one go off the state. Signatures come from the file
	manifest, the ones it doesn't list are the MD5 of the file, which is what
	the manifest lists.
]]
local function extractPackage(session: Session, package: Package)
	local pkgName = package.Name
	local studioDir = Paths.getStudioDirectory()
	local zipPath = Paths.join(Paths.getDownloadsDirectory(), pkgName)
	local fileManifest = session.FileManifest :: FileManifest
	local fileRegistry = StateManager.get().FileManifest
	local pkgInfo = packageState(pkgName)

	local entries = zip.read(zipPath)
	session.MaxProgress += #entries

	local numFiles = 0
	for _, entry in entries do
		if not endsWith(entry.name, "/") then
			numFiles += 1
		end
	end

	-- The entries' own signatures, for the ones the manifest doesn't resolve
	local computed = zip.hashEntries(zipPath)
	local localRootDir: string? = session.KnownRoots[pkgName]
	local deferred = {}
	local targets: { [string]: { string } } = {}
	local written = {}

	local function writePackageFile(file: string, newFileSig: string, entryName: string)
		local filePath = fixFilePath(session, pkgName, file)
		if session.WrittenFiles[filePath] then
			return
		end

		if filePath ~= file then
			appendNewManifestEntry(session, filePath, newFileSig)
		end

		if not session.Options.ForceInstall and (fileRegistry[filePath] or "") == newFileSig then
			return
		end

		local extractPath = studioFile(studioDir, filePath)
		local paths = targets[entryName]
		if not paths then
			paths = {}
			targets[entryName] = paths
		end
		table.insert(paths, extractPath)
		table.insert(written, { FilePath = filePath, Signature = newFileSig, ExtractPath = extractPath })

		session.WrittenFiles[filePath] = true
	end

	for _, entry in entries do
		local name = entry.name
		local fileName = string.match(name, "([^/\\]*)$") or name
		if entry.size == 0 or endsWith(fileName, ".robloxrc") or endsWith(fileName, ".luarc") then
			continue
		end

		local entryPath = string.gsub(name, "/", "\\")
		local newFileSig: string?

		-- If we have figured out what our root directory is, try to resolve
		-- what the signature of this file is.
		if localRootDir ~= nil then
			newFileSig = fileManifest:Get(localRootDir .. entryPath) or fileManifest:Get(entryPath)
		else
			newFileSig = fileManifest:Get(entryPath)
			if not newFileSig then
				local match = fileManifest:FindEndingWith(entryPath)
				newFileSig = if match then fileManifest:Get(match) else nil
			end
		end

		-- If we couldn't pre-determine the file signature from the manifest, it's the computed one
		local signature = newFileSig or computed[name]

		-- Now check what files this signature corresponds with.
		local files = session.BySignature[signature]
		if files then
			for _, file in files do
				-- Write the file from this signature.
				writePackageFile(file, signature, name)

				if localRootDir == nil then
					local filePath = fixFilePath(session, pkgName, file)
					if filePath ~= file then
						appendNewManifestEntry(session, filePath, signature)
					end

					-- We can infer what the root extraction directory is for the files in this package!
					if endsWith(filePath, entryPath) then
						localRootDir = string.sub(filePath, 1, #filePath - #entryPath)
					end
				end
			end
		elseif localRootDir == nil or localRootDir == "" then
			-- Check back on this file after we extract the regular files,
			-- so we can make sure this is extracted to the correct directory.
			table.insert(deferred, { Name = name, Signature = signature })
		else
			-- Append the local root directory.
			writePackageFile(localRootDir .. name, signature, name)
		end
	end

	-- Process any files that we deferred from writing immediately.
	for _, entry in deferred do
		local file = entry.Name
		if localRootDir ~= nil then
			file = localRootDir .. file
		end
		if not fileManifest:Get(file) then
			appendNewManifestEntry(session, file, entry.Signature)
		end
		writePackageFile(file, entry.Signature, entry.Name)
	end

	for _, file in written do
		echo(session, `Writing {file.FilePath}...`)
	end

	local result = zip.extract(zipPath, targets)
	local failed = {}
	for _, path in result.failed do
		failed[path] = true
	end

	for _, file in written do
		if failed[file.ExtractPath] then
			echo(session, `FILE WRITE FAILED: {file.FilePath} (This build may not run as expected!)`)
		else
			fileRegistry[file.FilePath] = file.Signature
		end
	end

	-- Update the signature in the package registry so we can check
	-- if this zip file needs to be updated in future versions.
	pkgInfo.Signature = package.Signature
	pkgInfo.NumFiles = numFiles

	-- Extracted, the package is only taking space
	pcall(fs.remove, zipPath)
	session.Progress += #entries
end

local function deleteUnusedFiles(session: Session)
	local studioDir = Paths.getStudioDirectory()
	local fileManifest = session.FileManifest :: FileManifest
	local fileRegistry = StateManager.get().FileManifest
	setStatus(session, "Deleting unused files...")

	for key, value in session.NewManifestEntries do
		if fileManifest:Get(key) then
			continue
		end
		fileRegistry[key] = value
		fileManifest:Set(key, value)
	end

	local fileNames = {}
	for fileName in fileRegistry do
		table.insert(fileNames, fileName)
	end

	for _, fileName in fileNames do
		local filePath = studioFile(studioDir, fileName)
		local lookupKey = fileName

		if not fileManifest:Get(fileName) then
			for _, pkgName in session.BadManifests do
				if startsWith(fileName, pkgName) then
					lookupKey = string.sub(fileName, #pkgName + 2)
				end
			end
		end

		if fileManifest:Get(lookupKey) then
			continue
		end

		if fs.exists(filePath) and fs.type(filePath) == "file" then
			local oldHash = fileRegistry[fileName]
			local name = string.match(fileName, "([^\\/]*)$") or fileName

			if type(oldHash) == "string" and #oldHash > 32 then
				if endsWith(name, ".dll") or name == "qmldir" or string.find(filePath, "api-docs", 1, true) then
					continue
				end
			end

			echo(session, `Deleting unused file {fileName}`)
			fileRegistry[fileName] = nil

			local ok = pcall(fs.remove, filePath)
			if not ok then
				print(`Couldn't delete {fileName}`)
			end
		else
			fileRegistry[fileName] = nil
		end
	end
end

-- Fails the installation, says so, and waits a moment so it can be read
local function fail(session: Session, message: string, delay: number): boolean
	setStatus(session, "Installation Failed!")
	echo(session, message)
	setProgress(session, 1, 1, true)
	task.wait(delay)
	return false
end

-- The installation part of Bootstrap, for a version that isn't installed yet
local function install(session: Session, versionId: string): boolean
	local options = session.Options
	local installVersion = tonumber(string.split(versionId, ".")[2]) or 0

	fetchKnownRoots(session, installVersion)

	setStatus(session, "Installing Packages...")
	echo(session, "Grabbing package manifest...")
	local pkgManifest = PackageManifest.get(session.BuildVersion)

	echo(session, "Grabbing file manifest...")
	local fileManifest = FileManifest.get(session.BuildVersion, options.RemapExtraContent)
	session.FileManifest = fileManifest
	session.BySignature = fileManifest:GroupBySignature()
	table.clear(session.WrittenFiles)

	setProgress(session, 0, 0, false)

	-- Verify all of these packages are available to install.
	local verifyJobs = {}
	for _, package in pkgManifest.Packages do
		package.ShouldInstall = shouldFetchPackage(session, package)
		if not package.ShouldInstall then
			package.Exists = true
			continue
		end
		table.insert(verifyJobs, function()
			package.Exists = packageExists(session, package)
		end)
	end
	Tasks.all(verifyJobs, VERIFY_LIMIT)

	-- Install packages, abort if any of them don't exist.
	local installJobs = {}
	local toInstall = {}
	for _, package in pkgManifest.Packages do
		if not package.Exists then
			return fail(session, `ERROR WHILE INSTALLING: Package {package.Name} could not be fetched! Skipping installation for now.`, 2)
		end
		if package.ShouldInstall then
			table.insert(toInstall, package)
			session.MaxProgress += package.PackedSize
			table.insert(installJobs, function()
				return installPackage(session, package)
			end)
		end
	end

	local _, installErrors = Tasks.all(installJobs, DOWNLOAD_LIMIT)

	-- Make sure the packages were installed without errors.
	if next(installErrors) then
		for _, message in installErrors do
			echo(session, message)
		end
		return fail(session, "One or more packages failed to install correctly! Skipping update for now...", 0.5)
	end

	-- Extract all of the packages
	setStatus(session, "Extracting Packages...")
	setProgress(session, 0, 0, false)

	local extractJobs = {}
	for _, package in toInstall do
		table.insert(extractJobs, function()
			extractPackage(session, package)
		end)
	end

	local _, extractErrors = Tasks.all(extractJobs, EXTRACT_LIMIT)
	if next(extractErrors) then
		for _, message in extractErrors do
			echo(session, message)
		end
		return fail(session, "One or more packages failed to extract correctly! Skipping update for now...", 2)
	end

	deleteUnusedFiles(session)
	return true
end

--[[
	The installation on macOS, where Studio is one app in one zip for the
	Mac's architecture rather than packages: it's extracted beside the
	installed app, then takes its place, so a failed install leaves the
	installed one as it was.
]]
local function installMac(session: Session): boolean
	local zipName = `{session.BuildVersion}-RobloxStudioApp.zip`
	local url = `{BASE_URL}/{Platform.getMacDownloadFolder()}/{zipName}`
	local downloads = Paths.getDownloadsDirectory()
	local zipPath = Paths.join(downloads, zipName)
	local staging = Paths.join(downloads, session.BuildVersion)
	local appPath = Paths.getStudioDirectory()

	setStatus(session, "Installing Roblox Studio...")
	echo(session, `Installing {url}`)
	setProgress(session, 0, Http.contentLength(url, headers()) or 0, false)

	session.Downloading[zipPath] = true
	local ok, result = pcall(Http.download, url, zipPath, headers())
	session.Downloading[zipPath] = nil
	if not ok then
		pcall(fs.remove, zipPath)
		return fail(session, `ERROR WHILE INSTALLING: {result}`, 2)
	end
	session.Progress += result

	setStatus(session, "Extracting Roblox Studio...")
	echo(session, `Extracting {zipName}...`)
	setProgress(session, 0, 0, true)

	if fs.exists(staging) then
		fs.rmdir(staging, true)
	end

	-- The zip is made by ditto, and only ditto restores all of it.
	local extractOk, extracted = pcall(process.run, { "ditto", "-x", "-k", zipPath, staging })
	pcall(fs.remove, zipPath)

	if not extractOk or not extracted.ok then
		pcall(fs.rmdir, staging, true)
		local problem = if extractOk then extracted.stderr else extracted
		return fail(session, `ERROR WHILE EXTRACTING: {problem}`, 2)
	end

	local newApp = Paths.join(staging, "RobloxStudio.app")
	if not fs.exists(newApp) then
		pcall(fs.rmdir, staging, true)
		return fail(session, "Roblox Studio couldn't be extracted completely! Skipping update for now...", 2)
	end
	echo(session, "Extracted RobloxStudio.app")

	-- The new app takes the installed one's place
	if fs.exists(appPath) then
		fs.rmdir(appPath, true)
	end
	local parent = string.match(appPath, "^(.*)/[^/]*$")
	if parent and not fs.exists(parent) then
		fs.mkdir(parent, true)
	end
	fs.move(newApp, appPath)
	pcall(fs.rmdir, staging, true)
	return true
end

--// Module Functions

--[[
	Brings Studio to the target version, feeding the bootstrapper window's states. Installs what
	changed, writes Studio's configs, registers its protocols, and applies
	the flags when ApplyModManagerPatches is set. Returns whether Studio is
	ready, yielding meanwhile.
]]
function Manager.bootstrap(feed: Feed, targetVersion: string, options: BootstrapOptions?): boolean
	local session: Session = {
		Feed = feed,
		Options = options or {},
		Status = nil,
		Progress = 0,
		MaxProgress = 0,
		Indeterminate = true,
		Downloading = {},
		Running = true,

		FileManifest = nil,
		BySignature = {},
		WrittenFiles = {},
		NewManifestEntries = {},
		KnownRoots = {},
		BadManifests = {},
		BuildVersion = "",
	}

	task.spawn(function()
		while session.Running do
			showProgress(session)
			task.wait(PROGRESS_TICK)
		end
	end)

	local ok, result = pcall(function()
		local sessionOptions = session.Options
		local versionData = StateManager.get().VersionData
		local studioDir = Paths.getStudioDirectory()

		setStatus(session, "Checking for updates")
		echo(session, "Checking build installation...")

		local currentVersion = versionData.VersionGuid
		local versionInfo = VersionManager.getVersionInfo(targetVersion)

		if sessionOptions.OverrideGuid and sessionOptions.OverrideGuid ~= "" then
			versionInfo = ClientVersionInfo.new(versionInfo.Version, sessionOptions.OverrideGuid)
		end
		session.BuildVersion = versionInfo.VersionGuid

		-- A Studio that was removed is installed again, whatever version was recorded
		if currentVersion ~= session.BuildVersion or sessionOptions.ForceInstall or not Paths.isStudioInstalled() then
			echo(session, "This build needs to be installed!")
			local studioClosed = true

			if sessionOptions.CanShutdownStudio ~= false then
				studioClosed = shutdownStudioProcesses(session)
			end

			if studioClosed then
				local installed = if Platform.isMac() then installMac(session) else install(session, versionInfo.Version)
				if not installed then
					return false
				end

				versionData.Version = versionInfo.Version
				versionData.VersionGuid = session.BuildVersion
				versionData.VersionOverload = targetVersion
				session.Indeterminate = true
			else
				session.Indeterminate = true
				echo(session, "Update cancelled. Launching on current version.")
			end
		else
			echo(session, "This version of Roblox Studio has been installed!")
		end

		-- The Mac app carries its own configuration and registers its own protocols, and writing into it
		-- would break its signature
		if not Platform.isMac() then
			local oAuth2Config = Http.get(VersionManager.BaseConfigUrl .. "OAuth2Config.json")
			local appSettings = Http.get(VersionManager.BaseConfigUrl .. "AppSettings.xml")

			echo(session, "Writing AppSettings.xml...")
			fs.writeFile(Paths.join(studioDir, "AppSettings.xml"), appSettings)

			echo(session, "Writing OAuth2Config.json...")
			local applicationConfig = Paths.join(studioDir, "ApplicationConfig")
			if not fs.exists(applicationConfig) then
				fs.mkdir(applicationConfig, true)
			end
			fs.writeFile(Paths.join(applicationConfig, "OAuth2Config.json"), oAuth2Config)

			setStatus(session, "Configuring Roblox Studio...")
			echo(session, "Updating registry protocols...")
			StudioRegistry.updateProtocols(Paths.getStudioPath())
		end

		if sessionOptions.ApplyModManagerPatches then
			echo(session, "Applying flag configuration...")
			FlagManager.applyFlags()
		end

		setProgress(session, 1, 1, true)
		setStatus(session, "Starting Roblox Studio...")
		echo(session, "Roblox Studio is up to date!")

		task.wait(1)
		return true
	end)

	session.Running = false
	showProgress(session)

	if not ok then
		return fail(session, `ERROR: {result}`, 2)
	end
	return result
end

function Manager.install(feed: Feed)
	Manager.bootstrap(feed, StateManager.get().TargetVersion)
	StateManager.save()
end

function Manager.returnCallbacks()
	return {
		Bootstrap = {
			Install = Manager.install
		}
	}
end

return Manager
