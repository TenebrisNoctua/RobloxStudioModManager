--!nonstrict
local Datatypes = require("../../Utility/Luwow/Datatypes")
local UDim, Enum = Datatypes.UDim, Datatypes.Enum
local Instances = require("../../Utility/Luwow/Instances")
local New = Instances.New

local PackageManager = require("../../PackageManager")

local Fusion = PackageManager.getPackage("Fusion")

local View = require("../View")
local Text = require("../Text")

local unwrap = require("../../Utility/unwrap")
local StorySection = require("../../Utility/Stories/StorySection")
local ControlState = require("../../Enums/ControlState")

local ThemeProvider = require("../../Providers/ThemeProvider")

type ControlState = ControlState.ControlState

local function Story(props)
	local Scope = props.scope
	
	return Text {
		scope = Scope,
		Text = props.text,
		tag = "auto-xy content-default",
		fontStyle = {
			FontSize = props.textSize,
		},
		LayoutOrder = props.layoutOrder
	}
end

local function StoryGuiState(props)
	local Scope = props.scope
	local Theme = ThemeProvider()
	local tokens = unwrap(Theme.Tokens)

	local guiState = Scope:Value(ControlState.Initialize)
	local function onStateChanged(new: ControlState)
		guiState:set(new)
	end
	
	return Text {
		scope = Scope,
		Text = Scope:Computed(function(use)
			return "State: " .. use(guiState)
		end),
		tag = "col align-x-center align-y-center size-2800 content-default",
		fontStyle = {
			FontSize = 20,
		},
		backgroundStyle = tokens.Color.Extended.Purple.Purple_500,
		onStateChanged = onStateChanged,
		LayoutOrder = props.layoutOrder
	}
end

return { 
	fusion = Fusion,
	controls = {
		text = "Hello, world!",
		textSize = 24
	},
	story = function(props)
		local scope = props.scope
		local text = props.controls.text
		local textSize = props.controls.textSize
		
		local theme, cleanup = ThemeProvider()
		table.insert(scope, cleanup)

		return View {
			scope = scope,
			backgroundStyle = {
				Transparency = 1
			},
			children = {
				New(scope, "UIListLayout") {
					Padding = UDim.new(0, 16),
					SortOrder = Enum.SortOrder.LayoutOrder
				},
				
				StorySection {
					scope = scope,
					title = "Basic Text",
					children = {
						Story {
							scope = scope,
							text = text,
							textSize = textSize,
							layoutOrder = 2
						}
					}
				},
				
				StorySection {
					scope = scope,
					title = "GUI State Use",
					layoutOrder = 2,
					children = {
						StoryGuiState {
							scope = scope,
							text = text,
							textSize = textSize,
							layoutOrder = 2
						}
					}
				},
				
				theme.StyleLink
			}
		}
	end
}