-- Written by @TenebrisNoctua
-- Handles panel functionality for plugins.

local PopoverManager = require("@self/Managers/PopoverManager")
local ProviderTypes = require("@self/Types")

local StudioUri = require("../Utility/Plugin/StudioUri")
local Types = require("../Utility/Types")

local PluginProvider = require("./PluginProvider")

local panelsProvider = {
	popoverManager = nil :: PopoverManager.PopoverManager
}

type Child = Types.Child
type PanelsContext = ProviderTypes.PanelsContext
type PanelPosition = ProviderTypes.PanelPosition
type StudioUri = StudioUri.StudioUri

type PanelsProviderProps = {
	uriScope: string?
}

type panelsProvider = typeof(panelsProvider)

--// Main Functions

function panelsProvider.registerPopoverAsync(
	self: panelsProvider,
	anchorUri: StudioUri,
	position: PanelPosition,
	onClose: () -> (),
	depth: number?,
	parentPopoverId: string?
)
	local handle = self.popoverManager:openAtAsync({
		targetWidgetUri = anchorUri,
		targetAnchorPoint = position.targetAnchorPoint,
		subjectAnchorPoint = position.subjectAnchorPoint,
		offset = position.offset,
	}, onClose, depth, parentPopoverId)

	return handle, function()
		handle.close()
	end
end

return function(props: PanelsProviderProps?): (panelsProvider, () -> ()?)
	if panelsProvider.popoverManager then return panelsProvider end
	
	local pluginProvider = PluginProvider()
	if not pluginProvider then
		error("[FusionFoundation]: PanelsProvider must be used after initializing PluginProvider!")
	end
	
	local newPopoverManager = PopoverManager.new(pluginProvider.plugin, props.uriScope)
	panelsProvider.popoverManager = newPopoverManager
	
	return panelsProvider, function()
		newPopoverManager:destroy()
	end
end