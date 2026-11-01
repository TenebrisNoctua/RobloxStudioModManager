local gui = require("@Luwow/udc")
local system = require("@Luwow/os")
local UDim2 = require("@Luwow/udim2")
local task = require("@Luwow/task")

local Packages = require("@Frontend/Packages")
local Types = require("@Frontend/Types")
local Style = require("@Frontend/Style")

local ScopeManager = require("@Frontend/managers/ScopeManager")
local OverlayManager = require("@Frontend/managers/OverlayManager")

local Foundation = Packages.Foundation
local Fusion = Packages.Fusion

local Children = Fusion.Children

local WindowManager = {
	-- Windows are never shown while set, for tests
	Headless = false,
	-- The open windows, oldest first
	Windows = {} :: { any },
}

local appScope: Types.Scope? = nil
local exiting = false

--// Types

type Scope = Types.Scope

export type WindowOptions = {
	Title: string,
	-- The whole window's size
	Size: vector?,
	-- The size inside the frame, used in place of Size
	ClientSize: vector?,
	Resizable: boolean?,
	Minimizable: boolean?,
	TopMost: boolean?,
	-- The window it belongs to
	Owner: any?,
	Modal: boolean?,
	-- The close button only calls OnCloseRequested
	PreventClose: boolean?,
	OnCloseRequested: (() -> ())?,
	-- Called once it's closed, by the user or by code, before its scope is cleaned
	OnClosed: (() -> ())?,
	-- Builds the window's content, the children of its root view
	Content: (scope: Scope) -> any
}

--// Local Functions

local function forget(window: any)
	local index = table.find(WindowManager.Windows, window)
	if index then
		table.remove(WindowManager.Windows, index)
	end
end

--// Module Functions

-- The scope Foundation's providers live in, for the whole program
function WindowManager.initialize(scope: Scope)
	appScope = scope
end

--[[
	Creates a hidden window centered on its owner, or on the screen. It has
	its own overlay for Foundation's popovers, the active one while the window
	is in use, and its own scope, cleaned once it's closed.
]]
function WindowManager.create(options: WindowOptions): (any, Scope)
	assert(appScope, "WindowManager.initialize must be called first")

	local scope = ScopeManager.createScope()
	local overlay: any = nil
	local window: any = nil

	window = gui.createWindow({
		Title = options.Title,
		Size = options.Size,
		ClientSize = options.ClientSize,
		Resizable = options.Resizable,
		Minimizable = options.Minimizable,
		TopMost = options.TopMost,
		Owner = options.Owner,
		Modal = options.Modal,
		PreventClose = options.PreventClose,
		Centered = true,
		Icon = Style.ICON,

		OnCloseRequested = options.OnCloseRequested,
		OnFocused = function()
			if overlay then
				OverlayManager.activate(overlay)
			end
		end,
		OnClosed = function()
			forget(window)
			OverlayManager.release(overlay)
			if options.OnClosed and not exiting then
				options.OnClosed()
			end
			ScopeManager.cleanScope(scope)

			-- A closed window's controls and their states are garbage now
			if not exiting then
				task.defer(system.releaseMemory)
			end
		end
	})

	-- Cleaned last, after the controls in it
	table.insert(scope, function()
		if not window.Destroyed then
			window:Destroy()
		end
	end)

	-- Popovers, such as a dropdown's menu, open in the overlay, which is drawn above everything else
	overlay = scope:New "View" {
		Name = "Overlay",
		Parent = window,
		ZIndex = 1000,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor = false,
		ClipsDescendants = false,
	}

	if not OverlayManager.isInitialized() then
		local providers = Foundation.FoundationProvider({
			scope = appScope,
			theme = Foundation.Enums.Theme.Dark,
			overlayGui = overlay
		})
		OverlayManager.initialize(providers.overlayProvider, overlay)
	else
		OverlayManager.activate(overlay)
	end

	scope:Hydrate(window) {
		[Children] = {
			Foundation.View {
				scope = scope,
				Name = "RootGrid",
				backgroundStyle = Style.BACKGROUND,
				tag = "size-full",
				children = options.Content(scope)
			},
		}
	}

	table.insert(WindowManager.Windows, window)
	return window, scope
end

function WindowManager.show(window: any)
	if WindowManager.Headless then
		return
	end
	window:Show()
end

function WindowManager.hide(window: any)
	window:Hide()
end

-- Closes the window, which calls its OnClosed and cleans its scope
function WindowManager.close(window: any)
	if window.Destroyed then
		return
	end
	window:Close()
end


-- Waits until the instance has a size, a layout having run. Gives up after a second.
function WindowManager.waitForLayout(instance: any)
	local deadline = os.clock() + 1
	while os.clock() < deadline do
		local size = instance.AbsoluteSize
		if size and size.x > 0 and size.y > 0 then
			return
		end
		task.wait()
	end
end

-- Destroys every window without calling their OnClosed. Once none is left, the program ends.
function WindowManager.closeAll()
	exiting = true
	for i = #WindowManager.Windows, 1, -1 do
		local window = WindowManager.Windows[i]
		WindowManager.Windows[i] = nil
		pcall(function()
			window:Destroy()
		end)
	end
	ScopeManager.cleanAll()
end

return WindowManager
