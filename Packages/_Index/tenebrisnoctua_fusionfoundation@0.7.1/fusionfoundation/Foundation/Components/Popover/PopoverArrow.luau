local Datatypes = require("../../Utility/Luwow/Datatypes")
local UDim2 = Datatypes.UDim2
local Instances = require("../../Utility/Luwow/Instances")
local Hydrate = Instances.Hydrate

local PackageManager = require("../../PackageManager")

local Dash = PackageManager.getPackage("Dash")

local View = require("../View")

local unwrap = require("../../Utility/unwrap")
local stripProps = require("../../Utility/stripProps")
local withDefaults = require("../../Utility/withDefaults")
local withCommonProps = require("../../Utility/withCommonProps")
local Types = require("../../Utility/Types")

local COMPONENT_ONLY_PROPERTIES = {
	"size",
	"position",
	"backgroundStyle",
	"ZIndex"
}

local defaultProps = {}

type UsedAs<T> = Types.UsedAs<T>
type Scope = Types.Scope
type Use = Types.Use

type ColorStyleValue = Types.ColorStyleValue

export type PopoverArrowProps = {
	scope: Scope,
	size: UsedAs<number>,
	position: UsedAs<UDim2>,
	backgroundStyle: UsedAs<ColorStyleValue>,
	ZIndex: UsedAs<number>,
} & Types.CommonProps

return function(arrowProps: PopoverArrowProps)
	local scope = arrowProps.scope
	assert(scope, "A scope has not been provided for the PopoverArrow component.")

	local props = withDefaults(arrowProps, defaultProps)
	return scope:Computed(function(use: Use, innerScope: Scope)
		local currentSize = unwrap(props.size, use)
		local currentPosition = unwrap(props.position, use)
		local currentZIndex = unwrap(props.ZIndex, use)
		local currentBackgroundStyle = unwrap(props.backgroundStyle, use)

		local viewProps = {
			scope = innerScope,
			Size = UDim2.fromOffset(currentSize, currentSize),
			Position = currentPosition,
			Rotation = 45,
			ZIndex = currentZIndex,
			backgroundStyle = currentBackgroundStyle,
			tag = "anchor-center-center"
		}

		return Hydrate(innerScope, unwrap(View(viewProps))(Dash.join(withCommonProps(props, {}), stripProps(props, COMPONENT_ONLY_PROPERTIES))))
	end)
end