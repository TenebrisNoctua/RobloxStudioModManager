local PackageManager = require("../../PackageManager")

local Fusion = PackageManager.getPackage("Fusion")

local Loading = require("../Loading")
local StoryMiddleware = require("../../Utility/Stories/StoryMiddleware")
local IconSize = require("../../Enums/IconSize")

local function Story(props)
	local scope = props.scope
	local controls = props.controls

	return Loading {
		scope = scope,
		size = controls.size,
		isDisabled = controls.isDisabled
	}
end

return {
	summary = "Loading component",
	fusion = Fusion,
	controls = {
		size = {
			EntryType = "Control",
			Type = "Choose",
			ControlValue = IconSize.Large,
			List = { IconSize.Large, IconSize.Medium, IconSize.Small },
			DefIndex = 1,
		},
		isDisabled = false,
	},
	story = StoryMiddleware(Story)
}
