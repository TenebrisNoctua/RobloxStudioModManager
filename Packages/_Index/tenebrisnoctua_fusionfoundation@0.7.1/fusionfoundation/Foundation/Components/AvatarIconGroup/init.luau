local Instances = require("../Utility/Luwow/Instances")
local Hydrate = Instances.Hydrate
local AvatarIcon = require("./AvatarIcon")
local BaseAvatarGroup = require("./BaseAvatarGroup")
local useAvatarIconVariants = require("./AvatarIcon/useAvatarIconVariants")

local unwrap = require("../Utility/unwrap")
local stripProps = require("../Utility/stripProps")
local withDefaults = require("../Utility/withDefaults")
local withCommonProps = require("../Utility/withCommonProps")
local Types = require("../Utility/Types")

local AvatarIconSize = require("../Enums/AvatarIconSize")
local AvatarGroupType = require("../Enums/AvatarGroupType")

local ThemeProvider = require("../Providers/ThemeProvider")

local COMPONENT_ONLY_PROPERTIES = {
	"type",
	"max",
	"size",
	"backplateStyle",
	"avatars"
}

local defaultProps = {
	type = AvatarGroupType.Spread,
	max = math.huge,
	size = AvatarIconSize.Medium
}

type UsedAs<T> = Types.UsedAs<T>
type Scope = Types.Scope
type Use = Types.Use

type AvatarIconSize = AvatarIconSize.AvatarIconSize
type AvatarGroupType = AvatarGroupType.AvatarGroupType

export type AvatarIconGroupProps = {
	type: UsedAs<AvatarGroupType>?,
	max: UsedAs<number>?,
	size: UsedAs<AvatarIconSize>?,
	backplateStyle: UsedAs<Types.ColorStyle>?,
	avatars: { UsedAs<number> },
} & Types.CommonProps

return function(avatarIconGroupProps: AvatarIconGroupProps)
	local scope = avatarIconGroupProps.scope
	local theme = ThemeProvider()
	assert(scope, "A scope has not been provided for the AvatarIconGroup component.")

	local props = withDefaults(avatarIconGroupProps, defaultProps)
	return scope:Computed(function(use: Use, innerScope: Scope)
		local tokens = unwrap(theme.Tokens, use)
		local size = unwrap(props.size, use)
		local type = unwrap(props.type, use)

		local variantProps = useAvatarIconVariants(unwrap(theme.Theme), tokens, size)
		local resolvedSize = variantProps.container.size

		local gap = if type == AvatarGroupType.Spread
			then tokens.Size.Size_200
			else if size == AvatarIconSize.Large or size == AvatarIconSize.Medium
				then -tokens.Size.Size_50
			else -tokens.Size.Size_0
		
		local function renderAvatarIcon(
			scope: Scope,
			avatarData: BaseAvatarGroup.AvatarData,
			layoutProps: BaseAvatarGroup.AvatarLayoutProps
		)
			return AvatarIcon {
				scope = scope,
				userId = avatarData,
				backgroundStyle = layoutProps.backgroundStyle,
				backplateStyle = layoutProps.backplateStyle,
				size = size,
				LayoutOrder = layoutProps.LayoutOrder,
				Position = layoutProps.Position,
				ZIndex = layoutProps.ZIndex
			}
		end

		return Hydrate(innerScope, BaseAvatarGroup(withCommonProps(props, {
			scope = innerScope,
			type = type,
			max = props.max,
			resolvedSize = resolvedSize,
			gap = gap,
			isEllipsedOverflow = true,
			backplateStyle = props.backplateStyle,
			avatars = props.avatars,
			renderAvatar = renderAvatarIcon
		})))(stripProps(props, COMPONENT_ONLY_PROPERTIES))
	end)
end