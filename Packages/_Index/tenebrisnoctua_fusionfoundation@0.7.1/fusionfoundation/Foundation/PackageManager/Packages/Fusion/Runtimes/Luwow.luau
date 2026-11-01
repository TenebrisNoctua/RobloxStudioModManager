--!strict
--!nolint LocalUnused
--!nolint LocalShadow

--[[
	Luwow implementation of Fusion's runtime provider: Luwow's task scheduler,
	gui objects through LuwowInstance stand-ins, tags through LuwowTags, and
	Luwow's datatypes for animation. Colors blend in Oklab space, their alpha
	along with them.

	Attributes have no Luwow equivalent, so using them is an error.
]]

local task = require("@Luwow/task")
local io = require("@Luwow/io")
local Color = require("@Luwow/color")
local UDim = require("@Luwow/udim")
local UDim2 = require("@Luwow/udim2")
local Rect = require("@Luwow/rect")

local Types = require("../Types")
local External = require("../External")
local Oklab = require("../Colour/Oklab")
local LuwowInstance = require("./LuwowInstance")
local LuwowTags = require("./LuwowTags")
local LuwowTweenInfo = require("./LuwowTweenInfo")

local UPDATE_INTERVAL = 1 / 60

local Luwow = {}

Luwow.name = "Luwow"

Luwow.policies = {
	allowWebLinks = true
}

--[[
   Sends an immediate task to the external provider. Throws if none is set.
]]
function Luwow.doTaskImmediate(
	resume: () -> ()
)
	task.spawn(resume)
end

--[[
	Sends a deferred task to the external provider. Throws if none is set.
]]
function Luwow.doTaskDeferred(
	resume: () -> ()
)
	task.defer(resume)
end

--[[
	Errors in a different thread to preserve the flow of execution.
]]
function Luwow.logErrorNonFatal(
	errorString: string
)
	task.spawn(error, errorString, 0)
end

--[[
	Shows a warning message on stderr.
]]
function Luwow.logWarn(
	errorString: string
)
	io.writeErr(errorString, "\n")
	io.flushErr()
end

local running = false
local stepping = false

--[[
	Sends update steps to Fusion using the clock time, for as long as they're
	needed. It stops when nothing needs them, so it doesn't keep the program
	alive once its animations are gone.
]]
local function stepLoop()
	while running and External.isUpdateStepNeeded() do
		local ok, err = pcall(External.performUpdateStep, os.clock())
		if not ok then
			Luwow.logErrorNonFatal(tostring(err))
		end
		task.wait(UPDATE_INTERVAL)
	end
	stepping = false
end

local function startStepping()
	if running and not stepping and External.isUpdateStepNeeded() then
		stepping = true
		task.spawn(stepLoop)
	end
end

function Luwow.startScheduler()
	running = true
	startStepping()
end

function Luwow.stopScheduler()
	running = false
end

function Luwow.setUpdateStepNeeded(
	needed: boolean
)
	if needed then
		startStepping()
	end
end

Luwow.isInstance = LuwowInstance.isObject
Luwow.className = LuwowInstance.className

--[[
	Makes a stand-in for the class, or returns nil when Luwow has no such
	class.
]]
function Luwow.newInstance(
	className: string
): Types.Instance?
	if not LuwowInstance.canCreate(className) then
		return nil
	end
	return LuwowInstance.new(className)
end

function Luwow.getProperty(
	instance: Types.Instance,
	property: string
): unknown
	return instance[property]
end

function Luwow.setProperty(
	instance: Types.Instance,
	property: string,
	value: unknown
)
	instance[property] = value
end

function Luwow.setParent(
	instance: Types.Instance,
	parent: Types.Instance?
)
	if LuwowInstance.is(instance) then
		LuwowInstance.setParent(instance, parent)
		return
	end
	local parentObject = if parent ~= nil then LuwowInstance.objectOf(parent) else nil
	if parentObject == nil then
		External.logError("unsupportedByRuntime", nil, "Luwow", `removing a {LuwowInstance.className(instance)} from its parent`)
	end
	instance.Parent = parentObject
end

function Luwow.destroy(
	instance: Types.Instance
)
	if LuwowInstance.is(instance) then
		LuwowInstance.destroy(instance)
	else
		LuwowInstance.destroyObject(instance)
	end
end

function Luwow.connectEvent(
	instance: Types.Instance,
	eventName: string,
	callback: (...any) -> ()
): (() -> ())?
	if not LuwowInstance.is(instance) then
		External.logError("unsupportedByRuntime", nil, "Luwow", `connecting to events of a {LuwowInstance.className(instance)} that Fusion didn't create`)
	end
	return LuwowInstance.connectEvent(instance, eventName, callback)
end

function Luwow.connectPropertyChanged(
	instance: Types.Instance,
	property: string,
	callback: () -> ()
): (() -> ())?
	if LuwowInstance.is(instance) then
		return LuwowInstance.connectPropertyChanged(instance, property, callback)
	end
	local ok, signal = pcall(function()
		return instance:BindToPropertyChanged(property)
	end)
	if not ok then
		return nil
	end
	local connection = signal:Connect(callback)
	return function()
		connection:Disconnect()
	end
end

local function unsupported(
	feature: string
): (...any) -> never
	return function(): never
		return External.logError("unsupportedByRuntime", nil, "Luwow", feature)
	end
end

Luwow.connectAttributeChanged = unsupported("attributes")
Luwow.getAttribute = unsupported("attributes")
Luwow.setAttribute = unsupported("attributes")
Luwow.addTag = LuwowTags.add
Luwow.removeTag = LuwowTags.remove

Luwow.tags = LuwowTags

function Luwow.isConnection(
	x: unknown
): boolean
	return typeof(x) == "SignalConnection"
end

function Luwow.disconnect(
	connection: Types.Connection
)
	connection:Disconnect()
end

-- Animation

Luwow.TweenInfo = {
	new = LuwowTweenInfo.new
}
Luwow.getEasedValue = LuwowTweenInfo.getEasedValue

--[[
	Packs an array of numbers into a given animatable data type.
	If the type is not animatable, nil will be returned.
]]
function Luwow.packType(
	numbers: {number},
	typeString: string
): Types.Animatable?
	if typeString == "vector" then
		return vector.create(numbers[1], numbers[2], numbers[3])
	elseif typeString == "Color" then
		local red, green, blue = Oklab.toSRGB(numbers[1], numbers[2], numbers[3], false)
		return Color.new(red, green, blue, math.clamp(numbers[4], 0, 1))
	elseif typeString == "UDim" then
		return UDim.new(numbers[1], numbers[2])
	elseif typeString == "UDim2" then
		return UDim2.new(numbers[1], numbers[2], numbers[3], numbers[4])
	elseif typeString == "Rect" then
		return Rect.new(numbers[1], numbers[2], numbers[3], numbers[4])
	end
	return nil
end

--[[
	Unpacks an animatable type into an array of numbers.
	If the type is not animatable, an empty array will be returned.
]]
function Luwow.unpackType(
	value: any,
	typeString: string
): {number}
	if typeString == "vector" then
		return {value.x, value.y, value.z}
	elseif typeString == "Color" then
		local L, a, b = Oklab.fromSRGB(value.R, value.G, value.B)
		return {L, a, b, value.A}
	elseif typeString == "UDim" then
		return {value.Scale, value.Offset}
	elseif typeString == "UDim2" then
		return {value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset}
	elseif typeString == "Rect" then
		return {value.X, value.Y, value.Width, value.Height}
	end
	return {}
end

--[[
	Linearly interpolates two values of the same type by a ratio, or returns
	nil when the type can't be animated. Colours are blended in Oklab space.
]]
function Luwow.lerpType(
	from: unknown,
	to: unknown,
	ratio: number,
	typeString: string
): unknown?
	if ratio == 0 then
		return from
	elseif ratio == 1 then
		return to
	end

	if typeString == "vector" then
		local from, to = from :: vector, to :: vector
		return from + (to - from) * ratio
	end

	local fromNumbers = Luwow.unpackType(from, typeString)
	if #fromNumbers == 0 then
		return nil
	end
	local toNumbers = Luwow.unpackType(to, typeString)
	for index, fromNumber in fromNumbers do
		fromNumbers[index] = (toNumbers[index] - fromNumber) * ratio + fromNumber
	end
	return Luwow.packType(fromNumbers, typeString)
end

return Luwow :: Types.RuntimeProvider
