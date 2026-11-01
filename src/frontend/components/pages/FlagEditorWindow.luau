local Color = require("@Luwow/color")
local UDim = require("@Luwow/udim")
local UDim2 = require("@Luwow/udim2")

local Packages = require("@Frontend/Packages")
local Types = require("@Frontend/Types")
local Style = require("@Frontend/Style")

local DialogWindow = require("@Frontend/components/DialogWindow")
local FlagCreatorDialog = require("@Frontend/components/FlagCreatorDialog")
local BusyOverlay = require("@Frontend/components/BusyOverlay")
local Notification = require("@Frontend/components/Notification")
local VirtualList = require("@Frontend/components/VirtualList")

local Foundation = Packages.Foundation

local Button = Foundation.Button
local Divider = Foundation.Divider
local Dropdown = Foundation.Dropdown
local Icon = Foundation.Icon
local SearchInput = Foundation.SearchInput
local SegmentedControl = Foundation.SegmentedControl
local TextInput = Foundation.TextInput
local ThemeProvider = Foundation.ThemeProvider
local Tooltip = Foundation.Tooltip
local View = Foundation.View

local ButtonVariant = Foundation.Enums.ButtonVariant
local Orientation = Foundation.Enums.Orientation
local IconName = Foundation.Enums.IconName
local InputSize = Foundation.Enums.InputSize
local InputVariant = Foundation.Enums.InputVariant
local PopoverSide = Foundation.Enums.PopoverSide

local unwrap = Foundation.Utility.unwrap

local VIEW_FLAGS = 1
local OVERRIDES = 2

local PADDING = 12
local ROW_SPACING = 8
local COLUMN_SPACING = 8
-- The tab strip above the tabs' content, with room under it, and the divider under that
local TAB_STRIP_HEIGHT = 52
local DIVIDER_HEIGHT = 8
local CONTENT_TOP = TAB_STRIP_HEIGHT + DIVIDER_HEIGHT
-- A small input's height, the toolbars' rows
local TOOLBAR_HEIGHT = 32
-- The space above a tab's toolbar, a little less than around the rest of its content
local CONTENT_TOP_PADDING = 8
-- The line between the search and the buttons
local TOOLBAR_DIVIDER_HEIGHT = 20
-- A small input's height, the override values' editors
local VALUE_EDITOR_HEIGHT = 28
-- ListViewItem's MinHeight
local ROW_HEIGHT = 40
local HEADER_HEIGHT = 26

-- Name 3*, Type *, Value 2*
local NAME_WIDTH = 3 / 6
local TYPE_WIDTH = 1 / 6
local VALUE_WIDTH = 2 / 6

-- A list item's inset in its row, and its corners. Hovering and selecting light up that rounded shape
local ITEM_INSET_X = 4
local ITEM_INSET_Y = 2
local ITEM_RADIUS = 4
-- ListViewItem's selected fill, and its accent pill
local SELECTED = { Color3 = Color.new(1, 1, 1), Transparency = 0.94 }
local ACCENT = { Color3 = Color.fromRGB(237, 97, 105), Transparency = 0 }

local SEARCH_PLACEHOLDER = "Search flags"
local OVERWRITTEN_TOOLTIP = "This flag has been overwritten"
local ICON_GUTTER = 22
local INFO_ICON_SIZE = 14

local BOOL_ITEMS = {
	{ id = "true", text = "true" },
	{ id = "false", text = "false" }
}

--// Types

type Scope = Types.Scope
type Callbacks = Types.Callbacks
type FlagData = Types.FlagData
type FlagEditorStates = Types.FlagEditorStates

export type FlagEditorContext = {
	Window: any,
	UIManager: any,
	Loaded: (() -> ())?,
	Closed: (() -> ())?
}

type Page = {
	States: FlagEditorStates,
	Editor: Types.FlagEditorCallbacks,
	Context: FlagEditorContext,
	Toast: any,
	FlagList: any,
	OverrideList: any
}

--// Local Functions

local function refreshOverrideList(page: Page)
	page.States.SelectedOverride:set(nil)
	page.States.OverrideCount:set(page.Editor.FetchOverrides())
	page.OverrideList.Reset()
end

local function refreshFlags(page: Page)
	page.States.SelectedFlag:set(nil)
	page.States.FlagCount:set(page.Editor.SearchFlags(string.lower(unwrap(page.States.Search))))
	page.FlagList.Reset()
end

-- The frontend part of addFlagOverride
local function showFlagOverride(page: Page)
	refreshOverrideList(page)
	page.States.SelectedTab:set(OVERRIDES)
	-- The highlights of View Flags
	page.FlagList.Refresh(true)
end

local function initializeEditor(page: Page)
	page.States.Busy:set(true)
	local ok, err = pcall(function()
		page.Editor.FetchAllFlags()
		refreshFlags(page)
		refreshOverrideList(page)
	end)
	page.States.Busy:set(false)
	if not ok then
		error(err, 0)
	end
end

local function searchTextChanged(page: Page, text: string)
	page.States.Search:set(text)
	refreshFlags(page)
end

local function overrideSelected(page: Page)
	local key = unwrap(page.States.SelectedFlag)
	if key then
		page.Editor.OverrideFlag(key)
		showFlagOverride(page)
	end
end

local function removeSelected(page: Page)
	local key = unwrap(page.States.SelectedOverride)
	if key then
		page.Editor.RemoveOverride(key)
		refreshOverrideList(page)
		page.FlagList.Refresh(true)
	end
end

local function removeAll(page: Page)
	local result = DialogWindow.show({
		Title = "Confirmation",
		Content = "Are you sure you would like to remove all flag overrides?\nThis will also delete any custom flags!",
		PrimaryButtonText = "Yes",
		CloseButtonText = "No",
		DefaultButton = "Close",
		Icon = "Warning",
		Owner = page.Context.Window,
	})
	if result ~= "Primary" then return end

	page.Editor.RemoveAllOverrides()
	refreshOverrideList(page)
	page.FlagList.Refresh(true)
end

local function addCustom(page: Page)
	local form = FlagCreatorDialog()
	local result = DialogWindow.show({
		Title = "Add Custom Flag",
		Content = form.Content,
		PrimaryButtonText = "Create",
		CloseButtonText = "Cancel",
		DefaultButton = "Primary",
		Owner = page.Context.Window,
		PlaySound = false,
		OnPrimaryButtonClick = form.Validate,
	})
	if result ~= "Primary" or not form.Result then return end

	page.Editor.AddCustomFlag(form.Result.Type, form.Result.Name)
	showFlagOverride(page)
end

local function copyFlagName(page: Page, key: string)
	page.Context.Window:SetClipboardText(key)
	page.Toast.Show("Flag name copied to clipboard!")
end

local function createCell(scope: Scope, name: string, x: number, width: number, child: any): any
	return View {
		scope = scope,
		Name = name,
		Position = UDim2.fromScale(x, 0),
		Size = UDim2.fromScale(width, 1),
		children = {
			Line = View {
				scope = scope,
				Name = "Border",
				Size = UDim2.new(0, 1, 1, 0),
				backgroundStyle = Style.GRAY,
			},
			Content = View {
				scope = scope,
				Name = "Padding",
				Position = UDim2.fromOffset(9, 0),
				Size = UDim2.new(1, -17, 1, 0),
				children = { child },
			}
		}
	}
end

local function createCellText(scope: Scope, text: any, props: { [string]: any }?): any
	local textProps: { [string]: any } = {
		AnchorPoint = vector.create(0, 0.5, 0),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromScale(1, 1),
		TextTruncate = "AtEnd",
	}
	for key, value in props or {} do
		textProps[key] = value
	end
	return Style.Text(scope, text, textProps)
end

local function createHeader(scope: Scope, horizontalPadding: number, nameInset: number?): any
	local inset = nameInset or 0
	return View {
		scope = scope,
		Name = "Header",
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
		children = {
			Columns = View {
				scope = scope,
				Position = UDim2.fromOffset(horizontalPadding, 0),
				Size = UDim2.new(1, -horizontalPadding * 2, 1, -6),
				children = {
					Name = createCellText(scope, "Name", {
						Position = UDim2.new(0, inset, 0.5, 0),
						Size = UDim2.new(NAME_WIDTH, -inset, 1, 0),
						Font = Style.SEMIBOLD_FONT,
					}),
					Type = createCell(scope, "Type", NAME_WIDTH, TYPE_WIDTH, createCellText(scope, "Type", { Font = Style.SEMIBOLD_FONT })),
					Value = createCell(scope, "Value", NAME_WIDTH + TYPE_WIDTH, VALUE_WIDTH, createCellText(scope, "Value", { Font = Style.SEMIBOLD_FONT })),
				}
			},
			BottomBorder = View {
				scope = scope,
				AnchorPoint = vector.create(0, 1, 0),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, 1),
				backgroundStyle = Style.GRAY,
			}
		}
	}
end

local function createSelection(scope: Scope, isSelected: any): any
	return View {
		scope = scope,
		Name = "Selection",
		Size = UDim2.fromScale(1, 1),
		cornerRadius = UDim.new(0, ITEM_RADIUS),
		backgroundStyle = SELECTED,
		Visible = isSelected,
		children = {
			Pill = View {
				scope = scope,
				Name = "Pill",
				AnchorPoint = vector.create(0, 0.5, 0),
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.fromOffset(3, 16),
				cornerRadius = UDim.new(0, 2),
				backgroundStyle = ACCENT,
			}
		}
	}
end

-- The info icon of an overwritten flag, explaining itself when hovered
local function createOverwrittenMark(scope: Scope, overwritten: any): any
	return View {
		scope = scope,
		Name = "OverwrittenMark",
		AnchorPoint = vector.create(0, 0.5, 0),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(INFO_ICON_SIZE, INFO_ICON_SIZE),
		Visible = overwritten,
		children = {
			Tooltip {
				scope = scope,
				title = "",
				text = OVERWRITTEN_TOOLTIP,
				-- Above the icon, so the flag's name stays readable
				side = PopoverSide.Top,
				children = {
					Icon {
						scope = scope,
						name = IconName.CircleI,
						size = INFO_ICON_SIZE,
						style = scope:Computed(function(use)
							return unwrap(ThemeProvider().Tokens, use).Color.Content.Link
						end)
					}
				}
			}
		}
	}
end

--[[
	A row of the list, with a rounded item inset in it that
	takes the hover, the clicks and the selection, so they all have the same
	shape. The columns go in the item.
]]
local function createListRow(scope: Scope, slot: any, props: {
	Name: string,
	IsSelected: any,
	OnActivated: () -> (),
	OnSecondaryActivated: (() -> ())?,
	Columns: { [string]: any },
}): any
	return View {
		scope = scope,
		Name = props.Name,
		Position = slot.Position,
		Visible = slot.Visible,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		children = {
			Item = View {
				scope = scope,
				Name = "Item",
				Position = UDim2.fromOffset(ITEM_INSET_X, ITEM_INSET_Y),
				Size = UDim2.new(1, -ITEM_INSET_X * 2, 1, -ITEM_INSET_Y * 2),
				cornerRadius = UDim.new(0, ITEM_RADIUS),
				stateLayer = { affordance = "Background" },
				onActivated = props.OnActivated,
				onSecondaryActivated = props.OnSecondaryActivated,
				children = {
					Selection = createSelection(scope, props.IsSelected),
					Content = View {
						scope = scope,
						Name = "Columns",
						-- The columns line up with the header's, 12 pixels into the row
						Position = UDim2.fromOffset(12 - ITEM_INSET_X, 4 - ITEM_INSET_Y),
						Size = UDim2.new(1, -(12 - ITEM_INSET_X) * 2, 1, -(4 - ITEM_INSET_Y) * 2),
						children = props.Columns,
					},
				},
			},
		},
	}
end

-- Whether a row shows the selected key of its list
local function isSelectedRow(scope: Scope, slot: any, selected: any): any
	return scope:Computed(function(use)
		local key = unwrap(slot.KeyValue, use)
		return key ~= nil and unwrap(selected, use) == key
	end)
end

-- View Flags' rows
local function createFlagRow(page: Page, scope: Scope, slot: any): any
	local states = page.States

	slot.Key = nil :: string?
	slot.KeyValue = scope:Value(nil :: string?)
	slot.Name = scope:Value("")
	slot.Type = scope:Value("")
	slot.Value = scope:Value("")
	slot.Overridden = scope:Value(false)

	local tokens = ThemeProvider().Tokens
	local textStyle = scope:Computed(function(use)
		if unwrap(slot.Overridden, use) then
			return unwrap(tokens, use).Color.Content.Link
		end
		return Style.TEXT
	end)

	-- Only an overwritten flag's name makes room for its icon
	local nameInset = scope:Computed(function(use)
		return if unwrap(slot.Overridden, use) then ICON_GUTTER else 0
	end)

	return createListRow(scope, slot, {
		Name = "FlagRow",
		IsSelected = isSelectedRow(scope, slot, states.SelectedFlag),
		OnActivated = function()
			states.SelectedFlag:set(slot.Key)
		end,
		OnSecondaryActivated = function()
			if slot.Key then
				copyFlagName(page, slot.Key)
			end
		end,
		Columns = {
			OverwrittenMark = createOverwrittenMark(scope, slot.Overridden),
			Name = createCellText(scope, slot.Name, {
				Position = scope:Computed(function(use)
					return UDim2.new(0, unwrap(nameInset, use), 0.5, 0)
				end),
				Size = scope:Computed(function(use)
					return UDim2.new(NAME_WIDTH, -(unwrap(nameInset, use) + 8), 1, 0)
				end),
				textStyle = textStyle,
			}),
			Type = createCell(scope, "Type", NAME_WIDTH, TYPE_WIDTH, createCellText(scope, slot.Type, { textStyle = textStyle })),
			Value = createCell(scope, "Value", NAME_WIDTH + TYPE_WIDTH, VALUE_WIDTH, createCellText(scope, slot.Value, { textStyle = textStyle })),
		},
	})
end

local function bindFlagRow(page: Page, slot: any, index: number)
	local flag: FlagData? = page.Editor.GetFlag(index)
	slot.Key = if flag then flag.Key else nil
	slot.KeyValue:set(slot.Key)
	slot.Name:set(if flag then flag.Name else "")
	slot.Type:set(if flag then flag.Type else "")
	slot.Value:set(if flag then flag.Value else "")
	slot.Overridden:set(if flag then flag.Overridden else false)
end

local function valueBoxLostFocus(page: Page, slot: any)
	if not slot.Key then return end
	slot.Value:set(page.Editor.SetOverrideValue(slot.Key, unwrap(slot.Value)))
end

local function valueComboSelectionChanged(page: Page, slot: any, value: string)
	if not slot.Key then return end
	slot.Value:set(value)
	page.Editor.SetOverrideValue(slot.Key, value)
end

local function createValueEditor(page: Page, scope: Scope, slot: any): any
	return View {
		scope = scope,
		Name = "ValueHost",
		AnchorPoint = vector.create(0, 0.5, 0),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, VALUE_EDITOR_HEIGHT),
		children = {
			ValueBox = View {
				scope = scope,
				tag = "size-full-0 auto-y",
				Visible = scope:Computed(function(use)
					return not unwrap(slot.IsBoolFlag, use)
				end),
				children = {
					TextInput {
						scope = scope,
						label = "",
						text = slot.Value,
						size = InputSize.Small,
						variant = InputVariant.Standard,
						width = UDim.new(1, 0),
						onChanged = function(text: string)
							slot.Value:set(text)
						end,
						onFocusLost = function()
							valueBoxLostFocus(page, slot)
						end
					}
				}
			},
			ValueCombo = View {
				scope = scope,
				tag = "size-full-0 auto-y",
				Visible = slot.IsBoolFlag,
				children = {
					Dropdown {
						scope = scope,
						label = "",
						items = BOOL_ITEMS,
						value = slot.Value,
						size = InputSize.Small,
						variant = InputVariant.Contrast,
						width = UDim.new(1, 0),
						onItemChanged = function(id)
							valueComboSelectionChanged(page, slot, id :: string)
						end
					}
				}
			}
		}
	}
end

local function createOverrideRow(page: Page, scope: Scope, slot: any): any
	local states = page.States

	slot.Key = nil :: string?
	slot.KeyValue = scope:Value(nil :: string?)
	slot.Name = scope:Value("")
	slot.Type = scope:Value("")
	slot.Value = scope:Value("")
	slot.IsBoolFlag = scope:Value(false)

	return createListRow(scope, slot, {
		Name = "OverrideRow",
		IsSelected = isSelectedRow(scope, slot, states.SelectedOverride),
		OnActivated = function()
			states.SelectedOverride:set(slot.Key)
		end,
		Columns = {
			Name = createCellText(scope, slot.Name, {
				Size = UDim2.new(NAME_WIDTH, -8, 1, 0),
			}),
			Type = createCell(scope, "Type", NAME_WIDTH, TYPE_WIDTH, createCellText(scope, slot.Type)),
			Value = createCell(scope, "Value", NAME_WIDTH + TYPE_WIDTH, VALUE_WIDTH, createValueEditor(page, scope, slot)),
		}
	})
end

local function bindOverrideRow(page: Page, slot: any, index: number)
	local flag: FlagData? = page.Editor.GetOverride(index)
	slot.Key = if flag then flag.Key else nil
	slot.KeyValue:set(slot.Key)
	slot.Name:set(if flag then flag.Name else "")
	slot.Type:set(if flag then flag.Type else "")

	local isBoolFlag = flag ~= nil and string.sub(flag.Type, -4) == "Flag"
	slot.IsBoolFlag:set(isBoolFlag)

	local value = if flag then flag.Value else ""
	if isBoolFlag then
		value = if string.lower(value) == "true" then "true" else "false"
	end
	slot.Value:set(value)
end

local function createToolbarButton(scope: Scope, name: string, text: string, order: number, onClick: () -> (), variant: string?): any
	return Button {
		scope = scope,
		Name = name,
		text = text,
		size = InputSize.Small,
		variant = variant or ButtonVariant.Standard,
		LayoutOrder = order,
		onActivated = onClick,
	}
end

local function createToolbar(scope: Scope, children: { [string]: any }): any
	return View {
		scope = scope,
		Name = "Toolbar",
		Size = UDim2.new(1, 0, 0, TOOLBAR_HEIGHT),
		layout = {
			FillDirection = "Horizontal",
			VerticalAlignment = "Center",
			Padding = UDim.new(0, COLUMN_SPACING),
			SortOrder = "LayoutOrder",
		},
		children = children,
	}
end

local function createTab(scope: Scope, states: FlagEditorStates, id: number, child: any): any
	return View {
		scope = scope,
		Name = if id == VIEW_FLAGS then "ViewFlags" else "Overrides",
		Position = UDim2.fromOffset(0, CONTENT_TOP),
		Size = UDim2.new(1, 0, 1, -CONTENT_TOP),
		padding = {
			top = UDim.new(0, CONTENT_TOP_PADDING),
			bottom = UDim.new(0, PADDING),
			left = UDim.new(0, PADDING),
			right = UDim.new(0, PADDING),
		},
		Visible = scope:Computed(function(use)
			return unwrap(states.SelectedTab, use) == id
		end),
		children = { child }
	}
end

-- Where the table starts, which is under the toolbar
local TOOLBAR_GAP = ROW_SPACING + math.round(TOOLBAR_HEIGHT * 0.2)
local TABLE_TOP = TOOLBAR_HEIGHT + TOOLBAR_GAP

local function createViewFlags(page: Page, scope: Scope, flagList: any): any
	local states = page.States

	return View {
		scope = scope,
		Name = "Grid",
		tag = "size-full",
		children = {
			Toolbar = createToolbar(scope, {
				SearchBox = View {
					scope = scope,
					Name = "SearchBox",
					LayoutOrder = 1,
					Size = UDim2.new(0, 0, 0, TOOLBAR_HEIGHT),
					flexItem = { FlexMode = "Fill" },
					children = {
						SearchInput {
							scope = scope,
							text = states.Search,
							placeholder = SEARCH_PLACEHOLDER,
							size = InputSize.Small,
							variant = InputVariant.Standard,
							width = UDim.new(1, 0),
							onChanged = function(text: string)
								searchTextChanged(page, text)
							end
						}
					}
				},
				SearchDivider = View {
					scope = scope,
					Name = "SearchDivider",
					LayoutOrder = 2,
					Size = UDim2.fromOffset(1, TOOLBAR_DIVIDER_HEIGHT),
					children = {
						Divider {
							scope = scope,
							orientation = Orientation.Vertical,
						}
					}
				},
				OverrideSelectedButton = createToolbarButton(scope, "OverrideSelectedButton", "Override Selected", 3, function()
					overrideSelected(page)
				end, ButtonVariant.Emphasis),
				AddCustomButton = createToolbarButton(scope, "AddCustomButton", "Add Custom", 4, function()
					addCustom(page)
				end)
			}),

			Table = View {
				scope = scope,
				Name = "Table",
				Position = UDim2.fromOffset(0, TABLE_TOP),
				Size = UDim2.new(1, 0, 1, -TABLE_TOP),
				children = {
					Header = createHeader(scope, 12),
					List = View {
						scope = scope,
						Name = "FlagListView",
						Position = UDim2.fromOffset(0, HEADER_HEIGHT + ROW_SPACING),
						Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + ROW_SPACING)),
						children = { flagList },
					}
				}
			}
		}
	}
end

local function createOverrides(page: Page, scope: Scope, overrideList: any): any
	return View {
		scope = scope,
		Name = "Grid",
		tag = "size-full",
		children = {
			Toolbar = createToolbar(scope, {
				Title = Style.Text(scope, "Overrides", {
					LayoutOrder = 1,
					Size = UDim2.new(0, 0, 1, 0),
					flexItem = { FlexMode = "Fill" },
					FontSize = 16,
				}),
				RemoveSelectedButton = createToolbarButton(scope, "RemoveSelectedButton", "Remove Selected", 2, function()
					removeSelected(page)
				end),
				RemoveAllButton = createToolbarButton(scope, "RemoveAllButton", "Remove All", 3, function()
					removeAll(page)
				end),
			}),
			Header = View {
				scope = scope,
				Position = UDim2.fromOffset(0, TABLE_TOP),
				Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
				children = { createHeader(scope, 12) },
			},
			List = View {
				scope = scope,
				Name = "OverrideListView",
				Position = UDim2.fromOffset(0, TABLE_TOP + HEADER_HEIGHT + ROW_SPACING),
				Size = UDim2.new(1, 0, 1, -(TABLE_TOP + HEADER_HEIGHT + ROW_SPACING)),
				children = { overrideList },
			}
		}
	}
end

-- Between the tab strip and the tab's toolbar
local function createTabDivider(scope: Scope): any
	return View {
		scope = scope,
		Name = "TabDivider",
		Position = UDim2.fromOffset(PADDING, TAB_STRIP_HEIGHT),
		Size = UDim2.new(1, -PADDING * 2, 0, DIVIDER_HEIGHT),
		children = {
			Divider {
				scope = scope,
			}
		}
	}
end

-- TabView's strip
local function createTabStrip(scope: Scope, states: FlagEditorStates): any
	return View {
		scope = scope,
		Name = "Tabs",
		Position = UDim2.fromOffset(PADDING, 8),
		tag = "auto-xy",
		children = {
			SegmentedControl {
				scope = scope,
				segments = {
					{ id = VIEW_FLAGS, text = "View Flags" },
					{ id = OVERRIDES, text = "Overrides" },
				},
				value = states.SelectedTab,
				size = InputSize.Small,
				onActivated = function(id)
					states.SelectedTab:set(id :: number)
				end
			}
		}
	}
end

--// Return Constructor

return function(scope: Scope, callbacks: Callbacks, context: FlagEditorContext): (any, FlagEditorStates)
	local page: Page

	local states: FlagEditorStates = {
		FlagCount = scope:Value(0),
		OverrideCount = scope:Value(0),
		SelectedFlag = scope:Value(nil :: string?),
		SelectedOverride = scope:Value(nil :: string?),
		Search = scope:Value(""),
		SelectedTab = scope:Value(VIEW_FLAGS),
		Busy = scope:Value(false),
		Refresh = function()
			page.FlagList.Refresh(true)
			page.OverrideList.Refresh(true)
		end
	}

	local toast, toastController = Notification(scope)

	page = {
		States = states,
		Editor = callbacks.FlagEditor,
		Context = context,
		Toast = toastController,
		FlagList = nil,
		OverrideList = nil
	}

	local flagList, flagController = VirtualList(scope, {
		Count = states.FlagCount,
		ItemHeight = ROW_HEIGHT,
		CreateRow = function(rowScope, slot)
			return createFlagRow(page, rowScope, slot)
		end,
		BindRow = function(slot, index)
			bindFlagRow(page, slot, index)
		end
	})

	local overrideList, overrideController = VirtualList(scope, {
		Count = states.OverrideCount,
		ItemHeight = ROW_HEIGHT,
		CreateRow = function(rowScope, slot)
			return createOverrideRow(page, rowScope, slot)
		end,
		BindRow = function(slot, index)
			bindOverrideRow(page, slot, index)
		end
	})

	page.FlagList = flagController
	page.OverrideList = overrideController

	context.Loaded = function()
		initializeEditor(page)
	end
	context.Closed = function()
		page.Editor.Closed()
	end

	local children = {
		Tabs = createTabStrip(scope, states),
		TabDivider = createTabDivider(scope),
		ViewFlags = createTab(scope, states, VIEW_FLAGS, createViewFlags(page, scope, flagList)),
		Overrides = createTab(scope, states, OVERRIDES, createOverrides(page, scope, overrideList)),
		CopyToast = toast,
		LoadingRing = BusyOverlay(scope, states.Busy)
	}

	return children, states
end
