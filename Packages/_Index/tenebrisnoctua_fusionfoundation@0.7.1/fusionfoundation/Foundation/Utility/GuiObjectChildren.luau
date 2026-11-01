local Instances = require("./Luwow/Instances")
local New = Instances.New
local Datatypes = require("./Luwow/Datatypes")
local typeof = Datatypes.typeof

local PackageManager = require("../PackageManager")

local Dash = PackageManager.getPackage("Dash")

local Padding = require("../Components/Padding")
local AspectRatio = require("../Components/AspectRatio")

local isState = require("./isState")
local isLuwow = require("./isLuwow")
local unwrap = require("./unwrap")
local Types = require("./Types")

type Use = Types.Use
type Child = Types.Child

type GuiObjectProps = Types.GuiObjectProps
type CommonProps = Types.CommonProps

local function GuiObjectChildren(props: GuiObjectProps & CommonProps): Child
	local Scope = props.scope
	local utilityChildren = {
		__AspectRatio = if props.aspectRatio ~= nil and not isLuwow then
			AspectRatio { 
				value = props.aspectRatio, 
				scope = Scope 
			}
		else nil,
		__Corner = if props.cornerRadius ~= nil then 
			New(Scope, "UICorner") {
				CornerRadius = props.cornerRadius,
			}
		else nil,
		__FlexItem = if props.flexItem ~= nil and not isLuwow then 
			New(Scope, "UIFlexItem") {
				FlexMode = props.flexItem.FlexMode,
				GrowRatio = props.flexItem.GrowRatio,
				ShrinkRatio = props.flexItem.ShrinkRatio,
				ItemLineAlignment = props.flexItem.ItemLineAlignment,
			}
		else nil,
		__ListLayout = if props.layout ~= nil and props.layout.FillDirection ~= nil then 
			New(Scope, "UIListLayout") {
				FillDirection = props.layout.FillDirection,
				ItemLineAlignment = props.layout.ItemLineAlignment,
				HorizontalAlignment = props.layout.HorizontalAlignment,
				HorizontalFlex = props.layout.HorizontalFlex,
				VerticalAlignment = props.layout.VerticalAlignment,
				VerticalFlex = props.layout.VerticalFlex,
				Padding = props.layout.Padding,
				SortOrder = props.layout.SortOrder,
				Wraps = props.layout.Wraps,
			}
		else nil,
		__SizeConstraint = if props.sizeConstraint ~= nil and not isLuwow then 
			New(Scope, "UISizeConstraint")(props.sizeConstraint)
		else nil,
		__Padding = if props.padding ~= nil then 
			Padding {
				value = props.padding,
				scope = Scope
			}
		else nil,
		__Scale = if props.scale ~= nil then 
			New(Scope, "UIScale") {
				Scale = props.scale,
			}
		else nil,
		__Stroke = if props.stroke ~= nil and not isState(props.stroke) then 
			New(Scope, "UIStroke")(props.stroke) 
		elseif props.stroke ~= nil then 
			Scope:Computed(function(use: Use) 
				local strokeProps = unwrap(props.stroke, use)
				if not strokeProps then return end
				return New(Scope, "UIStroke") {
					Color = strokeProps.Color,
					Transparency = strokeProps.Transparency,
					Thickness = strokeProps.Thickness,
					BorderStrokePosition = strokeProps.BorderStrokePosition
				}
			end)
		else nil,
	}

	if not props.children then
		return utilityChildren
	end

	if isState(props.children) then
		return Scope:Computed(function(use: Use)
			local dynamicChildren = unwrap(props.children, use)
			if not dynamicChildren then
				return utilityChildren
			end
			if typeof(dynamicChildren) == "BaseObject" or isState(dynamicChildren) then
				return Dash.join(utilityChildren, { dynamicChildren })
			end
			return Dash.join(utilityChildren, dynamicChildren)
		end)
	end

	return Dash.join(utilityChildren, unwrap(props.children) or {})
end

return GuiObjectChildren
