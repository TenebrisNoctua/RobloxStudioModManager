local UDim2 = require("@Luwow/udim2")

local Packages = require("@Frontend/Packages")
local Types = require("@Frontend/Types")

local Foundation = Packages.Foundation

local Loading = Foundation.Loading
local View = Foundation.View
local ThemeProvider = Foundation.ThemeProvider

local unwrap = Foundation.Utility.unwrap

-- The ring's size, against IconSize.XLarge's
local RING_SCALE = 0.85

--// Types

type Scope = Types.Scope
type UsedAs<T> = Types.UsedAs<T>

--// Return Constructor

return function(scope: Scope, busy: UsedAs<boolean>): any
	local tokens = ThemeProvider().Tokens

	return View {
		scope = scope,
		Name = "LoadingRing",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 500,
		Visible = busy,
		onActivated = function() end,
		stateLayer = { affordance = "None" },
		children = {
			Ring = Loading {
				scope = scope,
				size = scope:Computed(function(use)
					return math.round(unwrap(tokens, use).Size.Size_2400 * RING_SCALE)
				end),
				AnchorPoint = vector.create(0.5, 0.5, 0),
				Position = UDim2.fromScale(0.5, 0.5),
				isDisabled = scope:Computed(function(use)
					return not unwrap(busy, use)
				end),
			}
		}
	}
end
