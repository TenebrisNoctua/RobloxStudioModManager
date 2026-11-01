const signal = require("@Luwow/signal")
const task = require("@Luwow/task")

const Packages = require("@Frontend/Packages")
const Types = require("@Frontend/Types")

const ScopeManager = require("@Frontend/managers/ScopeManager")
const WindowManager = require("@Frontend/managers/WindowManager")

const DialogWindow = require("@Frontend/components/DialogWindow")
const MainWindow = require("@Frontend/components/pages/MainWindow")
const BootstrapWindow = require("@Frontend/components/pages/BootstrapWindow")
const FlagEditorWindow = require("@Frontend/components/pages/FlagEditorWindow")

const RobloxContent = Packages.RobloxContent
const Instances = Packages.Instances

local Manager = {
	Initialized = false,
	Pages = {} :: {
		Main: Types.MainStates?,
		FlagEditor: Types.FlagEditorStates?,
		Bootstrap: Types.BootstrapStates?
	}
}

local callbacks: Types.Callbacks
local exited = false

--// Types

type Callbacks = Types.Callbacks
type DialogOptions = Types.DialogOptions
type DialogResult = Types.DialogResult
type BootstrapStates = Types.BootstrapStates

--// Local Functions

-- Runs a page's handler in its own thread
local function run(handler: (() -> ())?)
	if not handler then
		return
	end
	task.defer(function()
		local ok, err = xpcall(handler, debug.traceback)
		if not ok then
			print("[UIManager] " .. tostring(err))
		end
	end)
end

--// Module Functions

--[[
	Sets up Foundation's content and the frontend's scope, with the
	backend's callbacks.
]]
function Manager.initialize(backendCallbacks: Callbacks)
	if Manager.Initialized then
		return
	end

	callbacks = backendCallbacks

	-- Foundation's buttons and checkboxes label in bold, the app's are regular
	Instances.weightSubstitutes.Bold = "Regular"

	local studioContent = RobloxContent.findStudioContent()
	if studioContent then
		RobloxContent.setDirectory(studioContent)
	end

	WindowManager.initialize(ScopeManager.createScope())
	Manager.Initialized = true
end

-- Opens the main window, and runs its first load once it's shown
function Manager.createUI(): Types.MainStates
	assert(Manager.Initialized, "UIManager.initialize must be called first")

	local context: MainWindow.MainContext = { Window = nil, UIManager = Manager }
	local states: Types.MainStates

	local window = WindowManager.create({
		Title = "Roblox Studio Mod Manager",
		Size = vector.create(410, 410, 0),
		Resizable = false,
		-- Closing the main window ends the program
		OnClosed = function()
			Manager.Pages.Main = nil
			Manager.exit()
		end,
		Content = function(scope)
			local children, pageStates = MainWindow(scope, callbacks, context)
			states = pageStates
			return children
		end
	})

	context.Window = window
	Manager.Pages.Main = states
	WindowManager.show(window)

	run(context.Loaded)
	return states
end

--[[
	Opens the bootstrapper's window, and returns its states for the backend
	to feed. With exitWhenClosed, closing it ends the program.
]]
function Manager.openBootstrapWindow(exitWhenClosed: boolean?): BootstrapStates
	local states: BootstrapStates
	local context: BootstrapWindow.BootstrapContext = {
		Window = nil,
		UIManager = Manager,
		ExitOnClose = exitWhenClosed == true
	}

	local window = WindowManager.create({
		Title = "Roblox Studio Bootstrapper",
		Size = vector.create(560, 340, 0),
		Resizable = false,
		Minimizable = true,
		TopMost = true,
		PreventClose = true,
		OnCloseRequested = function()
			if context.CloseRequested then
				context.CloseRequested()
			end
		end,
		OnClosed = function()
			if Manager.Pages.Bootstrap == states then
				Manager.Pages.Bootstrap = nil
			end
			if context.Closed then
				context.Closed()
			end
		end,
		Content = function(scope)
			local children, pageStates = BootstrapWindow(scope, callbacks, context)
			states = pageStates
			return children
		end
	})

	context.Window = window
	states.Window = window
	Manager.Pages.Bootstrap = states
	WindowManager.show(window)

	return states
end

--[[
	Opens the flag editor, and yields until it's closed. Its flags are loaded
	once it's shown.
]]
function Manager.openFlagEditor()
	local context: FlagEditorWindow.FlagEditorContext = { Window = nil, UIManager = Manager }
	local states: Types.FlagEditorStates
	local closed = signal.new()
	local isClosed = false

	local window = WindowManager.create({
		Title = "Flag Editor",
		Size = vector.create(560, 760, 0),
		Resizable = false,
		OnClosed = function()
			if Manager.Pages.FlagEditor == states then
				Manager.Pages.FlagEditor = nil
			end
			if context.Closed then
				context.Closed()
			end
			isClosed = true
			closed:Fire()
		end,
		Content = function(scope)
			local children, pageStates = FlagEditorWindow(scope, callbacks, context)
			states = pageStates
			return children
		end
	})

	context.Window = window
	Manager.Pages.FlagEditor = states
	WindowManager.show(window)

	run(context.Loaded)
	if not isClosed then
		closed:Wait()
	end
end

--[[
	When the installed Studio isn't the
	expected version, asks to update, then installs it. Yields until it's done.
]]
function Manager.bringUpToDate(expectedVersion: string, updateReason: string, owner: any?)
	local currentVersion = callbacks.Bootstrap.GetInstalledVersion()
	if currentVersion == expectedVersion then return end

	local proceed = true

	if currentVersion ~= "" then
		local result = DialogWindow.show({
			Title = "Out of date!",
			Content = "Roblox Studio is out of date!\n" .. updateReason .. "\nWould you like to update now?",
			PrimaryButtonText = "Yes",
			CloseButtonText = "No",
			DefaultButton = "Primary",
			Icon = "Warning",
			Owner = owner,
		})

		proceed = result == "Primary"
	end

	if proceed then
		local installer = Manager.openBootstrapWindow(false)
		callbacks.Bootstrap.Install(installer)
		installer.RequestClose()
	end
end

-- Shows a dialog and yields until it closes
function Manager.showDialog(options: DialogOptions): DialogResult
	return DialogWindow.show(options)
end

function Manager.exit()
	if exited then
		return
	end
	exited = true

	pcall(callbacks.App.Exiting)
	Manager.Pages = {}
	WindowManager.closeAll()
end

return Manager
