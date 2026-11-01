local PackageManager = require("../PackageManager")

local BuilderIcons = PackageManager.getPackage("BuilderIcons")

local getBuilderIconForCurrentPlatform = BuilderIcons.getBuilderIconForCurrentPlatform

return getBuilderIconForCurrentPlatform
