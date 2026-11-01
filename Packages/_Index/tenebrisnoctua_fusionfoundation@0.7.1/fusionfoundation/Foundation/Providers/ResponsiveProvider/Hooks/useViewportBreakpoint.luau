local useBreakpoint = require("./useBreakpoint")

local Types = require("../../../Utility/Types")
local Breakpoint = require("../../../Enums/Breakpoint")

local OverlayProvider = require("../../OverlayProvider")

type UsedAs<T> = Types.UsedAs<T>
type Scope = Types.Scope
type Breakpoint = Breakpoint.Breakpoint

return function(scope: Scope): UsedAs<Breakpoint>
	local overlay = OverlayProvider()
	local breakpoint, _ = useBreakpoint(scope, overlay.screen)
	return breakpoint
end