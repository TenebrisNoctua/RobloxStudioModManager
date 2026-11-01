local LocalizationService = require("../Wrappers").Services.LocalizationService
local GuiService = require("../Wrappers").Services.GuiService

local Constants = require("./Constants")
local GeneratedTranslations = require("../../Generated/Translations/GeneratedTranslations")
local isLuwow = require("../isLuwow")

--[[
	Luwow has no LocalizationTable, so the translations are looked up by key,
	falling back to English. Arguments fill in the {name} parts of the text,
	like a Roblox Translator does.
]]
if isLuwow then
	local entries: {[string]: {[string]: string}} = {}
	for _, entry in GeneratedTranslations do
		entries[entry.Key] = entry.Values
	end

	local function format(key: string, locale: string, args: any): string
		local values = entries[key]
		if values == nil then
			error(`Translation key {key} not found`, 3)
		end
		local text = values[locale] or values["en-us"] or key
		if args ~= nil then
			text = string.gsub(text, "{([%w_]+)}", function(name)
				local value = args[name]
				return if value ~= nil then tostring(value) else nil
			end)
		end
		return text
	end

	local LuwowTranslator = {}

	function LuwowTranslator:FormatByKey(key: string, args: any)
		return format(key, LocalizationService.RobloxLocaleId, args)
	end

	function LuwowTranslator:FormatByKeyForLocale(key: string, locale: string, args: any)
		return format(key, locale, args)
	end

	return LuwowTranslator
end

local function createFoundationLocalizationTable(parent)
	local existingLocalizationTable = GuiService:FindFirstChild(Constants.LOCALIZATION_TABLE_NAME)
	if existingLocalizationTable ~= nil and existingLocalizationTable:IsA("LocalizationTable") then
		-- Overwrites the existing translations with this set
		existingLocalizationTable:SetEntries(GeneratedTranslations)
		return
	end

	local FoundationLocalizationTable = Instance.new("LocalizationTable")
	FoundationLocalizationTable.Name = Constants.LOCALIZATION_TABLE_NAME
	FoundationLocalizationTable.Archivable = false
	FoundationLocalizationTable.SourceLocaleId = "en-us"
	FoundationLocalizationTable:SetEntries(GeneratedTranslations)
	FoundationLocalizationTable.Parent = parent
end

createFoundationLocalizationTable(GuiService)

local FALLBACK_ENGLISH_TRANSLATOR = (
	GuiService:FindFirstChild(Constants.LOCALIZATION_TABLE_NAME) :: LocalizationTable
):GetTranslator("en-us") :: Translator

local translatorsCache: {[string]: Translator} = {}

local function getTranslatorForLocale(locale: string)
	local translator = translatorsCache[locale]
	if translator then return translator end

	translator = (GuiService:FindFirstChild(Constants.LOCALIZATION_TABLE_NAME) :: LocalizationTable):GetTranslator(
		locale
	) :: Translator
	
	translatorsCache[locale] = translator

	return translator
end

local function getTranslator()
	return getTranslatorForLocale(LocalizationService.RobloxLocaleId)
end

local function formatByKeyWithFallback(key: string, args: any, translator: Translator): string
	local success, result = pcall(function()
		return translator:FormatByKey(key, args)
	end)

	if success then
		return result
	elseif translator.LocaleId == "zh-cjv" then
		return ""
	else
		return FALLBACK_ENGLISH_TRANSLATOR:FormatByKey(key, args)
	end
end

local RobloxTranslator = {}

function RobloxTranslator:FormatByKey(key: string, args: any)
	return formatByKeyWithFallback(key, args, getTranslator())
end

function RobloxTranslator:FormatByKeyForLocale(key: string, locale: string, args: any)
	return formatByKeyWithFallback(key, args, getTranslatorForLocale(locale))
end

return RobloxTranslator
