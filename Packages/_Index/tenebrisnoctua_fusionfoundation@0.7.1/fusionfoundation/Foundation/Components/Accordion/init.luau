local AccordionRoot = require("@self/Accordion")
local AccordionItem = require("@self/Item")

local Accordion = {
	Root = AccordionRoot,
	Item = AccordionItem
}

export type AccordionProps = AccordionRoot.AccordionProps
export type AccordionItemProps = AccordionItem.AccordionItemProps

return Accordion
