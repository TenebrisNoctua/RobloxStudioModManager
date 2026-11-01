--!nonstrict
local task = require("@Luwow/task")
local signal = require("@Luwow/signal")

local Services = {}

local function quietSignal()
	return signal.new()
end

--[[
	Fires every frame while anything is connected, with the time since the last
	frame, like RunService.Heartbeat.
]]
local function heartbeat()
	local fired = signal.new()
	local connected = 0
	local running = false

	local function loop()
		local last = os.clock()
		while connected > 0 do
			task.wait(1 / 60)
			local now = os.clock()
			fired:Fire(now - last)
			last = now
		end
		running = false
	end

	return {
		Connect = function(_, handler: (number) -> ())
			local connection = fired:Connect(handler)
			connected += 1
			if not running then
				running = true
				task.spawn(loop)
			end
			local disconnected = false
			return {
				Disconnect = function()
					if disconnected then
						return
					end
					disconnected = true
					connected -= 1
					connection:Disconnect()
				end,
			}
		end,
	}
end

Services.RunService = {
	Heartbeat = heartbeat(),
	IsRunning = function()
		return true
	end,
	IsClient = function()
		return true
	end,
	IsStudio = function()
		return false
	end,
}

Services.UserInputService = {
	PreferredInput = "KeyboardAndMouse",
	TouchEnabled = false,
	KeyboardEnabled = true,
	MouseEnabled = true,
	GamepadEnabled = false,
	OnScreenKeyboardVisible = false,
	OnScreenKeyboardPosition = vector.create(0, 0, 0),
	OnScreenKeyboardSize = vector.create(0, 0, 0),
	LastInputTypeChanged = quietSignal(),
	GetLastInputType = function()
		return "MouseMovement"
	end,
	GetStringForKeyCode = function(_, keyCode: any)
		return tostring(keyCode)
	end,
	GetPropertyChangedSignal = function()
		return quietSignal()
	end,
}

Services.GuiService = {
	SelectedObject = nil,
	FindFirstChild = function()
		return nil
	end,
	GetGuiInset = function()
		return vector.create(0, 0, 0), vector.create(0, 0, 0)
	end,
	IsTenFootInterface = function()
		return false
	end,
	GetPropertyChangedSignal = function()
		return quietSignal()
	end,
}

--[[
	Luwow can't measure text from scripts, so text is estimated: an average
	glyph is about half as wide as the text is tall.
]]
Services.TextService = {
	GetTextSize = function(_, text: string, size: number, _font: any, frameSize: vector?)
		local longest = 0
		local lines = 0
		for line in string.gmatch(text .. "\n", "([^\n]*)\n") do
			longest = math.max(longest, utf8.len(line) or #line)
			lines += 1
		end
		local width = longest * size * 0.5
		if frameSize ~= nil and frameSize.X > 0 then
			width = math.min(width, frameSize.X)
		end
		return vector.create(width, lines * size, 0)
	end,
}

Services.HttpService = {
	GenerateGUID = function(_, wrapInCurlyBraces: boolean?)
		local guid = string.gsub("xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx", "[xy]", function(c)
			local value = if c == "x" then math.random(0, 15) else math.random(8, 11)
			return string.format("%X", value)
		end)
		return if wrapInCurlyBraces == false then guid else `\{{guid}\}`
	end,
}

Services.LocalizationService = {
	RobloxLocaleId = "en-us",
	SystemLocaleId = "en-us",
}

Services.Players = {LocalPlayer = nil}
Services.CoreGui = nil
Services.ContentProvider = {
	PreloadAsync = function() end,
}

return Services
