--!nonstrict

local PackageManager = require("../../PackageManager")

local Fusion = PackageManager.getPackage("Fusion")

local HintText = require("../HintText")
local View = require("../View")

local ThemeProvider = require("../../Providers/ThemeProvider")

local function StoryPlayground(props)
	local controls = props.controls

	return HintText {
		scope = props.scope,
		text = controls.text,
		hasError = controls.hasError,
		isDisabled = controls.isDisabled
	}
end

return { 
	fusion = Fusion,
	summary = "Helper text put below inputs",
	controls = {
		text = "Helper text",
		hasError = false,
		isDisabled = false
	},
	story = function(props)
		local scope = props.scope
		local theme, cleanup = ThemeProvider()
		table.insert(scope, cleanup)

		return View {
			scope = scope,
			tag = "auto-xy",
			children = {
				StoryPlayground {
					scope = scope,
					controls = props.controls
				},
				theme.StyleLink
			}
		}
	end
}