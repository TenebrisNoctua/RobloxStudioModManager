local PackageManager = require("../../PackageManager")

local BuilderIcons = PackageManager.getPackage("BuilderIcons")

local endAlignedIcons: { [string]: true } = {
	[BuilderIcons.Icon.ArrowUpRightFromSquare] = true,
}

return endAlignedIcons
