local UDim2 = require("@Luwow/udim2")
local task = require("@Luwow/task")

local Packages = require("@Frontend/Packages")
local Types = require("@Frontend/Types")

local Foundation = Packages.Foundation
local Datatypes = Packages.Datatypes

local Snackbar = Foundation.Snackbar
local View = Foundation.View

local IconName = Foundation.Enums.IconName

local unwrap = Foundation.Utility.unwrap

local DEFAULT_DISPLAY_TIME = 2
-- The toast's distance from the window's bottom edge while it's shown
local MARGIN = 16
-- Where it slides in from and out to
local HIDDEN_OFFSET = 96
-- How long sliding in or out takes
local SLIDE_TIME = 0.25

--// Types

type Scope = Types.Scope

export type NotificationController = {
	-- Shows the message, replacing the one shown, and hides it after the display time
	Show: (text: string, icon: string?) -> (),
	Hide: () -> ()
}

--// Local Functions

--[[
	The toast, centered at the bottom of its parent. It slides up into place
	while shown, and back down out of sight once it's hidden.
]]
local function createContainer(scope: Scope, message: any, icon: any, shown: any): any
	local slide = Datatypes.TweenInfo.new(SLIDE_TIME, Datatypes.Enum.EasingStyle.Quad, Datatypes.Enum.EasingDirection.Out)
	local offset = scope:Tween(
		scope:Computed(function(use)
			return if unwrap(shown, use) then -MARGIN else HIDDEN_OFFSET
		end),
		slide
	)

	return View {
		scope = scope,
		Name = "Notification",
		AnchorPoint = vector.create(0.5, 1, 0),
		Position = scope:Computed(function(use)
			return UDim2.new(0.5, 0, 1, unwrap(offset, use))
		end),
		tag = "auto-xy",
		ZIndex = 100,
		Visible = scope:Computed(function(use)
			return unwrap(message, use) ~= nil
		end),
		children = {
			Toast = scope:Computed(function(use, innerScope: Scope)
				local text = unwrap(message, use)
				if not text then
					return nil
				end
				return Snackbar {
					scope = innerScope,
					title = text,
					icon = unwrap(icon),
				}
			end),
		},
	}
end

--// Return Constructor

--[[
	A toast at the bottom center of its parent.
]]
return function(scope: Scope, displayTime: number?): (any, NotificationController)
	local seconds = displayTime or DEFAULT_DISPLAY_TIME

	local message = scope:Value(nil :: string?)
	local shown = scope:Value(false)
	local icon = scope:Value(IconName.CircleCheck :: string)

	local pending: thread? = nil

	local function cancelPending()
		if pending then
			pcall(task.cancel, pending)
			pending = nil
		end
	end

	local function slideOut()
		shown:set(false)
		pending = task.delay(SLIDE_TIME, function()
			pending = nil
			message:set(nil)
		end)
	end

	local function hide()
		cancelPending()
		if unwrap(shown) then
			slideOut()
		else
			message:set(nil)
		end
	end

	local function show(text: string, newIcon: string?)
		cancelPending()
		icon:set(newIcon or IconName.CircleCheck)
		message:set(text)
		shown:set(true)
		pending = task.delay(seconds, function()
			pending = nil
			slideOut()
		end)
	end

	-- A message waiting to be hidden mustn't outlive the window
	table.insert(scope, cancelPending)

	local container = createContainer(scope, message, icon, shown)

	return container, { Show = show, Hide = hide }
end
