local RadioGroupRoot = require("@self/RadioGroup")
local RadioGroupItem = require("@self/Item")

local RadioGroup = {
	Root = RadioGroupRoot,
	Item = RadioGroupItem
}

export type RadioGroupProps = RadioGroupRoot.RadioGroupProps
export type RadioGroupItemProps = RadioGroupItem.RadioGroupItemProps

return RadioGroup
