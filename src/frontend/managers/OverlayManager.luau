const Types = require("@Frontend/Types")

type Scope = Types.Scope

-- Foundation renders popovers, such as a dropdown's menu, on one overlay. Each window has its own, and
-- the one of the window in use is given to Foundation.
local OverlayManager = {}

local overlayProvider: { instance: any?, screen: any? }? = nil
local mainOverlay: any? = nil
local activeOverlay: any? = nil

--// Module Functions

-- Registers the main window's overlay, the one Foundation was initialized with
function OverlayManager.initialize(provider: { instance: any?, screen: any? }, overlay: any)
	overlayProvider = provider
	mainOverlay = overlay
	activeOverlay = overlay
end

function OverlayManager.isInitialized(): boolean
	return overlayProvider ~= nil
end

-- Foundation renders floating content on this overlay from now on
function OverlayManager.activate(overlay: any)
	if not overlayProvider or activeOverlay == overlay then
		return
	end

	activeOverlay = overlay
	overlayProvider.instance = overlay
	overlayProvider.screen = overlay
end

-- To be called when a window closes: if its overlay was the active one, the main window's is again
function OverlayManager.release(overlay: any)
	if activeOverlay ~= overlay or not mainOverlay or overlay == mainOverlay then
		return
	end
	OverlayManager.activate(mainOverlay)
end

return OverlayManager
