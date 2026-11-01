local Datatypes = require("../../Utility/Luwow/Datatypes")
local UDim, Enum = Datatypes.UDim, Datatypes.Enum
local Instances = require("../../Utility/Luwow/Instances")
local New = Instances.New

local PackageManager = require("../../PackageManager")

local Fusion = PackageManager.getPackage("Fusion")
local Dash = PackageManager.getPackage("Dash")

local unwrap = require("../../Utility/unwrap")
local Types = require("../../Utility/Types")

local StoryMiddleware = require("../../Utility/Stories/StoryMiddleware")
local StorySection = require("../../Utility/Stories/StorySection")
local CommonControls = require("../../Utility/Stories/CommonControls")

local InputSize = require("../../Enums/InputSize")
local InputLabelSize = require("../../Enums/InputLabelSize")

local View = require("../View")
local BaseTextInput = require("../BaseTextInput")
local InputField = require("../InputField")

type Scope = Types.Scope
type Use = Types.Use

local function InputFieldStory(props: {
	scope: Scope,
	controls: any,
	layoutOrder: number?,
})
	local scope = props.scope
	local controls = props.controls

	local text = scope:Value("")

	local function handleChange(newText: string)
		text:set(newText)
	end

	return InputField {
		scope = scope,
		label = controls.label,
		size = controls.labelSize,
		hint = controls.hint,
		hasError = controls.hasError,
		isDisabled = controls.isDisabled,
		LayoutOrder = props.layoutOrder,
		input = function(childScope: Scope, textBoxRef)
			return BaseTextInput {
				scope = childScope,
				textBoxRef = textBoxRef,
				text = text,
				hasError = controls.hasError,
				isDisabled = controls.isDisabled,
				size = controls.size,
				onChanged = handleChange,
				placeholder = controls.placeholder
			}
		end,
	}
end

return {
	fusion = Fusion,
	summary = "Input field",
	controls = {
		label = "Field label",
		hint = "Hint",
		hasError = false,
		isDisabled = false,
		size = {
			EntryType = "Control",
			Type = "Choose",
			ControlValue = Dash.values(InputSize)[1],
			List = Dash.values(InputSize),
			DefIndex = 1,
		},
		labelSize = {
			EntryType = "Control",
			Type = "Choose",
			ControlValue = Dash.values(InputLabelSize)[1],
			List = Dash.values(InputLabelSize),
			DefIndex = 1,
		},
		placeholder = "Placeholder text",
		theme = CommonControls.theme,
	},
	story = StoryMiddleware(function(props)
		local scope = props.scope
		local controls = props.controls

		return scope:Computed(function(use: Use, innerScope: Scope)
			unwrap(controls.theme, use)

			return View {
				scope = innerScope,
				tag = "auto-xy padding-x-large padding-top-large",
				children = {
					New(innerScope, "UIListLayout") {
						Padding = UDim.new(0, 16),
						SortOrder = Enum.SortOrder.LayoutOrder,
					},

					StorySection {
						scope = innerScope,
						title = "Playground",
						layoutOrder = 1,
						children = {
							InputFieldStory {
								scope = innerScope,
								controls = controls,
								layoutOrder = 2,
							},
						},
					},
				},
			}
		end)
	end),
}
