export type MockServices = {
	ContentProvider: { [any]: any }?,
	CoreGui: { [any]: any }?,
	GuiService: { [any]: any }?,
	HttpService: { [any]: any }?,
	LocalizationService: { [any]: any }?,
	Players: { [any]: any }?,
	RunService: { [any]: any }?,
	TextService: { [any]: any }?,
	UserInputService: { [any]: any }?,
}

local isLuwow = require("../isLuwow")

if isLuwow then
	return require("../Luwow/Services")
end

local Services = {
	ContentProvider = game:GetService("ContentProvider"),
	CoreGui = game:GetService("CoreGui"),
	GuiService = game:GetService("GuiService"),
	HttpService = game:GetService("HttpService"),
	LocalizationService = game:GetService("LocalizationService"),
	Players = game:GetService("Players"),
	RunService = game:GetService("RunService"),
	TextService = game:GetService("TextService"),
	UserInputService = game:GetService("UserInputService"),
}

return Services
