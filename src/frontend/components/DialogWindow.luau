local gui = require("@Luwow/udc")
local signal = require("@Luwow/signal")
local UDim = require("@Luwow/udim")
local UDim2 = require("@Luwow/udim2")

local Packages = require("@Frontend/Packages")
local Types = require("@Frontend/Types")
local Style = require("@Frontend/Style")

local WindowManager = require("@Frontend/managers/WindowManager")

local Foundation = Packages.Foundation
local Datatypes = Packages.Datatypes

local Button = Foundation.Button
local Icon = Foundation.Icon
local View = Foundation.View
local ThemeProvider = Foundation.ThemeProvider

local ButtonVariant = Foundation.Enums.ButtonVariant
local IconName = Foundation.Enums.IconName
local InputSize = Foundation.Enums.InputSize

local unwrap = Foundation.Utility.unwrap

-- ShowAsync's measuring bounds, for the whole client area
local MAX_CONTENT_WIDTH = 440
local MIN_CONTENT_WIDTH = 300
local MIN_CONTENT_HEIGHT = 120

local PADDING = 20
local ROW_SPACING = 16
local BUTTON_SPACING = 8
local BUTTON_HEIGHT = 32
-- The emoji glyph's size at FontSize 34, and its right margin
local ICON_SIZE = 34
local ICON_MARGIN = 16

--// Types

type Scope = Types.Scope
type DialogOptions = Types.DialogOptions
type DialogResult = Types.DialogResult

export type Dialog = {
	Window: any,
	-- Presses a button, as a click does
	PressPrimary: () -> (),
	PressClose: () -> (),
	-- Yields until the dialog closes, returns its result
	Wait: () -> DialogResult
}

--// Local Functions

local function iconOf(icon: Types.DialogIcon?): (string?, string?)
	if icon == "Information" then
		return IconName.CircleI, "Emphasis"
	elseif icon == "Warning" then
		return IconName.TriangleExclamation, "Warning"
	elseif icon == "Error" then
		return IconName.CircleX, "Alert"
	end
	return nil, nil
end

-- The message, or the content the options build
local function createBody(scope: Scope, options: DialogOptions, maxWidth: number): any
	if type(options.Content) == "function" then
		return (options.Content :: any)(scope, maxWidth)
	end
	return Style.Text(scope, options.Content, {
		AutomaticSize = Datatypes.Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		TextWrapped = true,
		sizeConstraint = { MaxSize = vector.create(maxWidth, math.huge, 0) },
	})
end

local function createIcon(scope: Scope, name: string, color: string): any
	local theme = ThemeProvider()
	return Icon {
		scope = scope,
		name = name,
		size = ICON_SIZE,
		variant = "Filled",
		style = scope:Computed(function(use)
			return unwrap(theme.Tokens, use).Color.System[color]
		end),
	}
end

-- Centered beside the icon, in the space above the buttons
local function createContentHost(scope: Scope, body: any, iconWidth: number, maxWidth: number): any
	return View {
		scope = scope,
		Name = "ContentHost",
		AnchorPoint = vector.create(0, 0.5, 0),
		Position = UDim2.new(0, iconWidth, 0.5, -(BUTTON_HEIGHT + ROW_SPACING) / 2),
		tag = "auto-xy",
		sizeConstraint = { MaxSize = vector.create(maxWidth, math.huge, 0) },
		children = { body },
	}
end

-- The close button, and the accent primary button to its right when it has text
local function createButtons(scope: Scope, options: DialogOptions, pressPrimary: () -> (), pressClose: () -> ()): any
	local hasPrimary = options.PrimaryButtonText ~= nil and options.PrimaryButtonText ~= ""

	return View {
		scope = scope,
		Name = "Buttons",
		AnchorPoint = vector.create(1, 1, 0),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT),
		layout = {
			FillDirection = "Horizontal",
			HorizontalAlignment = "Right",
			VerticalAlignment = "Center",
			Padding = UDim.new(0, BUTTON_SPACING),
			SortOrder = "LayoutOrder",
		},
		children = {
			CloseButtonElement = Button {
				scope = scope,
				text = options.CloseButtonText,
				size = InputSize.Small,
				variant = ButtonVariant.Standard,
				LayoutOrder = 1,
				onActivated = pressClose,
			},
			PrimaryButtonElement = if hasPrimary
				then Button {
					scope = scope,
					text = options.PrimaryButtonText,
					size = InputSize.Small,
					variant = ButtonVariant.Emphasis,
					LayoutOrder = 2,
					onActivated = pressPrimary,
				}
				else nil
		}
	}
end

-- Sizes the window to its content once it's laid out
local function sizeToContent(window: any, contentHost: any, iconWidth: number, hasIcon: boolean)
	local content = unwrap(contentHost)
	WindowManager.waitForLayout(content)

	local size = content.AbsoluteSize
	local width = math.clamp(math.ceil(size.x) + iconWidth + PADDING * 2, MIN_CONTENT_WIDTH, MAX_CONTENT_WIDTH)
	local height = math.max(
		MIN_CONTENT_HEIGHT,
		PADDING * 2 + math.max(math.ceil(size.y), if hasIcon then ICON_SIZE else 0) + ROW_SPACING + BUTTON_HEIGHT
	)

	window.ClientSize = vector.create(width, height, 0)
	window:Center()
end

--// Module

local DialogWindow = {}

--[[
	Creates and shows a dialog in its own window, sized to its content. With
	an Owner, it's centered on it and the owner takes no input until it
	closes.
]]
function DialogWindow.create(options: DialogOptions): Dialog
	local iconName, iconColor = iconOf(options.Icon)
	local iconWidth = if iconName then ICON_SIZE + ICON_MARGIN else 0
	local maxTextWidth = MAX_CONTENT_WIDTH - PADDING * 2 - iconWidth

	local finished = signal.new()
	local resolved = false
	local closed = false
	local result: DialogResult = "None"

	local window: any
	local contentHost: any

	local function complete(newResult: DialogResult)
		if resolved then
			return
		end
		resolved = true
		result = newResult
	end

	local function pressPrimary()
		if options.OnPrimaryButtonClick and options.OnPrimaryButtonClick() == false then
			return
		end
		complete("Primary")
		WindowManager.close(window)
	end

	local function pressClose()
		complete("None")
		WindowManager.close(window)
	end

	window = WindowManager.create({
		Title = options.Title,
		ClientSize = vector.create(MIN_CONTENT_WIDTH, MIN_CONTENT_HEIGHT, 0),
		Resizable = false,
		TopMost = true,
		Owner = options.Owner,
		Modal = options.Owner ~= nil,
		OnClosed = function()
			closed = true
			complete("None")
			finished:Fire(result)
		end,
		Content = function(scope)
			contentHost = createContentHost(scope, createBody(scope, options, maxTextWidth), iconWidth, maxTextWidth)
			return {
				View {
					scope = scope,
					Name = "Dialog",
					tag = "size-full",
					padding = UDim.new(0, PADDING),
					children = {
						IconElement = if iconName then createIcon(scope, iconName, iconColor :: string) else nil,
						ContentHost = contentHost,
						Buttons = createButtons(scope, options, pressPrimary, pressClose),
					},
				},
			}
		end,
	})

	sizeToContent(window, contentHost, iconWidth, iconName ~= nil)

	if options.PlaySound ~= false then
		gui.beep("Information")
	end
	WindowManager.show(window)

	return {
		Window = window,
		PressPrimary = pressPrimary,
		PressClose = pressClose,
		Wait = function(): DialogResult
			if closed then
				return result
			end
			return finished:Wait()
		end,
	}
end

-- Shows a dialog and yields until it closes. "Primary" when the primary button closed it.
function DialogWindow.show(options: DialogOptions): DialogResult
	return DialogWindow.create(options).Wait()
end

return DialogWindow
