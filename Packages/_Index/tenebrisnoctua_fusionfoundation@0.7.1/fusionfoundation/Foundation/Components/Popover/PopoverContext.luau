local PackageManager = require("../../PackageManager")

local Fusion = PackageManager.getPackage("Fusion")

local Types = require("../../Utility/Types")
local StudioUri = require("../../Utility/Plugin/StudioUri")

type UsedAs<T> = Types.UsedAs<T>
type PopoverAnchor = Types.PopoverAnchor
type StudioUri = StudioUri.StudioUri

export type PopoverContextType = {
	anchor: UsedAs<PopoverAnchor?>,
	anchorUri: UsedAs<StudioUri?>,
	isOpen: UsedAs<boolean>,
	gui: UsedAs<Instance?>
}

return Fusion.Contextual(nil :: PopoverContextType?)
