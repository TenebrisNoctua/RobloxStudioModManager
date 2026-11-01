local PackageManager = require("../PackageManager")

local Fusion = PackageManager.getPackage("Fusion")
local Dash = PackageManager.getPackage("Dash")

local Types = require("./Types")
local unwrap = require("./unwrap")

type UsedAs<T> = Types.UsedAs<T>
type Scope = Types.Scope
type Use = Types.Use
type Tags = Types.Tags

local function useDefaultTags(scope: Scope, tags: UsedAs<Tags?>, defaults: UsedAs<string>): UsedAs<Tags>
	return scope:Computed(function(use: Use)
		local currentTags = unwrap(tags, use)
		local currentDefaults = unwrap(defaults, use)

		if currentTags == nil then
			return currentDefaults
		end

		if type(currentTags) == "string" then
			return `{currentDefaults} {currentTags}`
		else
			return Dash.join(currentTags, { [currentDefaults] = true })
		end
	end)
end

return useDefaultTags