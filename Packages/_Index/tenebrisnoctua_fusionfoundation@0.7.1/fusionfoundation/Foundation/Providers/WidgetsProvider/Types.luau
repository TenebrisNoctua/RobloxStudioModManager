local StudioUri = require("../../Utility/Plugin/StudioUri")

local WidgetManager = require("./WidgetManager")

type StudioUri = StudioUri.StudioUri

export type WidgetManager = WidgetManager.WidgetManager

export type WidgetsContext = {
	register: (uri: StudioUri, gui: GuiBase2d) -> (),
	deregister: (uri: StudioUri, gui: GuiBase2d?) -> (),
	nextId: () -> string,
}

export type WidgetsProvider = setmetatable<{
	widgetManager: WidgetManager?,
	register: (uri: StudioUri, gui: GuiBase2d) -> (),
	deregister: (uri: StudioUri, gui: GuiBase2d?) -> (),
	nextId: () -> string	
}, {__index: {}}>

return nil