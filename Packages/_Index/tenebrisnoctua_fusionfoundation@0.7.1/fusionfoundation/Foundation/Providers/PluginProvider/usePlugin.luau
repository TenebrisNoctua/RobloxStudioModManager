local PluginContext = require(script.Parent.PluginContext)
local isPluginElevated = require("./isPluginElevated")

local function usePlugin(): (Plugin?, boolean)
	local plugin = PluginContext:now()
	if plugin then
		return plugin, isPluginElevated(plugin)
	end
	return nil, false
end

return usePlugin