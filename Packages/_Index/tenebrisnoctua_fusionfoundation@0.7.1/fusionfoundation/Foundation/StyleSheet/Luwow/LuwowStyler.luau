--!strict

--[[
	Applies Foundation's style rules on Luwow, in place of Roblox's styling
	engine.

	On Roblox, Foundation turns its rules into StyleRule instances in a
	StyleSheet, tags instances with CollectionService, and the engine matches
	them, making pseudo-instances such as ::UICorner itself. Luwow has no
	styling engine, so the styler does the matching: it follows the tags of
	Fusion's Luwow runtime, and for each tagged instance it merges the rules
	of its tags and sets the results itself. Pseudo-instances become real
	objects, see LuwowProperties.

	Rules with the hover modifier apply while the pointer is over the
	instance, following its OnEnter and OnLeft events, and ones with the
	press (or pressed, or active) modifier while it's pressed, following
	OnPressed and OnUnPressed.

	The instance's own properties go to Foundation's Luwow instances, which
	merge them with the ones set explicitly, these winning like on Roblox.
	Properties a rule stops setting go back to the value they had before it,
	and pseudo-instances no rule asks for anymore are destroyed.
]]

local UDim = require("@Luwow/udim")
local UDim2 = require("@Luwow/udim2")

local LuwowProperties = require("./LuwowProperties")
local Instances = require("../../Utility/Luwow/Instances")

type Properties = LuwowProperties.Properties

export type Rule = {
	tag: string?,
	modifier: string?,
	pseudo: string?,
	priority: number?,
	properties: Properties,
	attributes: {{name: string, value: any}}?,
	children: {Rule}?
}

export type Sheet = {
	rules: {[string]: Rule},
	scale: number?
}

type Entry = {
	rule: Rule,
	tag: string,
	order: number
}

type Helper = {
	instance: any,
	properties: Properties
}

type InstanceStyle = {
	hovered: boolean,
	pressed: boolean,
	helpers: {[string]: Helper},
	disconnects: {() -> ()}?
}

export type Styler = {
	runtime: any,
	setSheet: (self: Styler, sheet: Sheet?) -> (),
	restyle: (self: Styler, instance: any) -> (),
	Destroy: (self: Styler) -> ()
}

local LuwowStyler = {}
LuwowStyler.__index = LuwowStyler

local function modifierActive(
	modifier: string?,
	style: InstanceStyle
): boolean
	if modifier == nil then
		return true
	end
	local name = string.lower(modifier)
	if name == "hover" then
		return style.hovered
	elseif name == "press" or name == "pressed" or name == "active" then
		return style.pressed
	end
	return false
end

local function scaleValue(
	value: any,
	scale: number
): any
	if scale == 1 then
		return value
	end
	local kind = typeof(value)
	if kind == "number" then
		return value * scale
	elseif kind == "UDim" then
		return UDim.new(value.Scale, value.Offset * scale)
	elseif kind == "UDim2" then
		return UDim2.new(value.X.Scale, value.X.Offset * scale, value.Y.Scale, value.Y.Offset * scale)
	end
	return value
end

local function equal(
	a: any,
	b: any
): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for key, value in a do
		if not equal(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

local function lacksAny(
	old: Properties,
	new: Properties
): boolean
	for name in old do
		if new[name] == nil then
			return true
		end
	end
	return false
end

function LuwowStyler.styleOf(
	self: any,
	instance: any
): InstanceStyle?
	if type(instance) == "table" then
		return rawget(instance, self.styleKey)
	end
	return self.objectStyles[instance]
end

function LuwowStyler.setStyle(
	self: any,
	instance: any,
	style: InstanceStyle?
)
	if type(instance) == "table" then
		rawset(instance, self.styleKey, style)
	else
		self.objectStyles[instance] = style
	end
	self.styled[instance] = if style ~= nil then true else nil
end

--[[
	Makes a styler working with Fusion's Luwow runtime provider (Fusion.Runtime).
]]
function LuwowStyler.new(
	runtime: any
): Styler
	local self = setmetatable({
		runtime = runtime,
		sheet = nil :: Sheet?,
		index = {} :: {[string]: {Entry}},
		tokens = {} :: {[string]: any},
		styleKey = table.freeze({}),
		styled = setmetatable({}, {__mode = "k"}) :: {[any]: true},
		objectStyles = setmetatable({}, {__mode = "k"}) :: {[any]: InstanceStyle},
		stopTags = nil :: (() -> ())?,
	}, LuwowStyler)

	self.stopTags = runtime.tags.onChanged(function(instance: any)
		self:restyle(instance)
	end)

	return self :: any
end

--[[
	Uses the sheet's rules from now on, and styles every tagged instance with
	them. nil removes every style.
]]
function LuwowStyler.setSheet(
	self: any,
	sheet: Sheet?
)
	self.sheet = sheet
	self.index = {}
	self.tokens = {}

	if sheet ~= nil then
		local scale = sheet.scale or 1
		local order = 0
		local function add(tag: string, rule: Rule)
			order += 1
			local entries = self.index[tag]
			if entries == nil then
				entries = {}
				self.index[tag] = entries
			end
			table.insert(entries, {rule = rule, tag = tag, order = order})
			for _, attribute in rule.attributes or {} do
				self.tokens[attribute.name] = scaleValue(attribute.value, scale)
			end
		end

		local tags = {}
		for tag in sheet.rules do
			table.insert(tags, tag)
		end
		table.sort(tags)
		for _, tag in tags do
			local rule = sheet.rules[tag]
			add(tag, rule)
			for _, child in rule.children or {} do
				add(child.tag or tag, child)
			end
		end
	end

	local instances = self.runtime.tags.getAllTagged()
	for instance in self.styled do
		table.insert(instances, instance)
	end
	for _, instance in instances do
		self:restyle(instance)
	end
end

function LuwowStyler.resolve(
	self: any,
	value: any
): any
	if typeof(value) == "string" and string.sub(value, 1, 1) == "$" then
		return self.tokens[string.sub(value, 2)]
	end
	return value
end

local function isAlive(
	runtime: any,
	instance: any
): boolean
	local ok, destroyed = pcall(runtime.getProperty, instance, "Destroyed")
	return ok and destroyed ~= true
end

local function setProperty(
	runtime: any,
	instance: any,
	name: string,
	value: any
)
	pcall(runtime.setProperty, instance, name, value)
end

function LuwowStyler.listen(
	self: any,
	instance: any,
	style: InstanceStyle
)
	if style.disconnects ~= nil then
		return
	end
	style.disconnects = {}

	local reference = setmetatable({instance}, {__mode = "v"})
	local function on(event: string, field: "hovered" | "pressed", value: boolean)
		local ok, disconnect = pcall(self.runtime.connectEvent, instance, event, function()
			local target = reference[1]
			if target == nil or style[field] == value then
				return
			end
			style[field] = value
			self:restyle(target)
		end)
		if ok and disconnect ~= nil then
			table.insert(style.disconnects :: {() -> ()}, disconnect)
		end
	end
	on("OnEnter", "hovered", true)
	on("OnLeft", "hovered", false)
	on("OnPressed", "pressed", true)
	on("OnUnPressed", "pressed", false)
end

function LuwowStyler.applyHelpers(
	self: any,
	instance: any,
	style: InstanceStyle,
	desired: {[string]: Properties}
)
	local runtime = self.runtime
	for class, properties in desired do
		local helper = style.helpers[class]
		if helper ~= nil and lacksAny(helper.properties, properties) then
			pcall(runtime.destroy, helper.instance)
			style.helpers[class] = nil
			helper = nil
		end

		if helper == nil then
			local object = runtime.newInstance(class)
			if object == nil then
				continue
			end
			for name, value in properties do
				setProperty(runtime, object, name, value)
			end
			runtime.setParent(object, instance)
			style.helpers[class] = {instance = object, properties = table.clone(properties)}
		else
			for name, value in properties do
				if not equal(helper.properties[name], value) then
					setProperty(runtime, helper.instance, name, value)
					helper.properties[name] = value
				end
			end
		end
	end

	for class, helper in table.clone(style.helpers) do
		if desired[class] == nil then
			pcall(runtime.destroy, helper.instance)
			style.helpers[class] = nil
		end
	end
end

--[[
	Works out the instance's styles again from its tags, its pointer state
	and the sheet's rules, and applies them.
]]
function LuwowStyler.restyle(
	self: any,
	instance: any
)
	local runtime = self.runtime
	local style: InstanceStyle? = self:styleOf(instance)
	if not isAlive(runtime, instance) then
		self:setStyle(instance, nil)
		return
	end

	local entries: {Entry} = {}
	local hasStates = false
	for _, tag in runtime.tags.get(instance) do
		for _, entry in self.index[tag] or {} do
			table.insert(entries, entry)
			if entry.rule.modifier ~= nil then
				hasStates = true
			end
		end
	end

	if #entries == 0 and style == nil then
		return
	end
	if style == nil then
		style = {
			hovered = false,
			pressed = false,
			helpers = {},
			disconnects = nil
		}
		self:setStyle(instance, style)
	end
	local style = style :: InstanceStyle
	if hasStates then
		self:listen(instance, style)
	end

	local active = {}
	for _, entry in entries do
		if modifierActive(entry.rule.modifier, style) then
			table.insert(active, entry)
		end
	end
	table.sort(active, function(a: Entry, b: Entry): boolean
		local priorityA, priorityB = a.rule.priority or 1, b.rule.priority or 1
		if priorityA ~= priorityB then
			return priorityA < priorityB
		end
		local modifiedA, modifiedB = a.rule.modifier ~= nil, b.rule.modifier ~= nil
		if modifiedA ~= modifiedB then
			return modifiedB
		end
		return a.order < b.order
	end)

	local own: Properties = {}
	local pseudo: {[string]: Properties} = {}
	for _, entry in active do
		local target = own
		if entry.rule.pseudo ~= nil then
			target = pseudo[entry.rule.pseudo] or {}
			pseudo[entry.rule.pseudo] = target
		end
		for name, value in entry.rule.properties do
			local resolved = self:resolve(value)
			if resolved ~= nil then
				target[name] = resolved
			end
		end
	end

	local desired = table.clone(own)
	local helpers: {[string]: Properties} = {}
	for name, properties in pseudo do
		local kind = LuwowProperties.pseudo[name]
		if kind == nil then
			continue
		end
		local translated = kind.translate(properties)
		if kind.class ~= nil then
			helpers[kind.class] = translated
		else
			for property, value in translated do
				desired[property] = value
			end
		end
	end

	Instances.setStyled(instance, desired)
	self:applyHelpers(instance, style, helpers)

	if #entries == 0 then
		for _, disconnect in style.disconnects or {} do
			disconnect()
		end
		self:setStyle(instance, nil)
	end
end

--[[
	Stops following tags, and takes every style off.
]]
function LuwowStyler.Destroy(
	self: any
)
	if self.stopTags ~= nil then
		self.stopTags()
		self.stopTags = nil
	end
	self.sheet = nil
	self.index = {}
	for instance in table.clone(self.styled) do
		self:restyle(instance)
	end
end

return LuwowStyler
