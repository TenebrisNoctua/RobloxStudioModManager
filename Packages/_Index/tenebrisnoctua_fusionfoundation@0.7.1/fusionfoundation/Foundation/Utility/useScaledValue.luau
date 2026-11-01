local Types = require("./Types")
local unwrap = require("./unwrap")

local ThemeProvider = require("../Providers/ThemeProvider")

type Use = Types.Use

local function useScaledValue(value: number, use: Use?): number
	local themeProvider = ThemeProvider()
	local tokens = unwrap(themeProvider.Tokens, use)
	local scaledValue = value * tokens.Config.UI.Scale

	if scaledValue <= tokens.Size.Size_3000 then
		print( -- This can be converted back to Logger Utility if Lumberyak is added as a package.
			"[FusionFoundation]: useScaledValue should be used for values larger than Size tokens. "
				.. "For smaller values, please align to a Size or derivative token."
		)
	end

	return scaledValue
end

return useScaledValue
