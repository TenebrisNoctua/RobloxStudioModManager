local Instances = require("./Utility/Luwow/Instances")
local New = Instances.New
local PackageManager = require("./PackageManager")

local Fusion = PackageManager.getPackage("Fusion")

local RuleTypes = require("@self/Rules/Types")
local createStyleSheetRules = require("@self/createStyleSheetRules")
local isLuwow = require("./Utility/isLuwow")
local LuwowStyler = if isLuwow then require("@self/Luwow/LuwowStyler") else nil

local useGeneratedRules = require("./Utility/useGeneratedRules")
local unwrap = require("./Utility/unwrap")
local Types = require("./Utility/Types")

local Device = require("./Enums/Device")
local Theme = require("./Enums/Theme")

local Children = Fusion.Children

type Theme = Theme.Theme
type Device = Device.Device

type StyleAttribute<T> = RuleTypes.StyleAttribute<T>
type StyleRule = RuleTypes.StyleRule
type AttributesCache = createStyleSheetRules.AttributesCache

type UsedAs<T> = Types.UsedAs<T>
type Scope = Types.Scope
type Use = Types.Use

type StyleSheetProps = {
	scope: Scope,
	theme: UsedAs<Theme>,
	device: UsedAs<Device>,
	scale: UsedAs<number?>,
	tags: UsedAs<{ [string]: boolean }>,
	derives: UsedAs<{ StyleSheet }?>?,
	setStyleSheetRef: { current: ((StyleSheet?) -> ()) | nil }?,
}

local FoundationDisableStyleProviderDerives = false

local function LuwowStyleSheet(props: StyleSheetProps)
	local scope = props.scope
	local rules = useGeneratedRules(scope, props.theme, props.device)

	local sheet = scope:Computed(function(use: Use)
		local currentRules = unwrap(rules, use) or {}
		local currentTags = unwrap(props.tags, use) or {}
		local tagged = {}
		for tag in currentTags do
			tagged[tag] = currentRules[tag]
		end
		return {
			rules = tagged,
			scale = unwrap(props.scale, use) or 1,
			Destroy = function() end,
		}
	end)

	local styler = (LuwowStyler :: any).new(Fusion.Runtime)
	local function link()
		local currentSheet = unwrap(sheet)
		styler:setSheet(currentSheet)
		if props.setStyleSheetRef and props.setStyleSheetRef.current then
			props.setStyleSheetRef.current(currentSheet)
		end
	end
	link()
	scope:Observer(sheet):onChange(link)
	table.insert(scope, function()
		styler:Destroy()
	end)

	return {
		FoundationStyleSheet = sheet,
		FoundationStyleLink = styler,
	}
end

local function StyleSheet(props: StyleSheetProps)
	if LuwowStyler then
		return LuwowStyleSheet(props)
	end
	local scope = props.scope

	local sheet = scope:Value(nil :: StyleSheet?)
	local attributesCache = {} :: AttributesCache

	local rules = useGeneratedRules(scope, props.theme, props.device)

	scope:Observer(sheet):onChange(function()
		local currentSheet = unwrap(sheet)
		if props.setStyleSheetRef and props.setStyleSheetRef.current then
			props.setStyleSheetRef.current(currentSheet)
		end
	end)

	local derivesTracker = scope:Computed(function(use: Use)
		return {unwrap(sheet, use), unwrap(props.derives, use)}
	end)

	scope:Observer(derivesTracker):onChange(function()
		local currentSheet = unwrap(sheet)
		if currentSheet and not FoundationDisableStyleProviderDerives then
			local currentDerives = unwrap(props.derives)
			currentSheet:SetDerives((currentDerives or {}) :: { Instance })
		end
	end)

	local styleRules = scope:Computed(function(use: Use)
		local currentSheet = unwrap(sheet, use)
		if currentSheet then
			return createStyleSheetRules(
				unwrap(rules, use),
				unwrap(props.tags, use),
				currentSheet,
				attributesCache,
				unwrap(props.scale, use)
			)
		else
			return nil
		end
	end)

	local foundationStyleSheet = sheet:set(New(scope, "StyleSheet") {
		[Children] = styleRules,
	})

	local foundationStyleLink = New(scope, "StyleLink") {
		StyleSheet = sheet,
	}

	return {
		FoundationStyleSheet = foundationStyleSheet,
		FoundationStyleLink = foundationStyleLink,
	}
end

return StyleSheet