-- Written by @TenebrisNoctua
-- The entry point of the Fusion Foundation library.

local PackageManager = require("@self/PackageManager")
local BuilderIcons = PackageManager.getPackage("BuilderIcons")
local Fusion = PackageManager.getPackage("Fusion")

local strict = require("@self/Utility/strict")
local Types = require("@self/Utility/Types")

local Tokens = require("@self/Providers/ThemeProvider/Tokens")
local StyleSheetRegistry = require("@self/StyleSheet/StyleSheetRegistry")

export type ActionProps = Types.ActionProps
export type AspectRatio = Types.AspectRatio
export type CommonProps = Types.CommonProps
export type FlexItem = Types.FlexItem
export type ListLayout = Types.ListLayout
export type Padding = Types.Padding
export type PopoverAnchor = Types.PopoverAnchor
export type Selection = Types.Selection
export type SelectionGroup = Types.SelectionGroup
export type StateChangedCallback = Types.StateChangedCallback
export type StateLayer = Types.StateLayer
export type Stroke = Types.Stroke
export type Tags = Types.Tags

-- Token types
export type ColorStyle = Types.ColorStyle
export type ColorStyleValue = Types.ColorStyleValue
export type FontStyle = Types.FontStyle
export type Tokens = Tokens.Tokens

-- Enums and their types
local AccessoryType = require("@self/Enums/AccessoryType")
local AlertSeverity = require("@self/Enums/AlertSeverity")
local AlertVariant = require("@self/Enums/AlertVariant")
local AvatarGroupType = require("@self/Enums/AvatarGroupType")
local AvatarIconSize = require("@self/Enums/AvatarIconSize")
local AvatarSize = require("@self/Enums/AvatarSize")
local BadgeShape = require("@self/Enums/BadgeShape")
local BadgeSize = require("@self/Enums/BadgeSize")
local BadgeVariant = require("@self/Enums/BadgeVariant")
local Breakpoint = require("@self/Enums/Breakpoint")
local ButtonVariant = require("@self/Enums/ButtonVariant")
local ChipGroupVariant = require("@self/Enums/ChipGroupVariant")
local ChipSize = require("@self/Enums/ChipSize")
local ChipVariant = require("@self/Enums/ChipVariant")
local ColorMode = require("@self/Enums/ColorMode")
local ControlState = require("@self/Enums/ControlState")
local CursorType = require("@self/Enums/CursorType")
local DateTimePickerVariant = require("@self/Enums/DateTimePickerVariant")
local Device = require("@self/Enums/Device")
local DialogSize = require("@self/Enums/DialogSize")
local DividerVariant = require("@self/Enums/DividerVariant")
local FillBehavior = require("@self/Enums/FillBehavior")
local IconName = BuilderIcons.Icon
local IconPosition = require("@self/Enums/IconPosition")
local IconSize = require("@self/Enums/IconSize")
local IconVariant = BuilderIcons.IconVariant
local InputFocusBehavior = require("@self/Enums/InputFocusBehavior")
local InputLabelSize = require("@self/Enums/InputLabelSize")
local InputPlacement = require("@self/Enums/InputPlacement")
local InputSize = require("@self/Enums/InputSize")
local InputVariant = require("@self/Enums/InputVariant")
local ListItemInputType = require("@self/Enums/ListItemInputType")
local NumberInputControlsVariant = require("@self/Enums/NumberInputControlsVariant")
local OnChangeCallbackReason = require("@self/Enums/OnChangeCallbackReason")
local OnCloseCallbackReason = require("@self/Enums/OnCloseCallbackReason")
local Orientation = require("@self/Enums/Orientation")
local PaginationSize = require("@self/Enums/PaginationSize")
local PaginationVariant = require("@self/Enums/PaginationVariant")
local PopoverAlign = require("@self/Enums/PopoverAlign")
local PopoverSide = require("@self/Enums/PopoverSide")
local ProgressShape = require("@self/Enums/ProgressShape")
local ProgressSize = require("@self/Enums/ProgressSize")
local Radius = require("@self/Enums/Radius")
local RatingValue = require("@self/Enums/RatingValue")
local ScrubBehavior = require("@self/Enums/ScrubBehavior")
local SearchInputShape = require("@self/Enums/SearchInputShape")
local SliderVariant = require("@self/Enums/SliderVariant")
local StateLayerAffordance = require("@self/Enums/StateLayerAffordance")
local StateLayerMode = require("@self/Enums/StateLayerMode")
local StatusIndicatorShape = require("@self/Enums/StatusIndicatorShape")
local StatusIndicatorSize = require("@self/Enums/StatusIndicatorSize")
local StatusIndicatorVariant = require("@self/Enums/StatusIndicatorVariant")
local Theme = require("@self/Enums/Theme")
local ThumbnailSize = require("@self/Enums/ThumbnailSize")
local ThumbnailType = require("@self/Enums/ThumbnailType")
local UserPresence = require("@self/Enums/UserPresence")
local Visibility = require("@self/Enums/Visibility")

export type AccessoryType = AccessoryType.AccessoryType
export type AlertSeverity = AlertSeverity.AlertSeverity
export type AlertVariant = AlertVariant.AlertVariant
export type AvatarGroupType = AvatarGroupType.AvatarGroupType
export type AvatarIconSize = AvatarIconSize.AvatarIconSize
export type AvatarSize = AvatarSize.AvatarSize
export type BadgeShape = BadgeShape.BadgeShape
export type BadgeSize = BadgeSize.BadgeSize
export type BadgeVariant = BadgeVariant.BadgeVariant
export type Breakpoint = Breakpoint.Breakpoint
export type ButtonVariant = ButtonVariant.ButtonVariant
export type ChipGroupVariant = ChipGroupVariant.ChipGroupVariant
export type ChipSize = ChipSize.ChipSize
export type ChipVariant = ChipVariant.ChipVariant
export type ColorMode = ColorMode.ColorMode
export type ControlState = ControlState.ControlState
export type CursorType = CursorType.CursorType
export type DateTimePickerVariant = DateTimePickerVariant.DateTimePickerVariant
export type Device = Device.Device
export type DialogSize = DialogSize.DialogSize
export type DividerVariant = DividerVariant.DividerVariant
export type FillBehavior = FillBehavior.FillBehavior
export type IconName = typeof(BuilderIcons.Icon)
export type IconPosition = IconPosition.IconPosition
export type IconSize = IconSize.IconSize
export type IconVariant = typeof(BuilderIcons.IconVariant)
export type InputFocusBehavior = InputFocusBehavior.InputFocusBehavior
export type InputLabelSize = InputLabelSize.InputLabelSize
export type InputPlacement = InputPlacement.InputPlacement
export type InputSize = InputSize.InputSize
export type InputVariant = InputVariant.InputVariant
export type ListItemInputType = ListItemInputType.ListItemInputType
export type NumberInputControlsVariant = NumberInputControlsVariant.NumberInputControlsVariant
export type ScrubBehavior = ScrubBehavior.ScrubBehavior
export type OnChangeCallbackReason = OnChangeCallbackReason.OnChangeCallbackReason
export type OnCloseCallbackReason = OnCloseCallbackReason.OnCloseCallbackReason
export type Orientation = Orientation.Orientation
export type PaginationSize = PaginationSize.PaginationSize
export type PaginationVariant = PaginationVariant.PaginationVariant
export type PopoverAlign = PopoverAlign.PopoverAlign
export type PopoverSide = PopoverSide.PopoverSide
export type ProgressShape = ProgressShape.ProgressShape
export type ProgressSize = ProgressSize.ProgressSize
export type RatingValue = RatingValue.RatingValue
export type Radius = Radius.Radius
export type SearchInputShape = SearchInputShape.SearchInputShape
export type SliderVariant = SliderVariant.SliderVariant
export type StateLayerAffordance = StateLayerAffordance.StateLayerAffordance
export type StateLayerMode = StateLayerMode.StateLayerMode
export type StatusIndicatorShape = StatusIndicatorShape.StatusIndicatorShape
export type StatusIndicatorSize = StatusIndicatorSize.StatusIndicatorSize
export type StatusIndicatorVariant = StatusIndicatorVariant.StatusIndicatorVariant
-- **DEPRECATED**: Theme is deprecated. Use ColorMode instead.
export type Theme = Theme.Theme
export type ThumbnailSize = ThumbnailSize.ThumbnailSize
export type ThumbnailType = ThumbnailType.ThumbnailType
export type UserPresence = UserPresence.UserPresence
export type Visibility = Visibility.Visibility
-- enums end

-- Components and their types

local Accordion = require("@self/Components/Accordion")
export type AccordionProps = Accordion.AccordionProps
export type AccordionItemProps = Accordion.AccordionItemProps

local Avatar = require("@self/Components/Avatar")
export type AvatarProps = Avatar.AvatarProps

local AvatarGroup = require("@self/Components/AvatarGroup")
export type AvatarGroupProps = AvatarGroup.AvatarGroupProps

local Badge = require("@self/Components/Badge")
export type BadgeProps = Badge.BadgeProps

local BaseMenu = require("@self/Components/BaseMenu")
export type BaseMenuProps<Item = BaseMenuItem> = BaseMenu.BaseMenuProps<Item>
export type BaseMenuItem = BaseMenu.BaseMenuItem
export type BaseMenuItems<Item = BaseMenuItem> = BaseMenu.BaseMenuItems<Item>
export type BaseMenuItemGroup<Item = BaseMenuItem> = BaseMenu.BaseMenuItemGroup<Item>

local Button = require("@self/Components/Button")
export type ButtonProps = Button.ButtonProps

local Checkbox = require("@self/Components/Checkbox")
export type CheckboxProps = Checkbox.CheckboxProps

local EducationalTooltip = require("@self/Components/EducationalTooltip")
export type EducationalTooltipProps = EducationalTooltip.EducationalTooltipProps

local Chip = require("@self/Components/Chip")
export type ChipProps = Chip.ChipProps

--local ColorPicker = require(script.Components.ColorPicker)
--export type ColorPickerProps = ColorPicker.ColorPickerProps

--[[
local Dialog = require(script.Components.Dialog)
export type DialogProps = Dialog.DialogProps
export type DialogActionsProps = Dialog.DialogActionsProps
export type DialogContentProps = Dialog.DialogContentProps
export type DialogTextProps = Dialog.DialogTextProps
export type DialogHeroMediaProps = Dialog.DialogHeroMediaProps
export type DialogTitleProps = Dialog.DialogTitleProps
]]

--local DateTimePicker = require(script.Components.DateTimePicker)
--export type DateTimePickerProps = DateTimePicker.DateTimePickerProps

local Divider = require("@self/Components/Divider")
export type DividerProps = Divider.DividerProps

local Dropdown = require("@self/Components/Dropdown")
export type DropdownProps = Dropdown.DropdownProps
export type DropdownItem = Dropdown.DropdownItem
export type DropdownItems = Dropdown.DropdownItems

--[[
local Grid = require(script.Components.Grid)
export type GridProps = Grid.GridProps
export type GridCellProps = Grid.GridCellProps
export type GridDebugProps = Grid.GridDebugProps
]]

local Empty = require("@self/Components/Empty")
export type EmptyProps = Empty.EmptyProps

--local FeedbackAlert = require(script.Components.FeedbackAlert)
--export type FeedbackAlertProps = FeedbackAlert.FeedbackAlertProps

local Icon = require("@self/Components/Icon")
export type IconProps = Icon.IconProps

local IconButton = require("@self/Components/IconButton")
export type IconButtonProps = IconButton.IconButtonProps

local Image = require("@self/Components/Image")
export type ImageProps = Image.ImageProps

local InputLabel = require("@self/Components/InputLabel")
export type InputLabelProps = InputLabel.InputLabelProps

--local KeyLabel = require(script.Components.KeyLabel)
--export type KeyLabelProps = KeyLabel.KeyLabelProps

local Knob = require("@self/Components/Knob")
export type KnobProps = Knob.KnobProps

--[[
local List = require(script.Components.List)
export type ListProps = List.ListProps
export type ListItemProps = List.ListItemProps
export type ListAccessoryProps = List.ListAccessoryProps
]]

local Loading = require("@self/Components/Loading")
export type LoadingProps = Loading.LoadingProps

local Menu = require("@self/Components/Menu")
export type MenuProps = Menu.MenuProps
export type MenuItem = Menu.MenuItem
export type MenuItems = Menu.MenuItems

local NumberInput = require("@self/Components/NumberInput")
export type NumberInputProps = NumberInput.NumberInputProps

--[[
local OptionSelectorGroup = require(script.Components.OptionSelectorGroup)
export type OptionSelectorGroupProps = OptionSelectorGroup.OptionSelectorGroupProps
export type OptionSelectorGroupItemProps = OptionSelectorGroup.OptionSelectorGroupItemProps
]]

local Popover = require("@self/Components/Popover")
export type PopoverProps = Popover.PopoverProps
export type PopoverAnchorProps = Popover.PopoverAnchorProps
export type PopoverContentProps = Popover.PopoverContentProps

--local Progress = require(script.Components.Progress)
--export type ProgressProps = Progress.ProgressProps

local RadioGroup = require("@self/Components/RadioGroup")
export type RadioGroupProps = RadioGroup.RadioGroupProps
export type RadioGroupItemProps = RadioGroup.RadioGroupItemProps

local SearchInput = require("@self/Components/SearchInput")
export type SearchInputProps = SearchInput.SearchInputProps

local ScrollView = require("@self/Components/ScrollView")
export type ScrollViewProps = ScrollView.ScrollViewProps

local SegmentedControl = require("@self/Components/SegmentedControl")
export type SegmentedControlProps = SegmentedControl.SegmentedControlProps

--[[
local Sheet = require(script.Components.Sheet)
export type SheetProps = Sheet.SheetProps
export type SheetActionsProps = Sheet.SheetActionsProps
export type SheetContentProps = Sheet.SheetContentProps
export type SheetFullBleedProps = Sheet.SheetFullBleedProps
export type SheetHeaderProps = Sheet.SheetHeaderProps
export type SheetRef = Sheet.SheetRef
]]

local Skeleton = require("@self/Components/Skeleton")
export type SkeletonProps = Skeleton.SkeletonProps

local Slider = require("@self/Components/Slider")
export type SliderProps = Slider.SliderProps

local Snackbar = require("@self/Components/Snackbar")
export type SnackbarProps = Snackbar.SnackbarProps
export type SnackbarAction = Snackbar.SnackbarAction

local StatusIndicator = require("@self/Components/StatusIndicator")
export type StatusIndicatorProps = StatusIndicator.StatusIndicatorProps

--local SystemBanner = require(script.Components.SystemBanner)
--export type SystemBannerProps = SystemBanner.SystemBannerProps

--local Tabs = require(script.Components.Tabs)
--export type TabsProps = Tabs.TabsProps
--export type TabItem = Tabs.TabItem

local Text = require("@self/Components/Text")
export type TextProps = Text.TextProps

local TextArea = require("@self/Components/TextArea")
export type TextAreaProps = TextArea.TextAreaProps

local TextInput = require("@self/Components/TextInput")
export type TextInputProps = TextInput.TextInputProps
export type TextInputRef = Types.TextInputRef

local Toggle = require("@self/Components/Toggle")
export type ToggleProps = Toggle.ToggleProps

local Tooltip = require("@self/Components/Tooltip")
export type TooltipProps = Tooltip.TooltipProps

--local Toast = require(script.Components.Toast)
--export type ToastProps = Toast.ToastProps

local View = require("@self/Components/View")
export type ViewProps = View.ViewProps
-- Components and types end

local Foundation = strict({
	-- Components
	Accordion = Accordion,
	Avatar = Avatar,
	AvatarGroup = AvatarGroup,
	Badge = Badge,
	Button = Button,
	Checkbox = Checkbox,
	Chip = Chip,
	EducationalTooltip = EducationalTooltip,
	--ColorPicker = ColorPicker,
	--DateTimePicker = DateTimePicker,
	--Dialog = Dialog,
	Divider = Divider,
	Dropdown = Dropdown,
	--Grid = Grid,
	Empty = Empty,
	--FeedbackAlert = FeedbackAlert,
	Icon = Icon,
	IconButton = IconButton,
	Image = Image,
	InputLabel = InputLabel,
	--KeyLabel = KeyLabel,
	Knob = Knob,
	--List = List,
	Loading = Loading,
	Menu = Menu,
	NumberInput = NumberInput,
	--OptionSelectorGroup = OptionSelectorGroup,
	Pill = Chip,
	Popover = Popover,
	--Progress = Progress,
	RadioGroup = RadioGroup,
	SearchInput = SearchInput,
	ScrollView = ScrollView,
	SegmentedControl = SegmentedControl,
	--Sheet = Sheet,
	Skeleton = Skeleton,
	Slider = Slider,
	Snackbar = Snackbar,
	StatusIndicator = StatusIndicator,
	--SystemBanner = SystemBanner,
	--Tabs = Tabs,
	Text = Text,
	TextArea = TextArea,
	TextInput = TextInput,
	Toggle = Toggle,
	Tooltip = Tooltip,
	--Toast = Toast,
	View = View,

	-- Providers
	ThemeProvider = require("@self/Providers/ThemeProvider"),
	ElevationProvider = require("@self/Providers/ElevationProvider"),
	OverlayProvider = require("@self/Providers/OverlayProvider"),
	PanelsProvider = require("@self/Providers/PanelsProvider"),
	PluginProvider = require("@self/Providers/PluginProvider"),
	WidgetsProvider = require("@self/Providers/WidgetsProvider"),
	ResponsiveProvider = require("@self/Providers/ResponsiveProvider"),
	CursorProvider = require("@self/Providers/CursorProvider"),
	PreferencesProvider = require("@self/Providers/PreferencesProvider"),
	FoundationProvider = require("@self/Providers/FoundationProvider"),

	-- Hooks
	Hooks = {
		useBreakpoint = require("@self/Providers/ResponsiveProvider/Hooks/useBreakpoint"),
		useResponsiveValue = require("@self/Providers/ResponsiveProvider/Hooks/useResponsiveValue"),
		useCumulativeBackground = require("@self/Utility/useCumulativeBackground"),
		useDefaultTags = require("@self/Utility/useDefaultTags"),
		--useDialogNavigation = require(script.Components.Dialog.useDialogNavigation),
		--useSheetNavigation = require(script.Components.Sheet.useSheetNavigation),
		useIconSize = require("@self/Utility/useIconSize"),
		useMeasurableRef = require("@self/Components/Popover/useMeasurableRef"),
		usePointerPosition = require("@self/Utility/usePointerPosition"),
		usePulseBinding = require("@self/Utility/usePulseBinding"),
		useRotation = require("@self/Utility/useRotation"),
		useScaledValue = require("@self/Utility/useScaledValue"),
		useStyleTags = require("@self/Providers/ThemeProvider/useStyleTags"),
		--withCursor = require(script.Providers.CursorProvider.withCursor)
	},

	-- Enums
	Enums = {
		AccessoryType = AccessoryType,
		AlertSeverity = AlertSeverity,
		AlertVariant = AlertVariant,
		AvatarGroupType = AvatarGroupType,
		AvatarIconSize = AvatarIconSize,
		AvatarSize = AvatarSize,
		BadgeShape = BadgeShape,
		BadgeSize = BadgeSize,
		BadgeVariant = BadgeVariant,
		Breakpoint = Breakpoint,
		-- **DEPRECATED**: ButtonSize is deprecated. Use InputSize instead.
		ButtonSize = require("@self/Enums/InputSize"),
		ButtonVariant = ButtonVariant,
		-- **DEPRECATED**: CheckboxSize is deprecated. Use InputSize instead.
		CheckboxSize = require("@self/Enums/InputSize"),
		ControlState = ControlState,
		ChipGroupVariant = ChipGroupVariant,
		ChipSize = ChipSize,
		ChipVariant = ChipVariant,
		ColorMode = ColorMode,
		CursorType = CursorType,
		DateTimePickerVariant = DateTimePickerVariant,
		Device = Device,
		DialogSize = DialogSize,
		-- **DEPRECATED**: DividerOrientation is deprecated. Use Orientation instead.
		DividerOrientation = require("@self/Enums/Orientation"),
		DividerVariant = DividerVariant,
		FillBehavior = FillBehavior,
		IconName = IconName,
		IconPosition = IconPosition,
		IconSize = IconSize,
		IconVariant = IconVariant,
		InputFocusBehavior = InputFocusBehavior,
		InputSize = InputSize,
		InputVariant = InputVariant,
		InputPlacement = InputPlacement,
		InputLabelSize = InputLabelSize,
		ListItemInputType = ListItemInputType,
		NumberInputControlsVariant = NumberInputControlsVariant,
		ScrubBehavior = ScrubBehavior,
		OnChangeCallbackReason = OnChangeCallbackReason,
		OnCloseCallbackReason = OnCloseCallbackReason,
		Orientation = Orientation,
		PaginationSize = PaginationSize,
		PaginationVariant = PaginationVariant,
		PopoverAlign = PopoverAlign,
		PopoverSide = PopoverSide,
		ProgressShape = ProgressShape,
		ProgressSize = ProgressSize,
		RatingValue = RatingValue,
		Radius = Radius,
		SearchInputShape = SearchInputShape,
		-- **DEPRECATED**: ScrollBarVisibility is deprecated. Use Visibility instead.
		ScrollBarVisibility = require("@self/Enums/Visibility"),
		SliderVariant = SliderVariant,
		StateLayerAffordance = StateLayerAffordance,
		StateLayerMode = StateLayerMode,
		StatusIndicatorShape = StatusIndicatorShape,
		StatusIndicatorSize = StatusIndicatorSize,
		StatusIndicatorVariant = StatusIndicatorVariant,
		-- **DEPRECATED**: Theme is deprecated. Use ColorMode instead.
		Theme = Theme,
		ThumbnailType = ThumbnailType,
		ThumbnailSize = ThumbnailSize,
		-- **DEPRECATED**: ToggleSize is deprecated. Use InputSize instead.
		ToggleSize = require("@self/Enums/InputSize"),
		UserPresence = UserPresence,
		Visibility = Visibility,
	},

	-- Utility
	Utility = {
		getStyleSheet = StyleSheetRegistry.getStyleSheet,
		addStyleTags = StyleSheetRegistry.addStyleTags,
		getTokens = Tokens.getTokens,
		blendColors = require("@self/Utility/blendColors"),
		composeStyleVariant = require("@self/Utility/composeStyleVariant"),
		getBuilderIconForKeycode = require("@self/Utility/getBuilderIconForKeycode"),
		getBuilderIconForCurrentPlatform = require("@self/Utility/getBuilderIconForCurrentPlatform"),
		--getBuilderIconVariant = require(script.Utility.getBuilderIconVariant),
		--getGridMetrics = require(script.Utility.getGridMetrics),
		getRbxThumb = require("@self/Utility/getRbxThumb"),
		getIconRichText = require("@self/Utility/getIconRichText"),
		withCommonProps = require("@self/Utility/withCommonProps"),
		withDefaults = require("@self/Utility/withDefaults"),
		isBuilderIcon = require("@self/Utility/isBuilderIcon"),
		isPointInGuiObjectBounds = require("@self/Utility/isPointInGuiObjectBounds"),
		preloadCloudAssets = require("@self/Utility/preloadAssets"),
		unwrap = require("@self/Utility/unwrap"),
		isState = require("@self/Utility/isState")
	},

	-- Unstable APIs, do not use
	UNSTABLE = {
		-- Use View/Text/Image instead
		Interactable = require("@self/Components/Interactable"),
		BaseMenu = BaseMenu,
		Fusion = Fusion
	}
})

return Foundation
