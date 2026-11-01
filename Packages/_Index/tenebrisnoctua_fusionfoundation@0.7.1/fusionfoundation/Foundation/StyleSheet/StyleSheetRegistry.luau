--[[
The StyleSheet Registry is a shared registry for StyleSheets outside of React/Fusion.
Currently it's scoped to the Foundation module, meaning any consumer of this module
will share the same registry. If there are multiple instances of Foundation, they will
not share the same registry, and StyleSheets will not be shared between them.

The API this module returns is not bound to a module level, meaning in the future we are
able to move the registry to a more global scope by using the DataModel as the source of truth.

For now this was avoided to keep the change less disruptive, simpler, and likely much faster.
Reading the DataModel to get state for every operation can be very slow, especially on Android.
]]
local isLuwow = require("../Utility/isLuwow")
local Foundation = if isLuwow then nil else script.Parent.Parent
local Device = require("../Enums/Device")
local Theme = require("../Enums/Theme")
local Types = require("./Rules/Types")

type Theme = Theme.Theme
type Device = Device.Device
type StyleRuleNoTag = Types.StyleRuleNoTag

local getGeneratedRules = require("../Utility/getGeneratedRules")
local scaleValue = require("../Utility/scaleValue")

local FoundationDisableTokenScaling = false

local registryFolder = nil :: Folder?
if not isLuwow then
	registryFolder = Instance.new("Folder")
	registryFolder.Name = "FoundationStyleSheets"
	registryFolder.Parent = Foundation
end

--[[
	A sheet on Luwow: the rules LuwowStyler applies, with the scale its tokens
	use, in place of a StyleSheet instance.
]]
local function createLuwowSheet(theme: Theme, device: Device, scale: number, rules: { [string]: StyleRuleNoTag }): any
	return {
		Name = `{theme}-{device}-{scale}`,
		rules = rules,
		scale = if FoundationDisableTokenScaling then 1 else scale,
		Destroy = function() end,
	}
end

type FoundationStyleSheet = {
	theme: Theme,
	device: Device,
	scale: number,
	instance: StyleSheet,
	tags: { [string]: boolean },
	rules: { [string]: StyleRuleNoTag },
	attributes: { [string]: boolean },
}

local styleSheetRegistry: { [StyleSheet]: FoundationStyleSheet } = {}

local function createStyleSheet(theme: Theme, deviceInput: Device?, scaleInput: number?): FoundationStyleSheet
	local device: Device = deviceInput or Device.Desktop
	local scale = scaleInput or 1
	local rules = getGeneratedRules(theme, device)

	local styleSheet
	if isLuwow then
		styleSheet = createLuwowSheet(theme, device, scale, rules)
	else
		styleSheet = Instance.new("StyleSheet")
		styleSheet.Name = `{theme}-{device}-{scale}`
		styleSheet.Parent = registryFolder
	end

	return {
		theme = theme,
		device = device,
		scale = scale,
		instance = styleSheet,
		tags = {},
		rules = rules,
		attributes = {},
	}
end

local function createStyleRule(rule: StyleRuleNoTag, tag: string): StyleRule
	local tagSelector = "." .. tag
	local modifier = if rule.modifier ~= nil then ":" .. rule.modifier else ""
	local pseudo = if rule.pseudo ~= nil then " ::" .. rule.pseudo else ""
	local selector = tagSelector .. modifier .. pseudo

	if rule.pseudo ~= nil then
		selector = selector .. ", " .. tagSelector .. modifier .. " > " .. rule.pseudo
	end

	local styleRule = Instance.new("StyleRule")
	styleRule.Name = selector
	styleRule.Priority = rule.priority or 1
	styleRule.Selector = selector
	styleRule:SetProperties(rule.properties)
	return styleRule
end

local function applyAttributes(sheet: FoundationStyleSheet, attributes: { Types.StyleAttribute<unknown> }?)
	if not attributes then
		return
	end

	for _, attribute in attributes do
		if sheet.attributes[attribute.name] then
			continue
		end

		local scaledValue = if FoundationDisableTokenScaling
			then attribute.value
			else scaleValue(attribute.value, sheet.scale)
		sheet.attributes[attribute.name] = true
		sheet.instance:SetAttribute(attribute.name, scaledValue)
	end
end

local function addRegisteredStyleSheetTags(sheet: FoundationStyleSheet, tags: { string })
	if isLuwow then
		for _, tag in tags do
			sheet.tags[tag] = true
		end
		return
	end

	for _, tag in tags do
		if sheet.tags[tag] then
			continue
		end
		local rule = sheet.rules[tag]
		if not rule then
			continue
		end

		local styleRule = createStyleRule(rule, tag)
		styleRule.Parent = sheet.instance
		applyAttributes(sheet, rule.attributes)
		if rule.children then
			for _, child in rule.children do
				local childRule = createStyleRule(child, child.tag)
				childRule.Parent = sheet.instance
				applyAttributes(sheet, child.attributes)
			end
		end
		sheet.tags[tag] = true
	end
end

local function getStyleSheet(theme: Theme, deviceInput: Device?, scaleInput: number?): StyleSheet
	local device: Device = deviceInput or Device.Desktop
	local scale = scaleInput or 1
	for instance, foundationStyleSheet in styleSheetRegistry do
		if
			foundationStyleSheet.theme == theme
			and foundationStyleSheet.device == device
			and foundationStyleSheet.scale == scale
		then
			return instance
		end
	end
	local foundationStyleSheet = createStyleSheet(theme, device, scale)
	styleSheetRegistry[foundationStyleSheet.instance] = foundationStyleSheet
	return foundationStyleSheet.instance
end

local function addStyleTags(sheet: StyleSheet, tags: { string })
	local foundationStyleSheet = styleSheetRegistry[sheet]
	if not foundationStyleSheet then
		error("StyleSheet not found in registry")
	end
	addRegisteredStyleSheetTags(foundationStyleSheet, tags)
end

local function removeRegistryFolder()
	if registryFolder then
		registryFolder:Destroy()
	end
end

--[[ Example consumer usage with signals:
local getStyleSheet = createComputed(function(scope)
	return Foundation.getStyleSheet(theme(scope), device(scope), scale(scope))
end)

local dispose = createEffect(function(scope)
	local sheet = getStyleSheet(scope)
	local tags = getTags(scope) -- some tags signals someone wants

	Foundation.addStyleTags(sheet, tags) -- potentially errors if sheet is not found in the registry/cache
end)

dispose()
]]

return {
	getStyleSheet = getStyleSheet,
	addStyleTags = addStyleTags,
	removeRegistryFolder = removeRegistryFolder
}
