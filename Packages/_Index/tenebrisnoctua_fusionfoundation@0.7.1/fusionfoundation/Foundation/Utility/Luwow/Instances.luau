--!nonstrict
local PackageManager = require("../../PackageManager")
local isLuwow = require("../isLuwow")

local Fusion = PackageManager.getPackage("Fusion")

--[[
	Foundation's instances. On Roblox these are Fusion's New and Hydrate. On
	Luwow, Foundation still describes its instances with Roblox's classes and
	properties, and this turns them into Luwow's:

		Frame, CanvasGroup        View
		ImageLabel, ImageButton   ImageLabel, ImageButton
		TextLabel, TextButton     TextLabel, TextButton
		TextBox                   TextInput
		ScrollingFrame            ScrollView
		UIListLayout, UICorner,   ListLayout, Corner,
		UIPadding, UIStroke,      Padding, Stroke,
		UIGradient                Gradient

	Roblox splits some Luwow properties in two, such as BackgroundColor3 and
	BackgroundTransparency for BackgroundColor, and they can be set apart: by
	New, by Hydrate, by Foundation's code, or by a style rule. So each instance
	keeps its Roblox properties, the ones set explicitly winning over styled
	ones like on Roblox, and its Luwow properties are worked out from them.
	Properties Luwow has no equivalent for are kept but do nothing.

	Activated, GuiState and the pointer events are made from Luwow's OnEnter,
	OnLeft, OnPressed and OnUnPressed.

	Roblox's images, such as rbxassetid:// ones, are downloaded by
	RobloxAssets, and shown once they're there. ImageRect and SliceCenter
	coordinates are mapped onto the downloaded thumbnails.
]]

local Instances = {}

if not isLuwow then
	function Instances.New(scope: any, className: string)
		return scope:New(className)
	end

	function Instances.Hydrate(scope: any, instance: any)
		return scope:Hydrate(instance)
	end

	function Instances.get(instance: any, property: string): any
		return instance[property]
	end

	function Instances.set(instance: any, property: string, value: any)
		instance[property] = value
	end

	function Instances.getStyled(instance: any, property: string): any
		return instance:GetStyled(property)
	end

	function Instances.getGuiState(instance: any): any
		return instance.GuiState
	end

	function Instances.getPropertyChangedSignal(instance: any, property: string): any
		return instance:GetPropertyChangedSignal(property)
	end

	function Instances.isInstance(value: any): boolean
		return typeof(value) == "Instance"
	end

	function Instances.connectEvent(instance: any, event: string, callback: (...any) -> ()): any
		return instance[event]:Connect(callback)
	end

	function Instances.captureFocus(instance: any)
		instance:CaptureFocus()
	end

	function Instances.releaseFocus(instance: any)
		instance:ReleaseFocus()
	end

	function Instances.isFocused(instance: any): boolean
		return instance:IsFocused()
	end

	return table.freeze(Instances)
end

local Color = require("@Luwow/color")
local fs = require("@Luwow/fs")
local LuwowRect = require("@Luwow/rect")
local UDim2 = require("@Luwow/udim2")
local RobloxAssets = require("./RobloxAssets")
local RobloxContent = require("./RobloxContent")
local task = require("@Luwow/task")

local runtime = Fusion.Runtime
local peek = Fusion.peek
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local OnChange = Fusion.OnChange
local Out = Fusion.Out

local function isState(value: any): boolean
	return typeof(value) == "table" and value.type == "State"
end

local CLASSES: {[string]: string} = {
	Frame = "View",
	CanvasGroup = "View",
	ImageLabel = "ImageLabel",
	ImageButton = "ImageButton",
	TextLabel = "TextLabel",
	TextButton = "TextButton",
	TextBox = "TextInput",
	ScrollingFrame = "ScrollView",
	UIListLayout = "ListLayout",
	UICorner = "Corner",
	UIPadding = "Padding",
	UIStroke = "Stroke",
	UIGradient = "Gradient",
}
for _, class in table.clone(CLASSES) do
	CLASSES[class] = class
end

local function set(names: {string}, base: {[string]: boolean}?): {[string]: boolean}
	local result = if base then table.clone(base) else {}
	for _, name in names do
		result[name] = true
	end
	return result
end

local CONTROL = set({
	"Name", "Position", "Size", "AnchorPoint", "MinSize", "MaxSize", "AspectRatio", "Flex", "AutomaticSize",
	"Visible", "LayoutOrder", "ZIndex", "BackgroundColor", "BorderColor", "BorderWidth", "ClipsDescendants",
})
local TEXT = set({"Text", "TextColor", "TextSize", "Font", "FontStyle", "TextAlignment", "MultiLine", "TextWrapped", "Truncated"}, CONTROL)
local IMAGE = set({"Image", "ScaleType", "ImageRectOffset", "ImageRectSize", "ImageColor", "SliceCenter", "SliceScale", "TileSize", "Rotation"}, CONTROL)
local PROPERTIES: {[string]: {[string]: boolean}} = {
	View = CONTROL,
	ScrollView = set({"ScrollPosition", "ContentSize", "AutomaticCanvasSize", "ScrollBarColor", "ScrollBarThickness"}, CONTROL),
	ImageLabel = IMAGE,
	ImageButton = set({"HoverImage", "PressedImage", "HoverColor", "PressedColor"}, IMAGE),
	TextLabel = TEXT,
	TextButton = set({"HoverColor", "PressedColor"}, TEXT),
	TextInput = set({"PlaceholderText", "PlaceholderColor", "SelectionColor", "TextInputType", "FocusedBorderColor"}, TEXT),
	ListLayout = set({
		"Name", "FillDirection", "HorizontalAlignment", "VerticalAlignment", "SortOrder", "Padding", "Wraps",
		"HorizontalFlex", "VerticalFlex", "ItemLineAlignment",
	}),
	Corner = set({"Name", "CornerRadius", "TopLeftRadius", "TopRightRadius", "BottomRightRadius", "BottomLeftRadius"}),
	Padding = set({"Name", "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight"}),
	Stroke = set({"Name", "Color", "Thickness", "StrokePosition"}),
	Gradient = set({"Name", "Color", "Transparency", "Rotation", "Offset", "Enabled"}),
}

local function withTransparency(color: any, transparency: any, default: any): any
	if typeof(color) ~= "Color" then
		color = default
	end
	local alpha = color.A
	if typeof(transparency) == "number" then
		alpha *= math.clamp(1 - transparency, 0, 1)
	end
	if alpha == color.A then
		return color
	end
	return Color.new(color.R, color.G, color.B, alpha)
end

local DEFAULT_BACKGROUND = Color.fromRGB(163, 162, 165)
local DEFAULT_TEXT = Color.fromRGB(27, 42, 53)
local DEFAULT_PLACEHOLDER = Color.fromRGB(178, 178, 178)
local DEFAULT_SCROLLBAR = Color.fromRGB(0, 0, 0)
local DEFAULT_STROKE = Color.fromRGB(0, 0, 0)

--[[
	Font families shown with another, "" being the platform's UI font, when
	RobloxContent has no files for them. Builder Sans, Foundation's font, is
	rarely installed, so it's the UI font without Roblox Studio's.
]]
Instances.fontSubstitutes = {
	["Builder Sans"] = "",
} :: {[string]: string}

--[[
	Font weights shown as another, for an app that wants Foundation's text
	lighter or heavier than its styles make it, such as {Bold = "Regular"}.
	Set it before the interface is made. Icons keep their weights.
]]
Instances.weightSubstitutes = {} :: {[string]: string}

local ICON_FAMILY = "BuilderIcons"

--[[
	BuilderIcons draws its icons from their names with font ligatures, which
	Luwow's text can't do. With Roblox Studio's BuilderIcons fonts, an icon is
	its own character in them. Without, it's a glyph of the platform's icon
	font: Segoe MDL2 Assets on Windows, or a plain Unicode symbol. Icons
	without one show nothing.
]]
local hasIconFont = fs.exists("C:/Windows/Fonts/segmdl2.ttf")
local ICON_FONT = if hasIconFont then "Segoe MDL2 Assets" else ""
local ICON_GLYPHS: {[string]: {number}} = {
	["check"] = {0xE73E, 0x2713},
	["chevron-large-down"] = {0xE70D, 0x2304},
	["chevron-small-down"] = {0xE70D, 0x2304},
	["chevron-large-up"] = {0xE70E, 0x2303},
	["chevron-small-up"] = {0xE70E, 0x2303},
	["chevron-large-left"] = {0xE76B, 0x2039},
	["chevron-small-left"] = {0xE76B, 0x2039},
	["chevron-large-right"] = {0xE76C, 0x203A},
	["chevron-small-right"] = {0xE76C, 0x203A},
	["x"] = {0xE711, 0x2715},
	["x-small"] = {0xE711, 0x2715},
	["minus"] = {0xE738, 0x2212},
	["plus-large"] = {0xE710, 0x002B},
	["plus-small"] = {0xE710, 0x002B},
	["magnifying-glass"] = {0xE721, 0x2315},
	["pencil"] = {0xE70F, 0x270E},
	["trash-can"] = {0xE74D, 0x2716},
	["two-stacked-squares"] = {0xE8C8, 0x2750},
	["paper-airplane"] = {0xE724, 0x27A4},
	["text-b-bold"] = {0xE8DD, 0x0042},
	["arrow-up-right-from-square"] = {0xE8A7, 0x2197},
	["circle-i"] = {0xE946, 0x2139},
	["triangle-exclamation"] = {0xE7BA, 0x26A0},
	["eye"] = {0xE7B3, 0x25C9},
}

local function faceFamily(face: any): string?
	if typeof(face) == "string" then
		return face
	elseif typeof(face) == "table" and typeof(face.Family) == "string" then
		return face.Family
	end
	return nil
end

local function iconGlyph(name: any): string
	if typeof(name) ~= "string" then
		return ""
	end
	local character = RobloxContent.iconCharacter(name)
	if character ~= nil then
		return character
	end
	local glyph = ICON_GLYPHS[name]
	if glyph == nil then
		return ""
	end
	return utf8.char(if hasIconFont then glyph[1] else glyph[2])
end

--[[
	A Luwow Font and FontStyle from a Roblox-like font: a family, a weight and a
	style. Luwow's styles have Bold and Italic, so other weights than Regular
	and Bold name their own family, the way Windows lists them, such as
	"Segoe UI Light". The platform's UI font only takes Bold.
]]
local function luwowFont(face: any): (string?, string?)
	if typeof(face) == "string" then
		return Instances.fontSubstitutes[face] or face, nil
	elseif typeof(face) ~= "table" or typeof(face.Family) ~= "string" then
		return nil, nil
	end
	local weight = face.Weight or "Regular"
	if face.Family == ICON_FAMILY then
		return RobloxContent.iconFamily(weight == "Bold") or ICON_FONT, "Regular"
	end
	weight = Instances.weightSubstitutes[weight] or weight
	local family = face.Family
	if not RobloxContent.loadFamily(family) then
		family = Instances.fontSubstitutes[family] or family
	end
	local bold = weight == "Bold"
	if not bold and weight ~= "Regular" and family ~= "" then
		family ..= " " .. weight
	end
	local italic = face.Style == "Italic"
	local style = if bold and italic then "BoldItalic" elseif bold then "Bold" elseif italic then "Italic" else "Regular"
	return family, style
end

local SCALE_TYPES = {Stretch = "Stretch", Fit = "Fit", Crop = "Crop", Slice = "Slice", Tile = "Tile"}

local WHITE = Color.new(1, 1, 1)

type Group = {
	inputs: {string},
	outputs: {string},
	compute: (...any) -> ...any,
}

local function same(value: any): any
	return value
end

local function rename(robloxName: string, luwowName: string, convert: ((any) -> any)?): Group
	return {inputs = {robloxName}, outputs = {luwowName}, compute = convert or same}
end

--[[
	A Luwow color made from a Roblox color and its transparency. The Luwow
	property set on its own wins, when its name isn't the Roblox color's. Other
	outputs take the same color, such as a TextButton's HoverColor, since
	Foundation draws its own hover and press states.
]]
local function colorGroup(output: string, colorName: string, transparencyName: string?, default: any, others: {string}?): Group
	local outputs = {output}
	for _, other in others or {} do
		table.insert(outputs, other)
	end
	local ownName = if output ~= colorName then output else nil
	return {
		inputs = {colorName, transparencyName or colorName, ownName or colorName},
		outputs = outputs,
		compute = function(color, transparency, luwowColor)
			local result
			if ownName ~= nil and luwowColor ~= nil then
				result = luwowColor
			elseif color ~= nil or (transparencyName ~= nil and transparency ~= nil) then
				result = withTransparency(color, if transparencyName then transparency else nil, default)
			end
			local results = table.create(#outputs, result)
			return table.unpack(results, 1, #outputs)
		end,
	}
end

local function vectorOffset(size: any): any
	if typeof(size) == "UDim2" then
		return vector.create(size.X.Offset, size.Y.Offset, 0)
	end
	return size
end

local GROUPS: {Group} = {
	colorGroup("BackgroundColor", "BackgroundColor3", "BackgroundTransparency", DEFAULT_BACKGROUND, {"HoverColor", "PressedColor"}),
	colorGroup("BorderColor", "BorderColor3", "BackgroundTransparency", DEFAULT_TEXT),
	colorGroup("TextColor", "TextColor3", "TextTransparency", DEFAULT_TEXT),
	colorGroup("PlaceholderColor", "PlaceholderColor3", nil, DEFAULT_PLACEHOLDER),
	colorGroup("ScrollBarColor", "ScrollBarImageColor3", "ScrollBarImageTransparency", DEFAULT_SCROLLBAR),
	{
		inputs = {"FontFace", "Font", "FontStyle"},
		outputs = {"Font", "FontStyle"},
		compute = function(face, font, fontStyle)
			local family, style = luwowFont(if face ~= nil then face else font)
			if typeof(fontStyle) == "string" then
				style = fontStyle
			end
			return family, style
		end,
	},
	{
		inputs = {"Text", "FontFace", "Font"},
		outputs = {"Text"},
		compute = function(text, face, font)
			if faceFamily(if face ~= nil then face else font) == ICON_FAMILY then
				return iconGlyph(text)
			end
			return text
		end,
	},
	rename("BorderSizePixel", "BorderWidth"),
	rename("TextXAlignment", "TextAlignment"),
	rename("CanvasSize", "ContentSize", vectorOffset),
	rename("CanvasPosition", "ScrollPosition"),
	colorGroup("ImageColor", "ImageColor3", "ImageTransparency", WHITE),
	rename("TextInputType", "TextInputType", function(value)
		return if value == "Password" then "Password" elseif value == nil then nil else "Default"
	end),
	rename("TextTruncate", "Truncated", function(value)
		return if value == nil then nil else value ~= "None"
	end),
	rename("ScaleType", "ScaleType", function(value)
		return SCALE_TYPES[value] or value
	end),
}

local STROKE_GROUPS: {Group} = {
	colorGroup("Color", "Color", "Transparency", DEFAULT_STROKE),
	rename("Thickness", "Thickness", function(value)
		return if typeof(value) == "number" then math.max(0, math.round(value)) else value
	end),
	rename("BorderStrokePosition", "StrokePosition"),
}

local function keypoints(value: any): any
	if typeof(value) == "table" and value.Keypoints ~= nil then
		return value.Keypoints
	end
	return value
end

local GRADIENT_GROUPS: {Group} = {
	rename("Color", "Color", keypoints),
	rename("Transparency", "Transparency", keypoints),
}

local function index(groups: {Group}): {[string]: {Group}}
	local byInput = {}
	for _, group in groups do
		for _, input in group.inputs do
			byInput[input] = byInput[input] or {}
			if not table.find(byInput[input], group) then
				table.insert(byInput[input], group)
			end
		end
	end
	return byInput
end
local GROUPS_BY_INPUT = index(GROUPS)
local CLASS_GROUPS_BY_INPUT: {[string]: {[string]: {Group}}} = {
	Stroke = index(STROKE_GROUPS),
	Gradient = index(GRADIENT_GROUPS),
}

type Pointer = {
	hovered: boolean,
	pressed: boolean,
	interactable: boolean,
	state: string,
	changed: {() -> ()},
	activated: {(...any) -> ()},
}

type Record = {
	class: string,
	explicit: {[string]: any},
	styled: {[string]: any},
	defaults: {[string]: any},
	original: {[string]: {value: any}},
	pointer: Pointer?,
	requested: {[string]: boolean}?,
}

--[[
	Instance -> its record. A stand-in keeps its own under a private key, as
	records refer to their instances (Luau's weak keys aren't ephemerons, so a
	weak table would keep them alive). Luwow objects Fusion didn't make, such
	as windows, are in a weak table.
]]
local RECORD = table.freeze({})
local objectRecords: {[any]: Record} = setmetatable({}, {__mode = "k"}) :: any
local records: {[any]: Record} = setmetatable({}, {
	__index = function(_, instance: any): Record?
		return if type(instance) == "table" then rawget(instance, RECORD) else objectRecords[instance]
	end,
	__newindex = function(_, instance: any, record: Record?)
		if type(instance) == "table" then
			rawset(instance, RECORD, record)
		else
			objectRecords[instance] = record
		end
	end,
}) :: any

local function recordOf(instance: any): Record
	local record = records[instance]
	if record == nil then
		record = {
			class = runtime.className(instance),
			explicit = {},
			styled = {},
			defaults = {},
			original = {},
			pointer = nil,
		}
		records[instance] = record
	end
	return record
end

local function merged(record: Record, name: string): any
	local value = record.explicit[name]
	if value == nil then
		value = record.styled[name]
	end
	if value == nil then
		value = record.defaults[name]
	end
	return value
end

local function setLuwow(instance: any, record: Record, name: string, value: any)
	local allowed = PROPERTIES[record.class]
	if allowed == nil or not allowed[name] then
		return
	end
	if value == nil then
		local original = record.original[name]
		if original == nil then
			return
		end
		value = original.value
		record.original[name] = nil
	elseif record.original[name] == nil then
		local ok, current = pcall(runtime.getProperty, instance, name)
		record.original[name] = {value = if ok then current else nil}
	end
	pcall(runtime.setProperty, instance, name, value)
end

local function applyGroup(instance: any, record: Record, group: Group)
	local values = {}
	for index, input in group.inputs do
		values[index] = merged(record, input)
	end
	local results = table.pack(group.compute(table.unpack(values, 1, #group.inputs)))
	for index, output in group.outputs do
		setLuwow(instance, record, output, results[index])
	end
end

local IMAGE_PROPERTIES = {"Image", "HoverImage", "PressedImage"}
local IMAGE_INPUTS = {Image = true, HoverImage = true, PressedImage = true, ImageRectOffset = true, ImageRectSize = true, SliceCenter = true}

local applyImages

local function luwowImage(instance: any, record: Record, content: any): any
	if content == nil then
		return nil
	elseif typeof(content) ~= "string" then
		return ""
	end
	local localPath = RobloxContent.localImage(content)
	if localPath ~= nil then
		return localPath
	end
	if RobloxAssets.parse(content) == nil then
		return if string.match(content, "^rbx") then "" else content
	end
	local cached = RobloxAssets.cachedPath(content)
	if cached ~= nil then
		return cached
	end
	record.requested = record.requested or {}
	if not record.requested[content] then
		record.requested[content] = true
		RobloxAssets.request(content, function(path)
			if path ~= nil and records[instance] == record then
				applyImages(instance, record)
			end
		end)
	end
	return ""
end

local function extentOf(offset: any, size: any, slice: any): vector
	local x, y = 0, 0
	if typeof(offset) == "vector" and typeof(size) == "vector" then
		x, y = offset.X + size.X, offset.Y + size.Y
	end
	if typeof(slice) == "Rect" then
		x, y = math.max(x, slice.X + slice.Width), math.max(y, slice.Y + slice.Height)
	end
	return vector.create(x, y, 0)
end

function applyImages(instance: any, record: Record)
	for _, name in IMAGE_PROPERTIES do
		setLuwow(instance, record, name, luwowImage(instance, record, merged(record, name)))
	end

	local offset = merged(record, "ImageRectOffset")
	local size = merged(record, "ImageRectSize")
	local slice = merged(record, "SliceCenter")
	local scale, shift = 1, vector.create(0, 0, 0)
	local image = merged(record, "Image")
	if typeof(image) == "string" and RobloxContent.localImage(image) == nil and (offset ~= nil or size ~= nil or slice ~= nil) then
		local imageScale, imageShift = RobloxAssets.imageScale(image, extentOf(offset, size, slice))
		if imageScale ~= nil then
			scale, shift = imageScale, imageShift
		end
	end

	setLuwow(instance, record, "ImageRectOffset", if typeof(offset) == "vector" then offset * scale + shift else offset)
	setLuwow(instance, record, "ImageRectSize", if typeof(size) == "vector" then size * scale else size)
	if typeof(slice) == "Rect" and scale ~= 1 then
		slice = LuwowRect.new(math.round(slice.X * scale), math.round(slice.Y * scale), math.round(slice.Width * scale), math.round(slice.Height * scale))
	end
	setLuwow(instance, record, "SliceCenter", slice)
end

local function update(instance: any, record: Record, names: {string})
	local byInput = CLASS_GROUPS_BY_INPUT[record.class] or GROUPS_BY_INPUT
	local done = {}
	for _, name in names do
		local groups = byInput[name]
		if IMAGE_INPUTS[name] then
			if not done.images then
				done.images = true
				applyImages(instance, record)
			end
		elseif groups ~= nil then
			for _, group in groups do
				if not done[group] then
					done[group] = true
					applyGroup(instance, record, group)
				end
			end
		else
			setLuwow(instance, record, name, merged(record, name))
		end
	end
end

local function updatePointerState(record: Record)
	local pointer = record.pointer :: Pointer
	local state = if not pointer.interactable then "NonInteractable"
		elseif pointer.pressed then "Press"
		elseif pointer.hovered then "Hover"
		else "Idle"
	if state ~= pointer.state then
		pointer.state = state
		for _, callback in table.clone(pointer.changed) do
			callback()
		end
	end
end

local NATIVE_ACTIVATION = {TextButton = true, ImageButton = true}

local function isInside(instance: any, position: vector): boolean
	local ok, frame = pcall(runtime.getProperty, instance, "AbsoluteFrame")
	return ok and frame ~= nil and frame:Contains(position)
end

--[[
	Follows the pointer over and on a control, for its GuiState and an
	Activated made from a press let go on it.
]]
local function pointerOf(instance: any): Pointer
	local record = recordOf(instance)
	if record.pointer ~= nil then
		return record.pointer
	end
	local interactable = merged(record, "Interactable")
	local pointer: Pointer = {
		hovered = false,
		pressed = false,
		interactable = interactable ~= false,
		state = if interactable == false then "NonInteractable" else "Idle",
		changed = {},
		activated = {},
	}
	record.pointer = pointer

	local function on(event: string, handler: (...any) -> ())
		pcall(runtime.connectEvent, instance, event, handler)
	end
	on("OnEnter", function()
		pointer.hovered = true
		updatePointerState(record)
	end)
	on("OnLeft", function()
		pointer.hovered = false
		updatePointerState(record)
	end)
	on("OnPressed", function()
		pointer.pressed = true
		updatePointerState(record)
	end)
	on("OnUnPressed", function(position: vector)
		local wasPressed = pointer.pressed
		pointer.pressed = false
		updatePointerState(record)
		if wasPressed and pointer.interactable and not NATIVE_ACTIVATION[record.class] and isInside(instance, position) then
			for _, callback in table.clone(pointer.activated) do
				task.spawn(callback)
			end
		end
	end)
	return pointer
end

local function connectList(list: {any}, callback: any): () -> ()
	table.insert(list, callback)
	return function()
		local index = table.find(list, callback)
		if index ~= nil then
			table.remove(list, index)
		end
	end
end

--[[
	Sets an explicit Roblox property of an instance, as Foundation's code does
	with instance.BackgroundColor3 = color on Roblox.
]]
function Instances.set(instance: any, property: string, value: any)
	local record = recordOf(instance)
	record.explicit[property] = value
	if property == "Interactable" or property == "Active" then
		if record.pointer ~= nil then
			record.pointer.interactable = value ~= false
			updatePointerState(record)
		end
		return
	end
	update(instance, record, {property})
end

local LIVE_READS: {[string]: string} = {
	CanvasPosition = "ScrollPosition",
	AbsoluteWindowSize = "AbsoluteSize",
	AbsoluteCanvasSize = "ContentSize",
	TextBounds = "AbsoluteSize",
}

local UNSUPPORTED_READS: {[string]: any} = {
	CursorPosition = -1,
	SelectionStart = -1,
}

function Instances.get(instance: any, property: string): any
	local live = LIVE_READS[property]
	if live ~= nil then
		local ok, current = pcall(runtime.getProperty, instance, live)
		if ok then
			return current
		end
	end
	if UNSUPPORTED_READS[property] ~= nil then
		return UNSUPPORTED_READS[property]
	end
	local value = merged(recordOf(instance), property)
	if value ~= nil then
		return value
	end
	local ok, current = pcall(runtime.getProperty, instance, property)
	return if ok then current else nil
end

Instances.getStyled = Instances.get

--[[
	Replaces the styled Roblox properties of an instance, for LuwowStyler. Its
	Luwow properties, such as AspectRatio for a ::UIAspectRatioConstraint
	rule, can be given the same way.
]]
function Instances.setStyled(instance: any, properties: {[string]: any})
	local record = recordOf(instance)
	local changed = {}
	for name in record.styled do
		if properties[name] == nil then
			table.insert(changed, name)
		end
	end
	for name, value in properties do
		if record.styled[name] ~= value then
			table.insert(changed, name)
		end
	end
	record.styled = table.clone(properties)
	update(instance, record, changed)
end

function Instances.getGuiState(instance: any): string
	return pointerOf(instance).state
end

function Instances.connectGuiState(instance: any, callback: () -> ()): () -> ()
	return connectList(pointerOf(instance).changed, callback)
end

local CHANGES: {[string]: string} = {
	CanvasPosition = "ScrollPosition",
	AbsoluteWindowSize = "AbsoluteSize",
	AbsoluteCanvasSize = "ContentSize",
}

function Instances.captureFocus(instance: any)
	runtime.getProperty(instance, "Focus")(instance)
end

function Instances.releaseFocus(instance: any)
	runtime.getProperty(instance, "ReleaseFocus")(instance)
end

function Instances.isFocused(instance: any): boolean
	return runtime.getProperty(instance, "Focused") == true
end

function Instances.isInstance(value: any): boolean
	return runtime.isInstance(value)
end

--[[
	A signal like Roblox's GetPropertyChangedSignal, for a Roblox property of an
	instance. Objects of Foundation's own, such as a MeasurableObject, use
	theirs.
]]
function Instances.getPropertyChangedSignal(instance: any, property: string): any
	if not runtime.isInstance(instance) and type(instance.GetPropertyChangedSignal) == "function" then
		return instance:GetPropertyChangedSignal(property)
	end
	return {
		Connect = function(_, callback: () -> ())
			local disconnect
			if property == "GuiState" then
				disconnect = Instances.connectGuiState(instance, callback)
			else
				local ok, result = pcall(runtime.connectPropertyChanged, instance, CHANGES[property] or property, callback)
				disconnect = if ok then result else nil
			end
			return {
				Disconnect = function()
					if disconnect ~= nil then
						disconnect()
						disconnect = nil
					end
				end,
			}
		end,
	}
end

local EVENTS: {[string]: (instance: any, callback: (...any) -> ()) -> (() -> ())?} = {}

local function luwowEvent(event: string, adapt: ((...any) -> ...any)?)
	return function(instance: any, callback: (...any) -> ())
		local handler = if adapt then function(...)
			callback(adapt(...))
		end else callback
		local ok, disconnect = pcall(runtime.connectEvent, instance, event, handler)
		return if ok then disconnect else nil
	end
end

local function inputObject(state: string)
	return function(input: any)
		return table.freeze({
			UserInputType = input.InputType,
			UserInputState = state,
			Position = vector.create(input.Position.x, input.Position.y, 0),
			KeyCode = "Unknown",
		})
	end
end

EVENTS.Activated = function(instance, callback)
	if NATIVE_ACTIVATION[recordOf(instance).class] then
		return luwowEvent("OnActivated")(instance, callback)
	end
	return connectList(pointerOf(instance).activated, callback)
end
EVENTS.MouseButton1Click = EVENTS.Activated
EVENTS.MouseEnter = luwowEvent("OnEnter", function(position)
	return position.x, position.y
end)
EVENTS.MouseLeave = luwowEvent("OnLeft", function(position)
	return position.x, position.y
end)
EVENTS.MouseButton1Down = luwowEvent("OnPressed", function(position)
	return position.x, position.y
end)
EVENTS.MouseButton1Up = luwowEvent("OnUnPressed", function(position)
	return position.x, position.y
end)
EVENTS.InputBegan = luwowEvent("OnInputBegan", inputObject("Begin"))
EVENTS.InputEnded = luwowEvent("OnInputEnded", inputObject("End"))
EVENTS.SecondaryActivated = function(instance, callback)
	local pressed = false
	local began = luwowEvent("OnInputBegan")(instance, function(input: any)
		if input.InputType == "MouseButton2" then
			pressed = true
		end
	end)
	local ended = luwowEvent("OnInputEnded")(instance, function(input: any)
		if input.InputType ~= "MouseButton2" or not pressed then
			return
		end
		pressed = false
		if isInside(instance, input.Position) then
			callback()
		end
	end)
	return function()
		if began then
			began()
		end
		if ended then
			ended()
		end
	end
end
EVENTS.MouseButton2Click = EVENTS.SecondaryActivated
EVENTS.FocusLost = function(instance, callback)
	local lost = luwowEvent("OnFocusLost", function()
		return false
	end)(instance, callback)
	local submitted = luwowEvent("OnSubmitted", function()
		return true
	end)(instance, callback)
	return function()
		if lost then
			lost()
		end
		if submitted then
			submitted()
		end
	end
end
EVENTS.Focused = function(instance, callback)
	return runtime.connectPropertyChanged(instance, "Focused", function()
		if runtime.getProperty(instance, "Focused") then
			callback()
		end
	end)
end


local eventKeys: {[any]: string} = {}
local changeKeys: {[any]: string} = {}
local outKeys: {[any]: string} = {}
local UNSUPPORTED_EVENTS = {
	"SecondaryActivated", "InputChanged", "DragStart", "DragContinue", "DragEnd", "MouseMoved", "MouseWheelForward",
	"MouseWheelBackward", "SelectionGained", "SelectionLost", "TouchTap", "MouseButton2Click", "ReturnPressedFromOnScreenKeyboard",
}
for name in EVENTS do
	eventKeys[OnEvent(name)] = name
end
for _, name in UNSUPPORTED_EVENTS do
	eventKeys[OnEvent(name)] = name
end

local dropped: {[string]: boolean} = {}

Instances.dropped = dropped

--[[
	Connects to a Roblox event of an instance, such as InputBegan, as
	instance.InputBegan:Connect does. Returns a connection with Disconnect, or
	nil when Luwow has nothing for the event.
]]
function Instances.connectEvent(instance: any, event: string, callback: (...any) -> ()): any
	local make = EVENTS[event]
	local disconnect = if make then make(instance, callback) else nil
	if disconnect == nil then
		dropped["event " .. event] = true
		return nil
	end
	return {
		Disconnect = function()
			if disconnect ~= nil then
				disconnect()
				disconnect = nil
			end
		end,
	}
end

local function keyName(key: any, cache: {[any]: string}, make: (string) -> any, candidates: {string}): string?
	local name = cache[key]
	if name ~= nil then
		return name
	end
	for _, candidate in candidates do
		if make(candidate) == key then
			cache[key] = candidate
			return candidate
		end
	end
	return nil
end

local FOLLOWED = {
	"AbsoluteSize", "AbsolutePosition", "AbsoluteFrame", "AbsoluteWindowSize", "AbsoluteCanvasSize",
	"AbsoluteContentSize", "CanvasPosition", "ScrollPosition", "ContentSize", "Text", "Visible", "Focused",
	"CursorPosition", "TextBounds", "GuiState", "Size", "Position", "ImageSize",
}

--[[
	Applies a Roblox property table to an instance: properties go to its
	record, and special keys to Fusion, the events and changes Luwow names
	differently translated. Parent goes last, once everything else is set.
]]
local function apply(scope: any, instance: any, props: {[any]: any})
	local record = recordOf(instance)
	local special = {}
	local parent = nil
	local names = {}

	for key, value in props do
		if typeof(key) == "string" then
			if key == "Parent" then
				parent = value
			elseif isState(value) then
				local state = value
				table.insert(scope, Fusion.Observer(scope, state):onBind(function()
					Instances.set(instance, key, peek(state))
				end))
			else
				record.explicit[key] = value
				table.insert(names, key)
				if key == "Interactable" or key == "Active" then
					Instances.set(instance, key, value)
				end
			end
		elseif typeof(key) == "table" and key.type == "SpecialKey" then
			if key.kind == "OnEvent" then
				local name = eventKeys[key]
				local make = if name ~= nil then EVENTS[name] else nil
				if make ~= nil then
					local disconnect = make(instance, value)
					if disconnect ~= nil then
						table.insert(scope, disconnect)
					end
				else
					dropped["event " .. tostring(name or "?")] = true
				end
			elseif key.kind == "OnChange" then
				local name = keyName(key, changeKeys, OnChange, FOLLOWED)
				if name == "GuiState" then
					table.insert(scope, Instances.connectGuiState(instance, function()
						value(Instances.getGuiState(instance))
					end))
					continue
				end
				local luwowName = if name ~= nil then CHANGES[name] or name else nil
				local callback = value
				local disconnect = if luwowName ~= nil
					then runtime.connectPropertyChanged(instance, luwowName, function()
						callback(runtime.getProperty(instance, luwowName), instance)
					end)
					else nil
				if disconnect ~= nil then
					table.insert(scope, disconnect)
				else
					dropped["change " .. tostring(name or "?")] = true
				end
			elseif key.kind == "Out" then
				local name = keyName(key, outKeys, Out, FOLLOWED)
				local luwowName = if name ~= nil then CHANGES[name] or name else nil
				if luwowName ~= nil then
					special[Out(luwowName)] = value
				else
					dropped["out " .. tostring(name or "?")] = true
				end
			else
				special[key] = value
			end
		end
	end

	update(instance, record, names)
	if next(special) ~= nil then
		Fusion.Hydrate(scope, instance)(special)
	end
	if parent ~= nil then
		Fusion.Hydrate(scope, instance)({Parent = parent})
	end
	return instance
end

local GUI_DEFAULTS = table.freeze({
	Size = UDim2.new(0, 0, 0, 0),
	BackgroundColor3 = DEFAULT_BACKGROUND,
	BackgroundTransparency = 0,
	BorderColor3 = DEFAULT_TEXT,
	BorderSizePixel = 1,
	ClipsDescendants = false,
})

local function textDefaults(text: string, extra: {[string]: any}?): {[string]: any}
	local defaults = table.clone(GUI_DEFAULTS)
	defaults.Text = text
	defaults.TextColor3 = DEFAULT_TEXT
	defaults.TextSize = 14
	defaults.TextXAlignment = "Center"
	for name, value in extra or {} do
		defaults[name] = value
	end
	return table.freeze(defaults)
end

local DEFAULTS: {[string]: {[string]: any}} = {
	Frame = GUI_DEFAULTS,
	CanvasGroup = GUI_DEFAULTS,
	ImageLabel = GUI_DEFAULTS,
	ImageButton = GUI_DEFAULTS,
	ScrollingFrame = GUI_DEFAULTS,
	TextLabel = textDefaults("Label", {MultiLine = true}),
	TextButton = textDefaults("Button", {MultiLine = true}),
	TextBox = textDefaults("", {FocusedBorderColor = false}),
}

--[[
	Makes an instance of a Roblox class, or of a Luwow one. Classes Luwow has
	nothing for, such as UIGradient, make nothing.
]]
function Instances.New(scope: any, className: string)
	return function(props: {[any]: any}): any
		local class = CLASSES[className]
		if class == nil then
			dropped["class " .. className] = true
			return nil
		end
		local instance = Fusion.New(scope, class)({})
		local defaults = DEFAULTS[className] or {}
		local record: Record = {
			class = class,
			explicit = {},
			styled = {},
			defaults = defaults,
			original = {},
			pointer = nil,
		}
		records[instance] = record
		local names = {}
		for name in defaults do
			table.insert(names, name)
		end
		update(instance, record, names)
		return apply(scope, instance, props)
	end
end

function Instances.Hydrate(scope: any, instance: any)
	return function(props: {[any]: any}): any
		if instance == nil then
			return nil
		end
		return apply(scope, instance, props)
	end
end

return table.freeze(Instances)
