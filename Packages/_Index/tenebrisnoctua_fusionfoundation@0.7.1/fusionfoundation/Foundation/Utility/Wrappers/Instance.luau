local Instances = require("../Luwow/Instances")

local Instance = {
	GetPropertyChangedSignal = function(instance: Instance, propertyName: string)
		return Instances.getPropertyChangedSignal(instance, propertyName)
	end,
}

return Instance
