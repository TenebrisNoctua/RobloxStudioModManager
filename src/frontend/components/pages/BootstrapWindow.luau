local Color = require("@Luwow/color")
local UDim = require("@Luwow/udim")
local UDim2 = require("@Luwow/udim2")
local task = require("@Luwow/task")

local Packages = require("@Frontend/Packages")
local Types = require("@Frontend/Types")
local Style = require("@Frontend/Style")

local DialogWindow = require("@Frontend/components/DialogWindow")
local ProgressBar = require("@Frontend/components/ProgressBar")
local VirtualList = require("@Frontend/components/VirtualList")

local Foundation = Packages.Foundation

local Divider = Foundation.Divider
local Image = Foundation.Image
local View = Foundation.View

local unwrap = Foundation.Utility.unwrap

local PADDING = 12
local ROW_SPACING = 10
local TITLE_HEIGHT = 40
local COLUMN_SPACING = 10

-- The terminal styled log
local LOG_BACKGROUND = { Color3 = Color.fromRGB(12, 12, 12), Transparency = 0 }
local LOG_TEXT = { Color3 = Color.fromRGB(212, 212, 212), Transparency = 0 }
local LOG_FONT_SIZE = 12
-- Each line's TextBlock, with the item's 0,1 padding
local LOG_LINE_HEIGHT = 18
-- Consolas's advance at 12 pixels, for the width of the longest line
local LOG_CHARACTER_WIDTH = 6.6

-- progressTimer's interval
local TICK = 0.1

--// Types

type Scope = Types.Scope
type Callbacks = Types.Callbacks
type BootstrapStates = Types.BootstrapStates

export type BootstrapContext = {
	Window: any,
	UIManager: any,
	-- Whether closing the window ends the program
	ExitOnClose: boolean,
	-- Set by the page: the window's OnCloseRequested and OnClosed
	CloseRequested: (() -> ())?,
	Closed: (() -> ())?
}

type Log = {
	Queue: { string },
	Lines: { string },
	Count: any,
	Longest: any,
	Controller: any
}

type Page = {
	States: BootstrapStates,
	Callbacks: Callbacks,
	Context: BootstrapContext,
	Log: Log,
	Open: boolean,
	ProgrammaticClose: boolean,
}

--// Local Functions

local function drainLog(log: Log)
	if #log.Queue == 0 then
		return
	end
	local drained = log.Queue
	log.Queue = {}

	local longest = unwrap(log.Longest)
	for _, line in drained do
		table.insert(log.Lines, line)
		longest = math.max(longest, utf8.len(line) or #line)
	end

	log.Longest:set(longest)
	log.Count:set(#log.Lines)
	if log.Controller then
		log.Controller.ScrollToIndex(#log.Lines)
	end
end

local function confirm(page: Page, message: string, title: string): boolean
	local result = DialogWindow.show({
		Title = title,
		Content = message,
		PrimaryButtonText = "OK",
		CloseButtonText = "Cancel",
		DefaultButton = "Primary",
		Icon = "Warning",
		Owner = page.Context.Window,
	})
	return result == "Primary"
end

local function closeRequested(page: Page)
	if page.ProgrammaticClose then return end

	local result = DialogWindow.show({
		Title = "Warning",
		Content = "The installation has not finished yet!\n"
			.. "Closing this window will exit the mod manager.\n"
			.. "Are you sure you want to continue?",
		PrimaryButtonText = "Yes",
		CloseButtonText = "No",
		DefaultButton = "Close",
		Icon = "Warning",
		Owner = page.Context.Window,
	})

	if result == "Primary" then
		page.Context.UIManager.exit()
	end
end

local function closed(page: Page)
	page.Open = false
	page.Callbacks.Bootstrap.Closed()

	if page.Context.ExitOnClose then
		page.Context.UIManager.exit()
	end
end

-- Terminal styled log, a virtual list, as a TextBox would lay out all its text on every update
local function createLogList(scope: Scope, log: Log): (any, any)
	return VirtualList(scope, {
		Count = log.Count,
		ItemHeight = LOG_LINE_HEIGHT,
		ResetOnCountChange = false,
		ContentWidth = scope:Computed(function(use)
			return math.ceil(unwrap(log.Longest, use) * LOG_CHARACTER_WIDTH)
		end),
		CreateRow = function(rowScope: Scope, slot)
			slot.Text = rowScope:Value("")
			return Style.Text(rowScope, slot.Text, {
				Name = "LogLine",
				Position = slot.Position,
				Visible = slot.Visible,
				Size = UDim2.new(1, 0, 0, LOG_LINE_HEIGHT),
				Font = Style.MONO_FONT,
				FontSize = LOG_FONT_SIZE,
				textStyle = LOG_TEXT,
			})
		end,
		BindRow = function(slot, index: number)
			slot.Text:set(log.Lines[index] or "")
		end
	})
end

local function createTitle(scope: Scope, states: BootstrapStates): any
	return View {
		scope = scope,
		Name = "Title",
		Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
		children = {
			Image {
				scope = scope,
				Name = "Logo",
				Image = Style.LOGO,
				ScaleType = "Fit",
				Size = UDim2.fromOffset(TITLE_HEIGHT, TITLE_HEIGHT),
			},
			Style.Text(scope, states.Status, {
				Name = "StatusText",
				AnchorPoint = vector.create(0, 0.5, 0),
				Position = UDim2.new(0, TITLE_HEIGHT + COLUMN_SPACING, 0.5, 0),
				Size = UDim2.new(1, -(TITLE_HEIGHT + COLUMN_SPACING), 1, 0),
				TextWrapped = true,
				Font = Style.SEMIBOLD_FONT,
				FontSize = 18,
			})
		}
	}
end

local function shownProgress(scope: Scope, states: BootstrapStates): any
	return scope:Computed(function(use)
		local value = unwrap(states.Progress, use)
		local maximum = unwrap(states.MaxProgress, use)
		if value > maximum then
			return math.max(0, maximum - 1)
		end
		return math.min(value, maximum)
	end)
end

--// Return Constructor

return function(scope: Scope, callbacks: Callbacks, context: BootstrapContext): (any, BootstrapStates)
	local page: Page

	local log: Log = {
		Queue = {},
		Lines = {},
		Count = scope:Value(0),
		Longest = scope:Value(0),
		Controller = nil,
	}

	local states: BootstrapStates = {
		Status = scope:Value("Checking for updates..."),
		Progress = scope:Value(0),
		MaxProgress = scope:Value(0),
		Indeterminate = scope:Value(true),

		Echo = function(message: string)
			table.insert(log.Queue, message)
		end,
		Confirm = function(message: string, title: string): boolean
			return confirm(page, message, title)
		end,
		-- Closes the window without the "installation hasn't finished" prompt
		RequestClose = function()
			if not page.Open then
				return
			end
			page.ProgrammaticClose = true
			context.Window:Close()
		end,

		Window = nil,
	}

	page = {
		States = states,
		Callbacks = callbacks,
		Context = context,
		Log = log,
		Open = true,
		ProgrammaticClose = false,
	}

	context.CloseRequested = function()
		closeRequested(page)
	end
	context.Closed = function()
		closed(page)
	end

	task.spawn(function()
		while page.Open do
			task.wait(TICK)
			if page.Open then
				drainLog(log)
			end
		end
	end)

	table.insert(scope, function()
		page.Open = false
	end)

	local logList, logController = createLogList(scope, log)
	log.Controller = logController

	local children = {
		View {
			scope = scope,
			Name = "Layout",
			tag = "size-full",
			padding = UDim.new(0, PADDING),
			children = {
				createTitle(scope, states),

				-- Divider between the title and the progress log
				View {
					scope = scope,
					Name = "DividerRow",
					Position = UDim2.fromOffset(0, TITLE_HEIGHT + ROW_SPACING),
					Size = UDim2.new(1, 0, 0, 1),
					children = {
						Divider {
							scope = scope,
						},
					},
				},

				View {
					scope = scope,
					Name = "Log",
					Position = UDim2.fromOffset(0, TITLE_HEIGHT + ROW_SPACING * 2 + 1),
					Size = UDim2.new(1, 0, 1, -(TITLE_HEIGHT + ROW_SPACING * 3 + 1 + 4)),
					backgroundStyle = LOG_BACKGROUND,
					cornerRadius = UDim.new(0, 6),
					padding = {
						left = UDim.new(0, 10),
						right = UDim.new(0, 10),
						top = UDim.new(0, 6),
						bottom = UDim.new(0, 6),
					},
					children = { logList },
				},

				ProgressBar(scope, {
					Value = shownProgress(scope, states),
					Maximum = states.MaxProgress,
					IsIndeterminate = states.Indeterminate,
					AnchorPoint = vector.create(0, 1, 0),
					Position = UDim2.fromScale(0, 1),
				})
			}
		}
	}

	return children, states
end
