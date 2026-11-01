const Color = require("@Luwow/color")
const UDim2 = require("@Luwow/udim2")
const system = require("@Luwow/os")

const Packages = require("@Frontend/Packages")
const Types = require("@Frontend/Types")

const Foundation = Packages.Foundation
const IS_MAC = system.platform() == "macos"

local Style = {
	-- The window backdrop, and the text on it
	BACKGROUND = { Color3 = Color.fromRGB(32, 32, 32), Transparency = 0 },
	TEXT = { Color3 = Color.new(1, 1, 1), Transparency = 0 },
	FADED_TEXT = { Color3 = Color.new(1, 1, 1), Transparency = 0.4 },
	-- BorderBrush="Gray" lines
	GRAY = { Color3 = Color.fromRGB(128, 128, 128), Transparency = 0 },

	-- The platform font, Segoe UI on Windows like WinUI's, San Francisco on macOS
	BODY_FONT = { Family = "", Weight = "Regular", Style = "Normal" },
	SEMIBOLD_FONT = { Family = "", Weight = "SemiBold", Style = "Normal" },
	LIGHT_FONT = { Family = if IS_MAC then "HelveticaNeue-Light" else "Segoe UI", Weight = "Light", Style = "Normal" },
	MONO_FONT = { Family = if IS_MAC then "Menlo" else "Consolas", Weight = "Regular", Style = "Normal" },

	-- WinUI's TextBlock default
	BODY_SIZE = 14,

	ICON = "assets/Icon.ico",
	LOGO = "assets/logo.png"
}

type Scope = Types.Scope

--[[
	Left aligned body text, white, one line of its font size
	unless props say otherwise.
]]
function Style.Text(scope: Scope, text: any, props: { [string]: any }?): any
	local fontSize = (props and props.FontSize) or Style.BODY_SIZE
	local textProps: { [string]: any } = {
		scope = scope,
		Text = text,
		Size = UDim2.new(1, 0, 0, math.ceil(fontSize * 1.4)),
		TextXAlignment = "Left",
		fontStyle = { Font = (props and props.Font) or Style.BODY_FONT, FontSize = fontSize },
		textStyle = Style.TEXT,
	}
	for key, value in props or {} do
		if key ~= "FontSize" and key ~= "Font" then
			textProps[key] = value
		end
	end
	return Foundation.Text(textProps)
end

return Style
