local AccordionContext = require("./AccordionContext")

export type onAccordionItemActivated = AccordionContext.onAccordionItemActivated
export type AccordionConfiguration = AccordionContext.AccordionContextType

local function useAccordion(): AccordionConfiguration
	return AccordionContext:now()
end

return useAccordion
