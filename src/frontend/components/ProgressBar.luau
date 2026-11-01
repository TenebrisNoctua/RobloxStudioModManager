local Color = require("@Luwow/color")
local UDim = require("@Luwow/udim")
local UDim2 = require("@Luwow/udim2")

local Packages = require("@Frontend/Packages")
local Types = require("@Frontend/Types")

local Foundation = Packages.Foundation
local RunService = Packages.RunService

local View = Foundation.View

local unwrap = Foundation.Utility.unwrap

-- The app's accent fill
local ACCENT = { Color3 = Color.fromRGB(237, 97, 105), Transparency = 0 }
local TRACK = { Color3 = Color.new(1, 1, 1), Transparency = 0.6 }

local HEIGHT = 4
local INDICATOR_HEIGHT = 3
-- The indeterminate indicator's share of the track, and the seconds one sweep takes
local SWEEP_WIDTH = 0.4
local SWEEP_TIME = 2

--// Types

type Scope = Types.Scope
type UsedAs<T> = Types.UsedAs<T>

export type ProgressBarProps = {
	Value: UsedAs<number>,
	Maximum: UsedAs<number>,
	IsIndeterminate: UsedAs<boolean>,
	LayoutOrder: number?,
	Size: UsedAs<any>?,
	Position: UsedAs<any>?,
	AnchorPoint: UsedAs<any>?
}

--// Local Functions

-- The indicator's left edge as it sweeps, from fully left of the track to fully right of it
local function sweepPosition(sweep: number): any
	return UDim2.fromScale(-SWEEP_WIDTH + sweep * (1 + SWEEP_WIDTH), 0.5)
end

-- The indicator's share of the track while it isn't indeterminate
local function fillSize(value: number, maximum: number): any
	local fraction = if maximum > 0 then math.clamp(value / maximum, 0, 1) else 0
	return UDim2.new(fraction, 0, 0, INDICATOR_HEIGHT)
end

--// Return Constructor

--[[
	A thin track with an accent indicator, which fills to
	Value / Maximum, or sweeps across while IsIndeterminate.

	Custom created because Foundation doesn't have a component that satisfies the style well.
]]
return function(scope: Scope, props: ProgressBarProps): any
	local sweep = scope:Value(0)

	local connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		if not unwrap(props.IsIndeterminate) then
			return
		end
		sweep:set((unwrap(sweep) + deltaTime / SWEEP_TIME) % 1)
	end)
	table.insert(scope, function()
		connection:Disconnect()
	end)

	local indicatorPosition = scope:Computed(function(use)
		if not unwrap(props.IsIndeterminate, use) then
			return UDim2.fromScale(0, 0.5)
		end
		return sweepPosition(unwrap(sweep, use))
	end)

	local indicatorSize = scope:Computed(function(use)
		if unwrap(props.IsIndeterminate, use) then
			return UDim2.new(SWEEP_WIDTH, 0, 0, INDICATOR_HEIGHT)
		end
		return fillSize(unwrap(props.Value, use), unwrap(props.Maximum, use))
	end)

	return View {
		scope = scope,
		Name = "Progress",
		LayoutOrder = props.LayoutOrder,
		Size = props.Size or UDim2.new(1, 0, 0, HEIGHT),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		ClipsDescendants = true,
		children = {
			Track = View {
				scope = scope,
				Name = "Track",
				AnchorPoint = vector.create(0, 0.5, 0),
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.new(1, 0, 0, 1),
				backgroundStyle = TRACK,
			},
			Indicator = View {
				scope = scope,
				Name = "Indicator",
				AnchorPoint = vector.create(0, 0.5, 0),
				Position = indicatorPosition,
				Size = indicatorSize,
				cornerRadius = UDim.new(0, INDICATOR_HEIGHT / 2),
				backgroundStyle = ACCENT,
			}
		}
	}
end
