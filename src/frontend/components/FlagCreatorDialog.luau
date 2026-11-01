const UDim = require("@Luwow/udim")
const UDim2 = require("@Luwow/udim2")

const Packages = require("@Frontend/Packages")
const Types = require("@Frontend/Types")
const Style = require("@Frontend/Style")

const Foundation = Packages.Foundation
const Datatypes = Packages.Datatypes

const Dropdown = Foundation.Dropdown
const TextInput = Foundation.TextInput
const View = Foundation.View

const InputSize = Foundation.Enums.InputSize
const InputVariant = Foundation.Enums.InputVariant

const unwrap = Foundation.Utility.unwrap

const WIDTH = 320

const CLASSES = { "F", "DF", "SF" }
const CLASS_ITEMS = {
	{ id = 1, text = "Fast (F)" },
	{ id = 2, text = "Dynamic Fast (DF)" },
	{ id = 3, text = "Synchronized Fast (SF)" },
}
const TYPE_ITEMS = {
	{ id = "Flag", text = "Flag" },
	{ id = "Int", text = "Int" },
	{ id = "Log", text = "Log" },
	{ id = "String", text = "String" },
}

--// Types

type Scope = Types.Scope

export type CustomFlag = {
	-- The class and type, such as "DFInt"
	Type: string,
	Name: string
}

-- The form's fields, made with its content
type FormStates = {
	Name: any,
	Class: any,
	Type: any,
	Error: any
}

export type FlagCreatorDialog = {
	-- Builds the form, a DialogWindow's Content
	Content: (scope: Scope) -> any,
	-- Checks the form and sets Result. False, with an error shown, when it isn't ready
	Validate: () -> boolean,
	Result: CustomFlag?
}

--// Local Functions

-- Foundation's inputs don't take a LayoutOrder, so each goes in a row that has one
local function createField(scope: Scope, order: number, input: any): any
	return View {
		scope = scope,
		LayoutOrder = order,
		tag = "size-full-0 auto-y",
		children = { input }
	}
end

-- The StackPanel of the Name, Class and Type fields, and the error under them
local function createForm(scope: Scope, states: FormStates): any
	return View {
		scope = scope,
		Name = "FlagCreatorDialog",
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Datatypes.Enum.AutomaticSize.Y,
		layout = {
			FillDirection = "Vertical",
			Padding = UDim.new(0, 12),
			SortOrder = "LayoutOrder",
		},
		children = {
			FlagNameBox = createField(scope, 1, TextInput {
				scope = scope,
				label = "Name:",
				text = states.Name,
				size = InputSize.Small,
				variant = InputVariant.Standard,
				width = UDim.new(1, 0),
				onChanged = function(text: string)
					states.Name:set(text)
				end,
			}),
			FlagClassBox = createField(scope, 2, Dropdown {
				scope = scope,
				label = "Class:",
				items = CLASS_ITEMS,
				value = states.Class,
				size = InputSize.Small,
				variant = InputVariant.Contrast,
				width = UDim.new(1, 0),
				onItemChanged = function(id)
					states.Class:set(id)
				end,
			}),
			FlagTypeBox = createField(scope, 3, Dropdown {
				scope = scope,
				label = "Type:",
				items = TYPE_ITEMS,
				value = states.Type,
				size = InputSize.Small,
				variant = InputVariant.Contrast,
				width = UDim.new(1, 0),
				onItemChanged = function(id)
					states.Type:set(id)
				end,
			}),
			ErrorText = Style.Text(scope, scope:Computed(function(use)
				return unwrap(states.Error, use) or ""
			end), {
				LayoutOrder = 4,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Datatypes.Enum.AutomaticSize.Y,
				TextWrapped = true,
				Visible = scope:Computed(function(use)
					return unwrap(states.Error, use) ~= nil
				end),
			}),
		},
	}
end

local function sanitizeName(text: string): string
	return (string.gsub(text, "[^A-z0-9_]", ""))
end

--// Return Constructor

return function(): FlagCreatorDialog
	local form: FlagCreatorDialog
	local states: FormStates

	local function content(scope: Scope): any
		states = {
			Name = scope:Value(""),
			Class = scope:Value(1),
			Type = scope:Value("Flag"),
			Error = scope:Value(nil :: string?),
		}
		return createForm(scope, states)
	end

	local function validate(): boolean
		const fullType = CLASSES[unwrap(states.Class)] .. unwrap(states.Type)
		const text = unwrap(states.Name)
		const name = sanitizeName(text)

		if text ~= name then
			states.Name:set(name)
		end

		if name == "" then
			states.Error:set(`Please enter a name for the {fullType}!`)
			return false
		end

		form.Result = { Type = fullType, Name = name }
		return true
	end

	form = {
		Content = content,
		Validate = validate,
		Result = nil
	}
	return form
end
