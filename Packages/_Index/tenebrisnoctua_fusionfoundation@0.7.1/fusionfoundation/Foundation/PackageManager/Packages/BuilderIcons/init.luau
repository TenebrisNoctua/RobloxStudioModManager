local Icon = require("@self/Icon")
export type Icon = Icon.Icon
local IconVariant = require("@self/IconVariant")
export type IconVariant = IconVariant.IconVariant
local Font = require("@self/Font")
local Migration = require("@self/Migration")
local builderIconPlatformUtils = require("@self/builderIconPlatformUtils")
local getBuilderIconForKeycode = builderIconPlatformUtils.getBuilderIconForKeycode
local getBuilderIconForCurrentPlatform = builderIconPlatformUtils.getBuilderIconForCurrentPlatform

return {
	Icon = Icon,
	IconVariant = IconVariant,
	Font = Font,
	Migration = Migration,
	getBuilderIconForKeycode = getBuilderIconForKeycode,
	getBuilderIconForCurrentPlatform = getBuilderIconForCurrentPlatform,
}
