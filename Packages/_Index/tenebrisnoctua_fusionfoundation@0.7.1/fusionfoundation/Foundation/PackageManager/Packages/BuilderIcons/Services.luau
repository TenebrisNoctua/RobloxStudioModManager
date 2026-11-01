local isLuwow = require("./isLuwow")

local Services = if isLuwow
	then {} :: any
	else {
		UserInputService = game:GetService("UserInputService"),
		GuiService = game:GetService("GuiService"),
	}

return Services
