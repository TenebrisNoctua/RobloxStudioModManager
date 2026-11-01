--!strict
--!nolint LocalUnused
--!nolint LocalShadow

--[[
	Roblox implementation of Fusion's runtime provider: Roblox's task
	scheduler and RunService for scheduling, instances, and Roblox datatypes
	for animation.
]]

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local Types = require("../Types")
local External = require("../External")
local RobloxTypes = require("./RobloxTypes")
local defaultProps = require("./RobloxDefaultProps")

local Roblox = {}

Roblox.name = "Roblox"

Roblox.policies = {
	allowWebLinks = RunService:IsStudio()
}

--[[
   Sends an immediate task to the external provider. Throws if none is set.
]]
function Roblox.doTaskImmediate(
	resume: () -> ()
)
   task.spawn(resume)
end

--[[
	Sends a deferred task to the external provider. Throws if none is set.
]]
function Roblox.doTaskDeferred(
	resume: () -> ()
)
	task.defer(resume)
end

--[[
	Errors in a different thread to preserve the flow of execution.
]]
function Roblox.logErrorNonFatal(
	errorString: string
)
	task.spawn(error, errorString, 0)
end

--[[
	Shows a warning message in the output.
]]
Roblox.logWarn = warn

--[[
	Sends an update step to Fusion using the Roblox clock time.
]]
local function performUpdateStep()
	External.performUpdateStep(os.clock())
end

--[[
	Binds Fusion's update step to RunService step events.
]]
local stopSchedulerFunc = nil :: (() -> ())?
function Roblox.startScheduler()
	if stopSchedulerFunc ~= nil then
		return
	end
	if RunService:IsClient() then
		-- In cases where multiple Fusion modules are running simultaneously,
		-- this prevents collisions.
		local id = "FusionUpdateStep_" .. HttpService:GenerateGUID()
		RunService:BindToRenderStep(
			id,
			Enum.RenderPriority.First.Value,
			performUpdateStep
		)
		stopSchedulerFunc = function()
			RunService:UnbindFromRenderStep(id)
		end
	else
		local connection = RunService.Heartbeat:Connect(performUpdateStep)
		stopSchedulerFunc = function()
			connection:Disconnect()
		end
	end
end

--[[
	Unbinds Fusion's update step from RunService step events.
]]
function Roblox.stopScheduler()
	if stopSchedulerFunc ~= nil then
		stopSchedulerFunc()
		stopSchedulerFunc = nil
	end
end

function Roblox.isInstance(
	x: unknown
): boolean
	return typeof(x) == "Instance"
end

function Roblox.className(
	instance: Instance
): string
	return instance.ClassName
end

--[[
	Creates an instance with the sensible defaults for its class, or returns
	nil when the class can't be created.
]]
function Roblox.newInstance(
	className: string
): Instance?
	local ok, instance = pcall(Instance.new, className)
	if not ok then
		return nil
	end

	local classDefaults = defaultProps[className]
	if classDefaults ~= nil then
		for defaultProp, defaultValue in pairs(classDefaults) do
			(instance :: any)[defaultProp] = defaultValue
		end
	end

	return instance
end

function Roblox.getProperty(
	instance: Instance,
	property: string
): unknown
	return (instance :: any)[property]
end

function Roblox.setProperty(
	instance: Instance,
	property: string,
	value: unknown
)
	(instance :: any)[property] = value
end

function Roblox.setParent(
	instance: Instance,
	parent: Instance?
)
	instance.Parent = parent
end

function Roblox.destroy(
	instance: Instance
)
	instance:Destroy()
end

local function getEvent(
	instance: Instance,
	eventName: string
): RBXScriptSignal?
	local ok, event = pcall(function()
		return (instance :: any)[eventName]
	end)
	if not ok or typeof(event) ~= "RBXScriptSignal" then
		return nil
	end
	return event
end

local function connect(
	event: RBXScriptSignal,
	callback: (...any) -> ()
): () -> ()
	local connection = event:Connect(callback)
	return function()
		connection:Disconnect()
	end
end

function Roblox.connectEvent(
	instance: Instance,
	eventName: string,
	callback: (...any) -> ()
): (() -> ())?
	local event = getEvent(instance, eventName)
	if event == nil then
		return nil
	end
	return connect(event, callback)
end

function Roblox.connectPropertyChanged(
	instance: Instance,
	property: string,
	callback: () -> ()
): (() -> ())?
	local ok, event = pcall(instance.GetPropertyChangedSignal, instance, property)
	if not ok then
		return nil
	end
	return connect(event, callback)
end

function Roblox.connectAttributeChanged(
	instance: Instance,
	attribute: string,
	callback: () -> ()
): (() -> ())?
	return connect(instance:GetAttributeChangedSignal(attribute), callback)
end

function Roblox.getAttribute(
	instance: Instance,
	attribute: string
): unknown
	return instance:GetAttribute(attribute)
end

function Roblox.setAttribute(
	instance: Instance,
	attribute: string,
	value: unknown
)
	instance:SetAttribute(attribute, value)
end

function Roblox.addTag(
	instance: Instance,
	tag: string
)
	instance:AddTag(tag)
end

function Roblox.removeTag(
	instance: Instance,
	tag: string
)
	instance:RemoveTag(tag)
end

function Roblox.isConnection(
	x: unknown
): boolean
	return typeof(x) == "RBXScriptConnection"
end

function Roblox.disconnect(
	connection: RBXScriptConnection
)
	connection:Disconnect()
end

-- Animation

Roblox.TweenInfo = TweenInfo

function Roblox.getEasedValue(
	alpha: number,
	easingStyle: Enum.EasingStyle,
	easingDirection: Enum.EasingDirection
): number
	return TweenService:GetValue(alpha, easingStyle, easingDirection)
end

Roblox.lerpType = RobloxTypes.lerpType
Roblox.packType = RobloxTypes.packType
Roblox.unpackType = RobloxTypes.unpackType

return Roblox :: Types.RuntimeProvider
