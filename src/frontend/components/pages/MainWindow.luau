local UDim = require("@Luwow/udim")
local UDim2 = require("@Luwow/udim2")
local task = require("@Luwow/task")

local Packages = require("@Frontend/Packages")
local Types = require("@Frontend/Types")
local Style = require("@Frontend/Style")

local WindowManager = require("@Frontend/managers/WindowManager")

local DialogWindow = require("@Frontend/components/DialogWindow")
local BusyOverlay = require("@Frontend/components/BusyOverlay")

local Foundation = Packages.Foundation
local Datatypes = Packages.Datatypes

local Button = Foundation.Button
local Checkbox = Foundation.Checkbox
local Dropdown = Foundation.Dropdown
local Image = Foundation.Image
local TextInput = Foundation.TextInput
local View = Foundation.View

local ButtonVariant = Foundation.Enums.ButtonVariant
local InputSize = Foundation.Enums.InputSize
local InputVariant = Foundation.Enums.InputVariant

local unwrap = Foundation.Utility.unwrap

local LATEST = "(Use Latest)"

-- The logo and the title, centered together.
local HEADER_HEIGHT = 104
local LOGO_SIZE = 94
local TITLE_FONT_SIZE = 28
local TITLE_LINE_HEIGHT = 34
local TITLE_WIDTH = 200
local HEADER_GAP = 22
-- The body's top, under the header
local BODY_TOP = 117
-- Where the action buttons start, level with the Target Version box under its label
local FIELD_LABEL_OFFSET = 27

local COLUMN_WIDTH = 173
local COLUMN_GAP = 16

local VERSION_HISTORY_DEBOUNCE = 0.4
-- Between the action buttons, and the extra room above the checkbox under them
local ACTION_SPACING = 6
local CHECKBOX_SPACING = 7

--// Types

type Scope = Types.Scope
type Callbacks = Types.Callbacks
type MainStates = Types.MainStates
type DeployVersion = Types.DeployVersion

-- What the UIManager gives the page
export type MainContext = {
	Window: any,
	UIManager: any,
	Loaded: (() -> ())?
}

type Page = {
	States: MainStates,
	Callbacks: Callbacks,
	Context: MainContext,
	-- The pending lostFocus debounce
	VersionHistoryDebounce: thread?
}

--// Local Functions

local function setBusy(page: Page, busy: boolean)
	page.States.Busy:set(busy)
end

local function showError(page: Page, message: string)
	DialogWindow.show({
		Title = "Error",
		Content = message,
		CloseButtonText = "OK",
		DefaultButton = "Close",
		Icon = "Error",
		Owner = page.Context.Window,
	})
end

local function promptNewRelease(page: Page, releaseTag: string)
	local result = DialogWindow.show({
		Title = "Update available!",
		Content = "There's a new version of the mod manager available!\n"
			.. "This version is likely broken or no longer supported.\n"
			.. "Would you like to check it out?",
		PrimaryButtonText = "Yes",
		CloseButtonText = "No",
		DefaultButton = "Primary",
		Icon = "Information",
		Owner = page.Context.Window,
	})

	if result == "Primary" then
		page.Callbacks.Main.OpenReleasePage(releaseTag)
		page.Context.UIManager.exit()
	end
end

local function findVersion(page: Page, versionId: string): DeployVersion?
	for _, version in unwrap(page.States.TargetVersions) do
		if version.Id == versionId then
			return version
		end
	end
	return nil
end

local function targetVersionChanged(page: Page, versionId: string)
	if versionId == "" then
		page.Callbacks.Main.SetTargetVersion("")
		return
	end

	local target = findVersion(page, versionId)
	if not target then
		return
	end

	page.Callbacks.Main.SetTargetVersion(target.Id)

	if target.Unsupported then
		DialogWindow.show({
			Title = "Tread Lightly!",
			Content = "This version of Roblox Studio is no longer supported!\n"
				.. "You are strongly advised against using it in the future.\n"
				.. "No technical support will be provided, use it at your own risk!",
			CloseButtonText = "OK",
			DefaultButton = "Close",
			Icon = "Warning",
			Owner = page.Context.Window,
		})
	end
end

local function selectVersion(page: Page, versionId: string)
	page.States.SelectedVersion:set(versionId)
	targetVersionChanged(page, versionId)
end

local function setVersionHistory(page: Page, channelName: string?, channelToken: string?)
	local states = page.States
	local name = channelName or "LIVE"
	local token = channelToken or ""

	states.TargetVersions:set({})
	local history = page.Callbacks.Main.FetchVersionHistory(name, token)

	states.TargetVersionEnabled:set(history.AllowTargetSelection)

	if not history.ChannelValid then
		showError(page, "Could not fetch client version info with the channel name and token!\nEnsure you have entered them correctly.")
		states.ChannelName:set("LIVE")
		states.ChannelToken:set("")
	end

	states.TargetVersions:set(history.Versions)

	if history.TargetVersion ~= "" and findVersion(page, history.TargetVersion) then
		selectVersion(page, history.TargetVersion)
		return
	end
	selectVersion(page, "")
end

local function launchStudio(page: Page)
	local context = page.Context
	WindowManager.hide(context.Window)

	local bootstrapper = context.UIManager.openBootstrapWindow(false)
	local launched = page.Callbacks.Main.LaunchStudio(unwrap(page.States.ForceReinstall), bootstrapper)
	bootstrapper.RequestClose()

	if launched then
		context.UIManager.exit()
		return
	end

	WindowManager.show(context.Window)
	setBusy(page, false)
end

local function onLoaded(page: Page)
	setBusy(page, true)

	if page.Callbacks.Main.HasLaunchArguments() then
		launchStudio(page)
		return
	end

	local releaseTag = page.Callbacks.Main.FetchLatestReleaseTag()
	if releaseTag == nil then
		showError(page, "Could not fetch latest release tag!\nYou may not have an internet connection.")
	elseif releaseTag ~= unwrap(page.States.ReleaseTag) then
		promptNewRelease(page, releaseTag)
	end

	setVersionHistory(page)
	setBusy(page, false)
end

local function showFlagWarningPrompt(page: Page): boolean
	local dontShowAgain = false

	local result = DialogWindow.show({
		Title = "WARNING: HERE BE DRAGONS",
		Content = function(scope: Scope, maxWidth: number)
			return View {
				scope = scope,
				tag = "auto-xy",
				layout = {
					FillDirection = "Vertical",
					Padding = UDim.new(0, 12),
					SortOrder = "LayoutOrder",
				},
				children = {
					Style.Text(scope, "Editing flags can make Roblox Studio unstable, and could potentially corrupt your places and game data.\n\n"
						.. "You should not edit them unless you are just experimenting with new features locally, and you know what you're doing.\n\n"
						.. "Are you sure you would like to continue?", {
						LayoutOrder = 1,
						Size = UDim2.new(),
						AutomaticSize = Datatypes.Enum.AutomaticSize.XY,
						TextWrapped = true,
						sizeConstraint = { MaxSize = vector.create(maxWidth, math.huge, 0) },
					}),
					Checkbox {
						scope = scope,
						label = "Do not show this warning again.",
						size = InputSize.Small,
						LayoutOrder = 2,
						onActivated = function(checked: boolean)
							dontShowAgain = checked
						end,
					},
				},
			}
		end,
		PrimaryButtonText = "Yes",
		CloseButtonText = "No",
		DefaultButton = "Close",
		Icon = "Error",
		Owner = page.Context.Window,
	})

	if result == "Primary" then
		page.Callbacks.Main.SetFlagWarningDisabled(dontShowAgain)
		return true
	end

	return false
end

local function editFlags(page: Page)
	local context = page.Context
	local allow = page.Callbacks.Main.GetFlagWarningDisabled()

	if not allow then
		allow = showFlagWarningPrompt(page)
	end

	if not allow then
		return
	end

	setBusy(page, true)

	local versionGuid = page.Callbacks.Main.GetCurrentVersion()
	WindowManager.hide(context.Window)

	context.UIManager.bringUpToDate(versionGuid, "Some newer flags might be missing.", context.Window)
	context.UIManager.openFlagEditor()

	WindowManager.show(context.Window)
	setBusy(page, false)
end

-- A debounce between ChannelTokenBox and ChannelNameBox, so the dropdown isn't rebuilt constantly
local function debounceVersionHistory(page: Page)
	if page.VersionHistoryDebounce then
		pcall(task.cancel, page.VersionHistoryDebounce)
	end

	page.VersionHistoryDebounce = task.delay(VERSION_HISTORY_DEBOUNCE, function()
		page.VersionHistoryDebounce = nil
		setVersionHistory(page, unwrap(page.States.ChannelName), unwrap(page.States.ChannelToken))
	end)
end

local function createLabel(scope: Scope, text: any, order: number, props: { [string]: any }?): any
	local labelProps: { [string]: any } = { LayoutOrder = order }
	for key, value in props or {} do
		labelProps[key] = value
	end
	return Style.Text(scope, text, labelProps)
end

local function createActionButton(scope: Scope, name: string, text: string, order: number, onClick: () -> ()): any
	return Button {
		scope = scope,
		Name = name,
		text = text,
		variant = ButtonVariant.Standard,
		size = InputSize.Small,
		width = UDim.new(0, COLUMN_WIDTH),
		LayoutOrder = order,
		onActivated = onClick,
	}
end

-- Foundation's inputs don't take a LayoutOrder, so each goes in a row of the column that has one
local function createField(scope: Scope, order: number, input: any): any
	return View {
		scope = scope,
		LayoutOrder = order,
		tag = "size-full-0 auto-y",
		children = { input },
	}
end

-- Header: logo + title
local function createHeader(scope: Scope, states: MainStates): any
	return View {
		scope = scope,
		Name = "Header",
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
		layout = {
			FillDirection = "Horizontal",
			HorizontalAlignment = "Center",
			VerticalAlignment = "Center",
			Padding = UDim.new(0, HEADER_GAP),
			SortOrder = "LayoutOrder",
		},
		children = {
			Image {
				scope = scope,
				Name = "Logo",
				Image = Style.LOGO,
				ScaleType = "Fit",
				Size = UDim2.fromOffset(LOGO_SIZE, LOGO_SIZE),
				LayoutOrder = 1,
			},
			View {
				scope = scope,
				Size = UDim2.fromOffset(TITLE_WIDTH, 0),
				LayoutOrder = 2,
				tag = "col align-x-center auto-y",
				children = {
					createLabel(scope, "Roblox Studio", 1, {
						Size = UDim2.new(1, 0, 0, TITLE_LINE_HEIGHT),
						TextXAlignment = "Center",
						Font = Style.LIGHT_FONT,
						FontSize = TITLE_FONT_SIZE,
					}),
					createLabel(scope, "Mod Manager", 2, {
						Size = UDim2.new(1, 0, 0, TITLE_LINE_HEIGHT),
						TextXAlignment = "Center",
						Font = Style.LIGHT_FONT,
						FontSize = TITLE_FONT_SIZE,
					}),
					createLabel(scope, states.ReleaseTag, 3, {
						Name = "ReleaseTagText",
						Size = UDim2.new(1, 0, 0, 22),
						TextXAlignment = "Center",
						FontSize = 11,
						textStyle = Style.FADED_TEXT,
					}),
				},
			},
		},
	}
end

-- Actions on the left
local function createActions(scope: Scope, page: Page): any
	local states = page.States

	return View {
		scope = scope,
		Name = "Actions",
		Position = UDim2.fromOffset(0, FIELD_LABEL_OFFSET),
		Size = UDim2.new(0, COLUMN_WIDTH, 1, -FIELD_LABEL_OFFSET),
		layout = {
			FillDirection = "Vertical",
			Padding = UDim.new(0, ACTION_SPACING),
			SortOrder = "LayoutOrder",
		},
		children = {
			createActionButton(scope, "LaunchStudioButton", "Launch Studio", 1, function()
				launchStudio(page)
			end),
			createActionButton(scope, "ManageModsButton", "Open Mod Folder", 2, function()
				page.Callbacks.Main.OpenModFolder()
			end),
			createActionButton(scope, "EditFlagsButton", "Edit Fast Flags", 3, function()
				editFlags(page)
			end),
			createActionButton(scope, "OpenStudioDirectoryButton", "Open Studio Directory", 4, function()
				page.Callbacks.Main.OpenStudioDirectory()
			end),
			CheckboxSpacer = View {
				scope = scope,
				Name = "CheckboxSpacer",
				Size = UDim2.fromOffset(0, CHECKBOX_SPACING - ACTION_SPACING),
				LayoutOrder = 5,
			},
			Checkbox {
				scope = scope,
				Name = "ForceRebuildCheck",
				label = "Force Reinstallation",
				size = InputSize.Small,
				isChecked = states.ForceReinstall,
				LayoutOrder = 6,
				onActivated = function(checked: boolean)
					states.ForceReinstall:set(checked)
				end,
			},
		},
	}
end

-- Fields/options on the right
local function createFields(scope: Scope, page: Page): any
	local states = page.States

	local versionItems = scope:Computed(function(use)
		local items = { { id = "", text = LATEST } }
		for _, version: DeployVersion in unwrap(states.TargetVersions, use) do
			table.insert(items, { id = version.Id, text = version.Text })
		end
		return items
	end)

	return View {
		scope = scope,
		Name = "Fields",
		Position = UDim2.fromOffset(COLUMN_WIDTH + COLUMN_GAP, 0),
		Size = UDim2.new(1, -(COLUMN_WIDTH + COLUMN_GAP), 1, 0),
		tag = "col gap-small",
		children = {
			createField(scope, 1, Dropdown {
				scope = scope,
				Name = "TargetVersionBox",
				label = "Target Version:",
				items = versionItems,
				value = states.SelectedVersion,
				size = InputSize.Small,
				variant = InputVariant.Contrast,
				width = UDim.new(1, 0),
				isDisabled = scope:Computed(function(use)
					return not unwrap(states.TargetVersionEnabled, use)
				end),
				-- TargetVersionBox_SelectionChanged
				onItemChanged = function(versionId)
					selectVersion(page, versionId :: string)
				end,
			}),
			createField(scope, 2, TextInput {
				scope = scope,
				Name = "ChannelNameBox",
				label = "Channel Name:",
				text = states.ChannelName,
				size = InputSize.Small,
				variant = InputVariant.Standard,
				width = UDim.new(1, 0),
				onChanged = function(text: string)
					states.ChannelName:set(text)
				end,
			}),
			createField(scope, 3, TextInput {
				scope = scope,
				Name = "ChannelTokenBox",
				label = "Channel Access Token:",
				text = states.ChannelToken,
				textInputType = "Password",
				size = InputSize.Small,
				variant = InputVariant.Standard,
				width = UDim.new(1, 0),
				onChanged = function(text: string)
					states.ChannelToken:set(text)
				end,
				-- ChannelTokenBox_LostFocus
				onFocusLost = function()
					debounceVersionHistory(page)
				end,
			}),
		},
	}
end

--// Return Constructor

return function(scope: Scope, callbacks: Callbacks, context: MainContext): (any, MainStates)
	local page: Page = {
		States = {
			ReleaseTag = scope:Value(callbacks.App.GetReleaseTag()),
			TargetVersions = scope:Value({}),
			SelectedVersion = scope:Value(""),
			TargetVersionEnabled = scope:Value(true),
			ChannelName = scope:Value("LIVE"),
			ChannelToken = scope:Value(""),
			ForceReinstall = scope:Value(false),
			Busy = scope:Value(false),
		},
		Callbacks = callbacks,
		Context = context,
		VersionHistoryDebounce = nil,
	}

	context.Loaded = function()
		onLoaded(page)
	end

	table.insert(scope, function()
		if page.VersionHistoryDebounce then
			pcall(task.cancel, page.VersionHistoryDebounce)
		end
	end)

	local children = {
		View {
			scope = scope,
			Name = "Content",
			Position = UDim2.fromOffset(16, 16),
			Size = UDim2.new(1, -32, 1, -16),
			children = {
				createHeader(scope, page.States),

				-- Body: actions on the left, fields/options on the right
				View {
					scope = scope,
					Name = "Body",
					Position = UDim2.fromOffset(0, BODY_TOP),
					Size = UDim2.new(1, 0, 1, -BODY_TOP),
					children = {
						createActions(scope, page),
						createFields(scope, page)
					}
				}
			}
		},

		BusyOverlay(scope, page.States.Busy)
	}

	return children, page.States
end
