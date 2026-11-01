local getGeneratedRules = require("./getGeneratedRules")
local unwrap = require("./unwrap")
local Types = require("./Types")

local Device = require("../Enums/Device")
local Theme = require("../Enums/Theme")

type UsedAs<T> = Types.UsedAs<T>
type Scope = Types.Scope
type Use = Types.Use

type Theme = Theme.Theme
type Device = Device.Device

local function useGeneratedRules(scope: Scope, theme: UsedAs<Theme>, device: UsedAs<Device>): UsedAs<any>
	return scope:Computed(function(use: Use): any
		local currentTheme: Theme = unwrap(theme, use)
		local currentDevice: Device = unwrap(device, use)
		return getGeneratedRules(currentTheme, currentDevice)
	end)
end

return useGeneratedRules