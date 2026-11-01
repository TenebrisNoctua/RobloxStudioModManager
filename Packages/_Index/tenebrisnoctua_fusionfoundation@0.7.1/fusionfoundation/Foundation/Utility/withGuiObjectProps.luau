local Datatypes = require("./Luwow/Datatypes")
local UDim2, Color3, Vector2, Enum = Datatypes.UDim2, Datatypes.Color3, Datatypes.Vector2, Datatypes.Enum

local PackageManager = require("../PackageManager")

local Fusion = PackageManager.getPackage("Fusion")

local unwrap = require("./unwrap")
local isState = require("./isState")
local getFormattedTags = require("./getFormattedTags")
local withCommonProps = require("./withCommonProps")
local isLuwow = require("./isLuwow")
local Types = require("./Types")

local OnChange = Fusion.OnChange
local Tags = Fusion.Tags

local DEFAULT_COLOR = Color3.fromRGB(163, 165, 162)
local DEFAULT_TRANSPARENCY = 1

type UsedAs<T> = Types.UsedAs<T>
type Scope = Types.Scope
type Use = Types.Use

type GuiObjectProps = Types.GuiObjectProps
type CommonProps = Types.CommonProps
type NativeCommonProps = Types.NativeCommonProps
type SelectionGroup = Types.SelectionGroup

-- Since GuiObjectProps is in a different form than what's actually applied, we need to manually define the applied props
type AppliedGuiObjectProps = {
	AnchorPoint: UsedAs<Vector2>?,
	AutoLocalize: UsedAs<boolean>?,
	AutomaticSize: UsedAs<Enum.AutomaticSize>?,
	BackgroundColor3: UsedAs<Color3>?,
	BackgroundTransparency: UsedAs<number>?,
	BorderSizePixel: UsedAs<number>?,
	BorderColor3: UsedAs<Color3>?,
	BorderMode: UsedAs<Enum.BorderMode>?,
	ClipsDescendants: UsedAs<boolean>?,
	Rotation: UsedAs<number>?,
	Selectable: UsedAs<boolean>?,
	SelectionImageObject: UsedAs<GuiObject>?,
	SelectionOrder: UsedAs<number>?,
	SizeConstraint: UsedAs<Enum.SizeConstraint>?,
	NextSelectionDown: UsedAs<GuiObject>?,
	NextSelectionLeft: UsedAs<GuiObject>?,
	NextSelectionRight: UsedAs<GuiObject>?,
	NextSelectionUp: UsedAs<GuiObject>?,
	Size: UsedAs<UDim2>?,
} & NativeCommonProps

local function getBackgroundStylePropsStates(scope: Scope, backgroundStyle: UsedAs<{Color3: Color3, Transparency: number}>)
	local color3 = scope:Computed(function(use: Use) 
		local styleData = unwrap(backgroundStyle, use)
		if not styleData then return DEFAULT_COLOR end
		return styleData.Color3
	end)
	local transparency = scope:Computed(function(use: Use) 
		local styleData = unwrap(backgroundStyle, use)
		if not styleData then return DEFAULT_TRANSPARENCY end
		return styleData.Transparency
	end)
	return {Color3 = color3, Transparency = transparency}
end

--[[
	Roblox's UIAspectRatioConstraint, UIFlexItem and UISizeConstraint are a
	control's own properties on Luwow: AspectRatio, Flex, MinSize and MaxSize.
]]
local function withLuwowConstraints(props: GuiObjectProps & CommonProps, baseProps: any)
	local scope = props.scope
	local aspectRatio = props.aspectRatio
	if aspectRatio ~= nil then
		baseProps.AspectRatio = scope:Computed(function(use: Use)
			local value = unwrap(aspectRatio, use)
			if typeof(value) == "table" then
				return unwrap(value.AspectRatio, use)
			end
			return value
		end)
	end

	local flexItem = props.flexItem
	if flexItem ~= nil then
		baseProps.Flex = scope:Computed(function(use: Use)
			local item = unwrap(flexItem, use)
			if item == nil then
				return nil
			end
			return {
				Mode = unwrap(item.FlexMode, use),
				GrowRatio = unwrap(item.GrowRatio, use),
				ShrinkRatio = unwrap(item.ShrinkRatio, use),
				ItemLineAlignment = unwrap(item.ItemLineAlignment, use),
			}
		end)
	end

	local sizeConstraint = props.sizeConstraint
	if sizeConstraint ~= nil then
		local function size(field: string)
			return scope:Computed(function(use: Use)
				local constraint = unwrap(sizeConstraint, use)
				local value = if constraint then unwrap(constraint[field], use) else nil
				if value == nil or value.X == math.huge and value.Y == math.huge then
					return nil
				end
				return vector.create(math.min(value.X, 1e7), math.min(value.Y, 1e7), 0)
			end)
		end
		baseProps.MinSize = size("MinSize")
		baseProps.MaxSize = size("MaxSize")
	end
end

local function withGuiObjectProps<T>(props: GuiObjectProps & CommonProps, baseProps: T | any)
	if type(baseProps) == "table" then
		baseProps.AutoLocalize = props.AutoLocalize
		baseProps.AutomaticSize = props.AutomaticSize
		
		if props.backgroundStyle then 
			local styleProps = if isState(props.backgroundStyle) then 
				getBackgroundStylePropsStates(props.scope, props.backgroundStyle) else props.backgroundStyle
			
			baseProps.BackgroundColor3 = styleProps.Color3
			baseProps.BackgroundTransparency = styleProps.Transparency 
		end
		
		baseProps.BorderSizePixel = props.BorderSizePixel
		baseProps.BorderColor3 = props.BorderColor3
		baseProps.BorderMode = props.BorderMode
		baseProps.ClipsDescendants = props.ClipsDescendants
		baseProps.Rotation = props.Rotation
		baseProps.SizeConstraint = props.SizeConstraint

		if props.selection then
			baseProps.Selectable = props.selection.Selectable
			baseProps.SelectionImageObject = props.selection.SelectionImageObject
			baseProps.SelectionOrder = props.selection.SelectionOrder
			baseProps.NextSelectionDown = props.selection.NextSelectionDown
			baseProps.NextSelectionLeft = props.selection.NextSelectionLeft
			baseProps.NextSelectionRight = props.selection.NextSelectionRight
			baseProps.NextSelectionUp = props.selection.NextSelectionUp
		end

		if props.selectionGroup ~= nil then
			if type(props.selectionGroup) == "boolean" then
				baseProps.SelectionGroup = props.selectionGroup
			else
				local selectionGroup = props.selectionGroup :: SelectionGroup
				baseProps.SelectionGroup = true
				baseProps.SelectionBehaviorUp = selectionGroup.SelectionBehaviorUp
				baseProps.SelectionBehaviorDown = selectionGroup.SelectionBehaviorDown
				baseProps.SelectionBehaviorLeft = selectionGroup.SelectionBehaviorLeft
				baseProps.SelectionBehaviorRight = selectionGroup.SelectionBehaviorRight
			end
		end

		baseProps.Size = props.Size

		if isLuwow then
			withLuwowConstraints(props, baseProps)
		end
	end
	
	local tagProp = props.tag
	if tagProp then
		if typeof(tagProp) == "table" and not isState(tagProp) then
			baseProps[Tags] = getFormattedTags(tagProp)
		else
			baseProps[Tags] = tagProp
		end
	end
	
	local fullProps = withCommonProps(props, baseProps) :: any -- Required since constrained generics are not yet supported
	
	-- Replace incompatible Common Props
	fullProps[OnChange "AbsoluteSize"] = fullProps.onAbsoluteSizeChanged
	fullProps.onAbsoluteSizeChanged = nil
	fullProps[OnChange "AbsolutePosition"] = fullProps.onAbsolutePositionChanged
	fullProps.onAbsolutePositionChanged = nil
	
	return fullProps :: T & AppliedGuiObjectProps
end

return withGuiObjectProps
