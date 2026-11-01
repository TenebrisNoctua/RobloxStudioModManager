--!strict
--!nolint LocalUnused
--!nolint LocalShadow

--[[
	Instances for the Luwow runtime provider: stand-ins for Luwow gui objects.

	A Luwow control is created along with its parent. Fusion makes children
	before the instance they're parented to, so a stand-in keeps its
	properties and event handlers until it gets a parent, then creates the
	control with them, along with the children that were waiting for it. From
	then on, it passes properties and methods through to the control, and
	moves it when its Parent changes. A Window has no parent, it's created
	when a child or a method such as Show first needs it.

	Luwow controls only take event handlers in their descriptors, so each
	stand-in gives its control one handler per event, which calls the
	callbacks connected to the stand-in. Property changes come from the
	control's BindToPropertyChanged signals once it's created, and from the
	stand-in itself before.

	Helpers, such as a Stroke or a ListLayout, can't be without a parent in
	Luwow, so one removed from its parent is destroyed, and made again from
	its properties when it's put back in one.

	A control with pointer handlers is Active, so pointers hit it rather than
	what's behind it. Every stand-in has the handlers, so the ones of passive
	classes, such as View, are made inactive, and become active once something
	listens to their pointer events, unless their Active is set.
]]

local gui = require("@Luwow/udc")
local Rect = require("@Luwow/rect")
local UDim2 = require("@Luwow/udim2")

local External = require("../External")

type Callback = (...any) -> ()
type Callbacks = {Callback}

type Class = {
	create: (descriptor: {[string]: unknown}) -> any,
	ancestry: {[string]: boolean},
	events: {string},
	methods: {[string]: boolean},
	root: boolean,
	passive: boolean,
	defaults: {[string]: unknown}
}

type State = {
	className: string,
	class: Class,
	object: any?,
	properties: {[string]: unknown},
	parent: any?,
	waiting: {any},
	callbacks: {[string]: Callbacks},
	handlers: {[string]: Callback},
	changed: {[string]: Callbacks},
	signals: {[string]: any},
	detached: boolean,
	hidden: boolean,
	visible: unknown,
	bound: {[string]: (...any) -> ...any},
	destroyed: boolean,
	activeSet: boolean,
	listensToPointer: boolean,
	remembered: {[string]: unknown}
}

local LuwowInstance = {}

local classes: {[string]: Class} = {}

local function define(
	className: string,
	create: (...any) -> any,
	ancestors: {string},
	options: {
		events: {string}?,
		methods: {string}?,
		root: boolean?,
		passive: boolean?,
		defaults: {[string]: unknown}?
	}?
)
	local options = options or {}
	local ancestry = {[className] = true}
	for _, ancestor in ancestors do
		ancestry[ancestor] = true
	end
	local methods = {}
	for _, method in options.methods or {} do
		methods[method] = true
	end
	classes[className] = {
		create = create,
		ancestry = ancestry,
		events = options.events or {},
		methods = methods,
		root = options.root or false,
		passive = options.passive or false,
		defaults = options.defaults or {}
	}
end

local GUI = {"BaseGuiObject", "BaseObject"}
local CONTROL = {"ControlObject", "BaseGuiObject", "BaseObject"}
local TEXT = {"TextObject", "ControlObject", "BaseGuiObject", "BaseObject"}
local IMAGE = {"ImageObject", "ControlObject", "BaseGuiObject", "BaseObject"}

local function controlEvents(
	...: string
): {string}
	return {"OnEnter", "OnLeft", "OnPressed", "OnUnPressed", "OnInputBegan", "OnInputEnded", ...}
end

define("Window", gui.createWindow, GUI, {
	events = {"OnCloseRequested", "OnClosed", "OnFocused"},
	methods = {"Show", "Hide", "Close", "Focus", "Center", "SetClipboardText"},
	root = true
})
define("View", gui.createView, CONTROL, {events = controlEvents(), passive = true})
define("ScrollView", gui.createScrollView, CONTROL, {events = controlEvents()})
define("TextLabel", gui.createTextLabel, TEXT, {events = controlEvents(), passive = true})
define("TextButton", gui.createTextButton, TEXT, {events = controlEvents("OnActivated")})
define("TextInput", gui.createTextInput, TEXT, {
	events = controlEvents("OnChanged", "OnSubmitted", "OnFocusLost"),
	methods = {"Focus", "ReleaseFocus"}
})
local IMAGE_DEFAULTS = {Size = UDim2.fromScale(1, 1)}
define("ImageLabel", gui.createImageLabel, IMAGE, {events = controlEvents(), passive = true, defaults = IMAGE_DEFAULTS})
define("ImageButton", gui.createImageButton, IMAGE, {events = controlEvents("OnActivated"), defaults = IMAGE_DEFAULTS})
define("ListLayout", gui.createListLayout, GUI)
define("Corner", gui.createCorner, GUI)
define("Padding", gui.createPadding, GUI)
define("Stroke", gui.createStroke, GUI)
define("Gradient", gui.createGradient, GUI)

local UNCREATED_READS: {[string]: unknown} = {
	AbsolutePosition = vector.create(0, 0, 0),
	AbsoluteSize = vector.create(0, 0, 0),
	AbsoluteFrame = Rect.new(0, 0, 0, 0),
	AbsoluteContentSize = vector.create(0, 0, 0),
	ImageSize = vector.create(0, 0, 0),
	Focused = false,
}

--[[
	Stand-in -> its state. The state is kept on the stand-in under a private
	key rather than in a weak table: Luau's weak keys aren't ephemerons, so a
	state referring to stand-ins, as its parent and children do, would keep
	them all alive forever.
]]
local STATE = table.freeze({})
local states: {[any]: State} = setmetatable({}, {
	__index = function(_, standIn: any): State?
		return if type(standIn) == "table" then rawget(standIn, STATE) else nil
	end,
	__newindex = function(_, standIn: any, state: State?)
		rawset(standIn, STATE, state)
	end,
}) :: any

local POINTER_EVENTS = {OnEnter = true, OnLeft = true, OnPressed = true, OnUnPressed = true, OnInputBegan = true, OnInputEnded = true}

local function activate(
	state: State
)
	if not state.class.passive or state.activeSet then
		return
	end
	state.listensToPointer = true
	if state.object ~= nil then
		state.object.Active = true
	end
end
local standIns: {[any]: any} = setmetatable({}, {__mode = "kv"}) :: any

local METATABLE = {}

local function isDestroyed(
	state: State
): boolean
	if state.destroyed then
		return true
	end
	local object = state.object
	return object ~= nil and state.class.ancestry.BaseObject == true and object.Destroyed
end

local function fireChanged(
	state: State,
	property: string
)
	local callbacks = state.changed[property]
	if callbacks == nil then
		return
	end
	for _, callback in table.clone(callbacks) do
		callback()
	end
end

local function dispatch(
	state: State,
	event: string,
	...: any
)
	local handler = state.handlers[event]
	if handler ~= nil then
		handler(...)
	end
	local callbacks = state.callbacks[event]
	if callbacks ~= nil then
		for _, callback in table.clone(callbacks) do
			callback(...)
		end
	end
end

local function connect(
	list: Callbacks,
	callback: Callback
): () -> ()
	table.insert(list, callback)
	return function()
		local index = table.find(list, callback)
		if index ~= nil then
			table.remove(list, index)
		end
	end
end

local function followProperty(
	state: State,
	property: string
): boolean
	local object = state.object
	if object == nil or property == "Parent" or state.signals[property] ~= nil then
		return true
	end
	if not state.class.ancestry.BaseGuiObject then
		return false
	end
	local ok, signal = pcall(object.BindToPropertyChanged, object, property)
	if not ok then
		return false
	end
	state.signals[property] = signal:Connect(function()
		fireChanged(state, property)
	end)
	return true
end

local function objectValue(
	value: unknown
): unknown
	if type(value) == "table" and states[value] ~= nil then
		return LuwowInstance.objectOf(value)
	end
	return value
end

local function create(
	self: any,
	state: State,
	parentObject: any?
)
	local descriptor = {}
	for key, value in state.properties do
		descriptor[key] = objectValue(value)
	end
	for key, value in state.class.defaults do
		if descriptor[key] == nil then
			descriptor[key] = value
		end
	end
	descriptor.Parent = parentObject
	if state.class.passive and descriptor.Active == nil then
		descriptor.Active = state.listensToPointer == true
	end
	for _, event in state.class.events do
		descriptor[event] = function(...)
			dispatch(state, event, ...)
		end
	end

	state.object = state.class.create(descriptor)
	standIns[state.object] = self
	table.clear(state.properties)
	for property in state.changed do
		followProperty(state, property)
	end

	local waiting = state.waiting
	state.waiting = {}
	for _, child in waiting do
		local childState = states[child]
		if isDestroyed(childState) then
			continue
		elseif childState.object == nil then
			create(child, childState, state.object)
		else
			childState.object.Parent = state.object
		end
	end
end

local function objectOf(
	parent: any
): any?
	local state = states[parent]
	if state == nil then
		return parent
	end
	if state.object == nil and state.class.root then
		create(parent, state, nil)
	end
	return state.object
end

local function releaseObject(
	state: State
)
	local object = state.object
	if object == nil then
		return
	end
	for _, connection in state.signals do
		connection:Disconnect()
	end
	table.clear(state.signals)
	table.clear(state.bound)
	standIns[object] = nil
	state.object = nil
	state.detached = false
	state.parent = nil
	state.properties = table.clone(state.remembered)
	object:Destroy()
end

local function destroyObject(
	className: string,
	object: any
)
	object:Destroy()
end

local function nameOf(
	state: State
): string
	local name = if state.object ~= nil and state.class.ancestry.BaseObject and not state.object.Destroyed
		then state.object.Name
		else state.properties.Name
	return if typeof(name) == "string" then name else state.className
end

local function checkAlive(
	state: State
)
	if isDestroyed(state) then
		error(`{nameOf(state)} was destroyed`, 3)
	end
end

local function destroyMethod(
	self: any
)
	LuwowInstance.destroy(self)
end

local function isAMethod(
	self: any,
	className: string
): boolean
	return states[self].class.ancestry[className] == true
end

local function removeFromWaiting(
	parent: any?,
	self: any
)
	local parentState = states[parent]
	if parentState ~= nil then
		local index = table.find(parentState.waiting, self)
		if index ~= nil then
			table.remove(parentState.waiting, index)
		end
	end
end

function METATABLE.__index(
	self: any,
	key: string
): unknown
	local state = states[self]
	if key == "ClassName" then
		return state.className
	elseif key == "Parent" then
		return if state.detached then nil else state.parent
	elseif key == "Destroyed" then
		return isDestroyed(state)
	elseif key == "Destroy" then
		return destroyMethod
	elseif key == "IsA" then
		return isAMethod
	elseif key == "Name" and (state.object == nil or not state.class.ancestry.BaseObject) then
		return nameOf(state)
	end

	if typeof(key) ~= "string" or string.match(key, "^%l") then
		return nil
	end

	checkAlive(state)
	if state.object == nil and state.class.root and state.class.methods[key] then
		create(self, state, nil)
	end

	local object = state.object
	if object == nil then
		if state.class.methods[key] then
			return function()
				External.logError("notCreatedYet", nil, nameOf(state), key)
			end
		end
		local value = state.properties[key]
		if value == nil then
			value = UNCREATED_READS[key]
		end
		return value
	end

	if key == "Visible" and state.hidden then
		return state.visible
	end
	if key == "FetchChildren" then
		return LuwowInstance.fetchChildren
	end
	local value = object[key]
	if type(value) == "userdata" and standIns[value] ~= nil then
		return standIns[value]
	end
	if type(value) == "function" then
		local bound = state.bound[key]
		if bound == nil then
			bound = function(_, ...)
				return value(object, ...)
			end
			state.bound[key] = bound
		end
		return bound
	end
	return value
end

function METATABLE.__newindex(
	self: any,
	key: string,
	value: unknown
)
	local state = states[self]
	if key == "Parent" then
		LuwowInstance.setParent(self, value)
		return
	end
	checkAlive(state)

	if key == "Active" then
		state.activeSet = value ~= nil
	end
	if not state.class.ancestry.ControlObject and not state.class.root then
		state.remembered[key] = value
	end

	if table.find(state.class.events, key) then
		if value ~= nil and type(value) ~= "function" then
			error(`{key} must be a function`, 2)
		end
		state.handlers[key] = value :: Callback
		if value ~= nil and POINTER_EVENTS[key] then
			activate(state)
		end
		return
	end

	local object = state.object
	if object == nil then
		state.properties[key] = value
		fireChanged(state, key)
	elseif key == "Visible" and state.hidden then
		state.visible = value
		fireChanged(state, key)
	else
		object[key] = objectValue(value)
	end
end

function METATABLE.__tostring(
	self: any
): string
	return nameOf(states[self])
end

METATABLE.__metatable = "The metatable is locked"

--[[
	Whether a class can be made with new.
]]
function LuwowInstance.canCreate(
	className: string
): boolean
	return classes[className] ~= nil
end

--[[
	Makes a stand-in for a new object of the class, which is created once it
	has a parent.
]]
function LuwowInstance.new(
	className: string
): any
	local self = setmetatable({}, METATABLE)
	states[self] = {
		className = className,
		class = classes[className],
		object = nil,
		properties = {},
		parent = nil,
		waiting = {},
		callbacks = {},
		handlers = {},
		changed = {},
		signals = {},
		detached = false,
		hidden = false,
		visible = nil,
		bound = {},
		destroyed = false,
		activeSet = false,
		listensToPointer = false,
		remembered = {}
	}
	return self
end

--[[
	Whether the value is a stand-in.
]]
function LuwowInstance.is(
	x: unknown
): boolean
	return states[x] ~= nil
end

--[[
	Whether the value is a Luwow object Fusion can use as an instance, made by
	Fusion or not.
]]
function LuwowInstance.isObject(
	x: unknown
): boolean
	return states[x] ~= nil or classes[typeof(x)] ~= nil
end

function LuwowInstance.className(
	instance: any
): string
	local state = states[instance]
	return if state ~= nil then state.className else typeof(instance)
end

--[[
	The Luwow object of a stand-in, or nil while it isn't created. Luwow
	objects Fusion didn't make are given back as they are.
]]
function LuwowInstance.objectOf(
	instance: any
): any?
	local state = states[instance]
	if state == nil then
		return instance
	end
	return state.object
end

--[[
	The stand-in of a Luwow object Fusion made, or the object itself.
]]
function LuwowInstance.standInOf(
	object: any
): any
	return standIns[object] or object
end

--[[
	A stand-in's FetchChildren: the object's children, as their stand-ins.
]]
function LuwowInstance.fetchChildren(
	self: any
): {any}
	local children = states[self].object:FetchChildren()
	for index, child in children do
		children[index] = LuwowInstance.standInOf(child)
	end
	return children
end

--[[
	Parents a stand-in. Before it's created, it may be moved freely. Once it's
	created, its object moves with it. Luwow objects can't be without a
	parent, so one removed from its parent is hidden until it's put back in
	one.
]]
function LuwowInstance.setParent(
	self: any,
	parent: any?
)
	local state = states[self]
	if isDestroyed(state) then
		return
	end

	if state.object ~= nil and parent == nil then
		if state.detached then
			return
		end
		state.detached = true
		External.doTaskDeferred(function()
			if not state.detached or state.hidden or isDestroyed(state) then
				return
			end
			if not state.class.ancestry.ControlObject then
				releaseObject(state)
				return
			end
			state.visible = state.object.Visible
			state.object.Visible = false
			state.hidden = true
		end)
		fireChanged(state, "Parent")
		return
	end

	removeFromWaiting(state.parent, self)
	state.parent = parent

	if state.object ~= nil then
		state.detached = false
		if state.hidden then
			state.hidden = false
			state.object.Visible = state.visible
			state.visible = nil
		end
		local parentObject = objectOf(parent)
		if parentObject ~= nil then
			state.object.Parent = parentObject
		else
			table.insert(states[parent].waiting, self)
		end
	elseif parent ~= nil then
		local parentObject = objectOf(parent)
		if parentObject ~= nil then
			create(self, state, parentObject)
		else
			table.insert(states[parent].waiting, self)
		end
	end
	fireChanged(state, "Parent")
end

--[[
	Destroys a stand-in, along with its object and children like Luwow's
	Destroy.
]]
function LuwowInstance.destroy(
	self: any
)
	local state = states[self]
	if state.destroyed then
		return
	end
	state.destroyed = true

	for _, child in state.waiting do
		LuwowInstance.destroy(child)
	end
	table.clear(state.waiting)
	removeFromWaiting(state.parent, self)

	if state.object ~= nil then
		destroyObject(state.className, state.object)
	end
	for _, connection in state.signals do
		connection:Disconnect()
	end
	table.clear(state.signals)
	table.clear(state.callbacks)
	table.clear(state.handlers)
	table.clear(state.changed)
end

--[[
	Destroys a Luwow object Fusion didn't make.
]]
function LuwowInstance.destroyObject(
	object: any
)
	destroyObject(typeof(object), object)
end

--[[
	Connects a callback to an event of a stand-in, given with or without its
	On prefix: "OnActivated" or "Activated". Returns nil when the class has no
	such event.
]]
function LuwowInstance.connectEvent(
	self: any,
	event: string,
	callback: Callback
): (() -> ())?
	local state = states[self]
	local events = state.class.events
	if not table.find(events, event) then
		event = "On" .. event
		if not table.find(events, event) then
			return nil
		end
	end
	if POINTER_EVENTS[event] then
		activate(state)
	end
	local list = state.callbacks[event]
	if list == nil then
		list = {}
		state.callbacks[event] = list
	end
	return connect(list, callback)
end

--[[
	Runs what's connected to a stand-in's event, as when its control fires it,
	without input reaching the window. For tests.
]]
function LuwowInstance.dispatchEvent(
	self: any,
	event: string,
	...: any
)
	dispatch(states[self], event, ...)
end

--[[
	Connects a callback to a property's changes on a stand-in. Returns nil
	when the created object has no such property.
]]
function LuwowInstance.connectPropertyChanged(
	self: any,
	property: string,
	callback: () -> ()
): (() -> ())?
	local state = states[self]
	if not followProperty(state, property) then
		return nil
	end
	local list = state.changed[property]
	if list == nil then
		list = {}
		state.changed[property] = list
	end
	return connect(list, callback)
end

return LuwowInstance
