local PackageManager = require("../../PackageManager")

local BuilderIcons = PackageManager.getPackage("BuilderIcons")
local migrationLookUp = BuilderIcons.Migration

type IconVariant = typeof(BuilderIcons.IconVariant)

local function migrateIconName(name: string): { name: string, variant: IconVariant? } | nil
	return migrationLookUp["uiblox"][name]
end

return migrateIconName
