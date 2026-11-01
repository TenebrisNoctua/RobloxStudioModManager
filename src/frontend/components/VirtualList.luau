const UDim2 = require("@Luwow/udim2")
const task = require("@Luwow/task")

const Packages = require("@Frontend/Packages")
const Types = require("@Frontend/Types")

const Foundation = Packages.Foundation
const Fusion = Packages.Fusion
const Instances = Packages.Instances

const ThemeProvider = Foundation.ThemeProvider

const unwrap = Foundation.Utility.unwrap

const Children = Fusion.Children
const OnChange = Fusion.OnChange

const FRAME_TIME = 1 / 60

--// Types

type UsedAs<T> = Types.UsedAs<T>
type Scope = Types.Scope

-- A row of the list.
export type Slot = {
	Index: number?,
	Position: UsedAs<any>,
	Visible: UsedAs<boolean>,
	[string]: any
}

export type VirtualListProps = {
	-- How many items there are.
	Count: UsedAs<number>,
	ItemHeight: number,
	-- How wide the content is, for sideways scrolling. Left out, the rows fill the list's width.
	ContentWidth: UsedAs<number>?,
	-- How many rows are kept above and below the window. (3 by default)
	Buffer: number?,
	-- Whether a new Count scrolls back to the top, as new items do. (true by default)
	ResetOnCountChange: boolean?,
	-- Builds a row once. It has to use slot.Position and slot.Visible, and returns the row.
	CreateRow: (scope: Scope, slot: Slot) -> any,
	-- Shows an item in a row, when the row's index changes or the list is refreshed.
	BindRow: (slot: Slot, index: number) -> ()
}

export type VirtualListController = {
	-- Shows the rows again, rebinding them all when forced
	Refresh: (force: boolean?) -> (),
	-- Scrolls so the item is in view
	ScrollToIndex: (index: number) -> (),
	-- Scrolls back to the top and rebinds every row, as new items do
	Reset: () -> ()
}

--// Local Functions

local function hideSlot(slot: Slot)
	slot.Visible:set(false)
	slot.Index = nil
end

-- The items in view, with the buffer around them
local function visibleRange(scrollY: number, windowHeight: number, itemHeight: number, buffer: number, total: number): (number, number)
	const first = math.max(math.floor(scrollY / itemHeight) + 1 - buffer, 1)
	const last = math.min(math.ceil((scrollY + windowHeight) / itemHeight) + buffer, total)
	return first, last
end

-- The scroll position that brings an item into view, moving as little as it can
local function scrollTarget(index: number, itemHeight: number, scrollY: number, windowHeight: number): number
	const top = (index - 1) * itemHeight
	if top < scrollY then
		return top
	elseif top + itemHeight > scrollY + windowHeight then
		return math.max(top + itemHeight - windowHeight, 0)
	end
	return scrollY
end

--// Return Constructor

--[[
	A list that only has rows for the items in view. A
	pool of rows is moved and rebound as it scrolls, so the items themselves
	stay with whoever gives them, and only the shown ones are fetched.
]]
return function(scope: Scope, props: VirtualListProps): (any, VirtualListController)
	const tokens = ThemeProvider().Tokens
	const itemHeight = props.ItemHeight
	const buffer = props.Buffer or 3

	const slots: { Slot } = {}
	const rows = scope:Value({})

	local list: any = nil
	local windowHeight = 0
	local canvasWidth = -1
	local canvasHeight = -1
	local lastRefresh = 0
	local boundFirst = 0
	local boundLast = -1
	local pendingRefresh: thread? = nil

	local function createSlot()
		const slot: Slot = {
			Position = scope:Value(UDim2.new()),
			Visible = scope:Value(false),
		}

		table.insert(slots, slot)
		return props.CreateRow(scope, slot)
	end

	local function measureWindow(): number
		if windowHeight <= 0 then
			windowHeight = Instances.get(list, "AbsoluteWindowSize").y
		end
		return windowHeight
	end

	local function refresh(force: boolean?, partial: boolean?): boolean
		if not list or list.Destroyed then
			return false
		end

		const total = unwrap(props.Count)
		const contentHeight = total * itemHeight
		const contentWidth = if props.ContentWidth then unwrap(props.ContentWidth) else 0
		if canvasWidth ~= contentWidth or canvasHeight ~= contentHeight then
			canvasWidth = contentWidth
			canvasHeight = contentHeight
			Instances.set(list, "CanvasSize", UDim2.fromOffset(contentWidth, contentHeight))
		end

		if force then
			windowHeight = 0
		end
		const height = measureWindow()
		if total == 0 or height <= 0 then
			for _, slot in slots do
				hideSlot(slot)
			end
			return false
		end

		const scrollY = math.clamp(Instances.get(list, "CanvasPosition").y, 0, math.max(contentHeight - height, 0))

		local first, last = visibleRange(scrollY, height, itemHeight, buffer, total)
		const jumped = partial == true and not force and (last < boundFirst or first > boundLast)
		if jumped then
			first, last = visibleRange(scrollY, height, itemHeight, 0, total)
		end
		boundFirst, boundLast = first, last
		const capacity = math.min(math.ceil(height / itemHeight) + 1 + buffer * 2, total)

		-- The pool grows when the list gets taller, and never shrinks.
		if #slots < capacity then
			const newRows = table.clone(unwrap(rows))
			for _ = #slots + 1, capacity do
				table.insert(newRows, createSlot())
			end
			rows:set(newRows)
			force = true
		end

		const poolSize = #slots

		for index = first, last do
			const slot = slots[((index - 1) % poolSize) + 1]

			if force or slot.Index ~= index then
				slot.Index = index
				slot.Position:set(UDim2.fromOffset(0, (index - 1) * itemHeight))
				props.BindRow(slot, index)
			end

			slot.Visible:set(true)
		end

		for _, slot in slots do
			const index = slot.Index
			if index ~= nil and (index < first or index > last) then
				hideSlot(slot)
			end
		end

		return jumped
	end

	local settle: () -> ()

	local function refreshScrolled()
		const jumped = refresh(false, true)
		lastRefresh = os.clock()
		if jumped and not pendingRefresh then
			pendingRefresh = task.delay(FRAME_TIME, settle)
		end
	end

	function settle()
		pendingRefresh = nil
		const wait = FRAME_TIME - (os.clock() - lastRefresh)
		if wait > 0 then
			pendingRefresh = task.delay(wait, settle)
			return
		end
		refreshScrolled()
	end

	local function scrollToIndex(index: number)
		if not list or list.Destroyed then
			return
		end
		const position = Instances.get(list, "CanvasPosition")
		const y = scrollTarget(index, itemHeight, position.y, measureWindow())
		if y ~= position.y then
			Instances.set(list, "CanvasPosition", vector.create(position.x, y, 0))
		end
		refresh(false)
	end

	list = Instances.New(scope, "ScrollingFrame")({
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,

		AutomaticCanvasSize = "None",
		CanvasSize = UDim2.new(),
		ScrollingDirection = if props.ContentWidth then "XY" else "Y",

		ScrollBarThickness = scope:Computed(function(use)
			return unwrap(tokens, use).Size.Size_150
		end),
		ScrollBarImageColor3 = scope:Computed(function(use)
			return unwrap(tokens, use).Color.Shift.Shift_400.Color3
		end),
		ScrollBarImageTransparency = scope:Computed(function(use)
			return unwrap(tokens, use).Color.Shift.Shift_400.Transparency
		end),

		Size = UDim2.fromScale(1, 1),

		-- Scrolling and resizing move the window over the content
		[OnChange "CanvasPosition"] = refreshScrolled,
		[OnChange "AbsoluteWindowSize"] = function()
			windowHeight = 0
			refresh(false)
		end,

		[Children] = rows
	})

	local function reset()
		if not list or list.Destroyed then
			return
		end
		Instances.set(list, "CanvasPosition", vector.create(0, 0, 0))
		refresh(true)
	end

	-- New items
	scope:Observer(props.Count):onChange(function()
		if props.ResetOnCountChange == false then
			refresh(false)
		else
			reset()
		end
	end)
	if props.ContentWidth then
		scope:Observer(props.ContentWidth):onChange(function()
			refresh(false)
		end)
	end

	task.defer(refresh, true)
	return list, {
		Refresh = function(force: boolean?)
			refresh(force)
		end,
		ScrollToIndex = scrollToIndex,
		Reset = reset
	}
end
