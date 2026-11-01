--!nonstrict
local Datatypes = require("../Utility/Luwow/Datatypes")
local Enum, NumberSequence, NumberSequenceKeypoint = Datatypes.Enum, Datatypes.NumberSequence, Datatypes.NumberSequenceKeypoint
local Instances = require("../Utility/Luwow/Instances")
local New, Hydrate = Instances.New, Instances.Hydrate

local unwrap = require("../Utility/unwrap")
local stripProps = require("../Utility/stripProps")
local Types = require("../Utility/Types")

local COMPONENT_ONLY_PROPERTIES = {
	"fillDirection",
	"top"
}

type Scope = Types.Scope
type Use = Types.Use

export type GradientProps = {
	scope: Scope,
	fillDirection: Enum.FillDirection,
	top: boolean
}

return function(props: GradientProps)
	local scope = props.scope
	assert(scope, "A scope has not been provided for the Gradient component.")
	return scope:Computed(function(use: Use, innerScope: Scope)
		local top = unwrap(props.top, use)
		return Hydrate(innerScope, New(innerScope, "UIGradient") {
			Rotation = if unwrap(props.fillDirection, use) == Enum.FillDirection.Vertical then 90 else 0,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, if top then 0 else 1),
				NumberSequenceKeypoint.new(
					0.5,
					if top then 0 else 1
				),
				NumberSequenceKeypoint.new(
					0.50001,
					if top then 1 else 0
				),
				NumberSequenceKeypoint.new(1, if top then 1 else 0),
			}),
		})(stripProps(props, COMPONENT_ONLY_PROPERTIES))
	end)
end
