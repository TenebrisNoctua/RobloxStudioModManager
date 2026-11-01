--!strict

--[[
	Turns the Roblox properties of the pseudo-instances in Foundation's style
	rules into Luwow ones, for LuwowStyler. The instance's own properties are
	turned by Foundation's Luwow instances, see Utility/Luwow/Instances.

	On Luwow, pseudo-instances are real objects or the instance's own
	properties:

		UICorner                 a Corner child
		UIPadding                a Padding child
		UIStroke                 a Stroke child
		UIListLayout             a ListLayout child
		UIAspectRatioConstraint  the instance's AspectRatio
		UIFlexItem               the instance's Flex

	Roblox properties Luwow has no equivalent for, such as TextWrapped, are
	left out. Enum items become their names, which is how Luwow takes enums,
	and Roblox's transparencies become the alpha of Luwow's Colors.
]]

local Color = require("@Luwow/color")

export type Properties = {[string]: any}

export type Pseudo = {
	class: string?,
	translate: (properties: Properties) -> Properties
}

local LuwowProperties = {}

local function enumName(
	value: any
): any
	if typeof(value) == "EnumItem" then
		return value.Name
	end
	return value
end

local function same(
	value: any
): any
	return value
end

local function pick(
	properties: Properties,
	names: {[string]: (any) -> any}
): Properties
	local picked = {}
	for name, convert in names do
		local value = properties[name]
		if value ~= nil then
			picked[name] = convert(value)
		end
	end
	return picked
end

local function withTransparency(
	color: any,
	transparency: any
): any
	if typeof(color) ~= "Color" or typeof(transparency) ~= "number" then
		return color
	end
	local alpha = math.clamp(color.A * (1 - transparency), 0, 1)
	return Color.new(color.R, color.G, color.B, alpha)
end

LuwowProperties.pseudo = {
	UICorner = {
		class = "Corner",
		translate = function(properties: Properties): Properties
			return pick(properties, {
				CornerRadius = same,
				TopLeftRadius = same,
				TopRightRadius = same,
				BottomRightRadius = same,
				BottomLeftRadius = same,
			})
		end
	},
	UIPadding = {
		class = "Padding",
		translate = function(properties: Properties): Properties
			return pick(properties, {
				PaddingTop = same,
				PaddingBottom = same,
				PaddingLeft = same,
				PaddingRight = same,
			})
		end
	},
	UIStroke = {
		class = "Stroke",
		translate = function(properties: Properties): Properties
			local translated = pick(properties, {
				Thickness = function(value)
					return math.max(0, math.round(value))
				end,
			})
			local transparency = properties.Transparency
			if properties.Color ~= nil then
				translated.Color = withTransparency(properties.Color, transparency)
			elseif typeof(transparency) == "number" and transparency >= 1 then
				translated.Thickness = 0
			end
			return translated
		end
	},
	UIListLayout = {
		class = "ListLayout",
		translate = function(properties: Properties): Properties
			return pick(properties, {
				Padding = same,
				FillDirection = enumName,
				HorizontalAlignment = enumName,
				VerticalAlignment = enumName,
				SortOrder = enumName,
				Wraps = same,
				HorizontalFlex = enumName,
				VerticalFlex = enumName,
				ItemLineAlignment = enumName,
			})
		end
	},
	UIAspectRatioConstraint = {
		translate = function(properties: Properties): Properties
			return {AspectRatio = properties.AspectRatio}
		end
	},
	UIFlexItem = {
		translate = function(properties: Properties): Properties
			return {
				Flex = {
					Mode = enumName(properties.FlexMode),
					GrowRatio = properties.GrowRatio,
					ShrinkRatio = properties.ShrinkRatio,
					ItemLineAlignment = enumName(properties.ItemLineAlignment),
				}
			}
		end
	},
} :: {[string]: Pseudo}

return LuwowProperties
