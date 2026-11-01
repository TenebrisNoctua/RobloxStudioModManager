local PackageManager = require("../PackageManager")

local Dash = PackageManager.getPackage("Dash")

local Tokens = require("../Providers/ThemeProvider/Tokens")
local Types = require("./Rules/Types")
local formatTokens = require("./formatTokens")

type Tokens = Tokens.Tokens
type RulesGenerator = Types.RulesGenerator

local function generateRules(tokens: Tokens, rulesGenerator: RulesGenerator)
	local formattedTokens = formatTokens(tokens)
	local common, size, theme = rulesGenerator(tokens, formattedTokens)
	local rules = Dash.joinArrays(common, size, theme)

	return rules, common, size, theme
end

return generateRules
