local Popover = require("@self/Popover")
local PopoverAnchor = require("@self/Anchor")
local PopoverContent = require("@self/Content")

export type PopoverProps = Popover.PopoverProps
export type PopoverAnchorProps = PopoverAnchor.PopoverAnchorProps
export type PopoverContentProps = PopoverContent.PopoverContentProps

return {
	Root = Popover,
	Anchor = PopoverAnchor,
	Content = require("@self/PopoverContentProxy")
}
