local RadioGroupContext = require("./RadioGroupContext")

export type RadioGroupContextType = RadioGroupContext.RadioGroupContextType

local function useRadioGroup(): RadioGroupContextType
	return RadioGroupContext:now()
end

return useRadioGroup
