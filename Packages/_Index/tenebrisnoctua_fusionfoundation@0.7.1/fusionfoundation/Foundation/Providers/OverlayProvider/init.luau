-- Written by @TenebrisNoctua
-- Provides an overlay ScreenGui for rendering floating content (popovers, dialogs, etc.).

local Datatypes = require("../Utility/Luwow/Datatypes")
local UDim2, Enum = Datatypes.UDim2, Datatypes.Enum
local Instances = require("../Utility/Luwow/Instances")
local New = Instances.New

local useKeyboardAwareSize = require("@self/useKeyboardAwareSize")
local ThemeProvider = require("./ThemeProvider")
local isLuwow = require("../Utility/isLuwow")

local unwrap = require("../Utility/unwrap")
local Types = require("../Utility/Types")
local Wrappers = require("../Utility/Wrappers")
local isPluginSecurity = require("../Utility/isPluginSecurity")

local CoreGui = Wrappers.Services.CoreGui
local RunService = Wrappers.Services.RunService
local Players = Wrappers.Services.Players

local Constants = require("../Constants")

local defaultDisplayOrder = Constants.MAX_LAYOUT_ORDER - 1

local overlayProvider = {
	instance = nil :: GuiBase2d?,
	screen = nil :: GuiBase2d?,
}

type UsedAs<T> = Types.UsedAs<T>
type Scope = Types.Scope

export type OverlayProviderProps = {
	scope: Scope,
	gui: UsedAs<GuiBase2d>? | any,
	DisplayOrder: UsedAs<number>?
}

type overlayProvider = typeof(overlayProvider)

--// Main Functions

local function getMainGui(): Instance?
	if isPluginSecurity() then
		return CoreGui
	end

	if not RunService:IsClient() or not Players.LocalPlayer or not RunService:IsRunning() then
		return nil
	end

	return Players.LocalPlayer:FindFirstChild("PlayerGui")
end

return function(props: OverlayProviderProps?): (overlayProvider, () -> ()?)
	if overlayProvider.instance then return overlayProvider end
	assert(props.scope, "OverlayProvider has not been provided a scope!")
	assert(props.gui, "OverlayProvider has not been provided a GuiObject!")

	local scope: Scope = props and props.scope
	local theme = ThemeProvider()
	local gui = props and unwrap(props.gui)
	local displayOrder = (props and unwrap(props.DisplayOrder)) or defaultDisplayOrder

	if gui then
		overlayProvider.instance = gui
		overlayProvider.screen = gui
		return overlayProvider
	end

	local mainGui = getMainGui()
	if not mainGui then
		return overlayProvider
	end
	
	local screenGui = New(scope, "ScreenGui") {
		Enabled = true,
		DisplayOrder = displayOrder,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		SafeAreaCompatibility = Enum.SafeAreaCompatibility.None,
		ClipToDeviceSafeArea = false,
		Parent = mainGui,
	}
	
	local safeAreaFrame = New(scope, "Frame") {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = screenGui
	}
	
	local foundationStyleLink = if isLuwow
		then { Destroy = function() end }
		else New(scope, "StyleLink") {
			StyleSheet = theme.RegistryStyleSheet,
			Parent = screenGui
		}
	
	local cleanup: () -> ()

	if scope then
		local safeAreaSize = useKeyboardAwareSize(scope, screenGui)
		cleanup = scope:Observer(safeAreaSize):onChange(function()
			safeAreaFrame.Size = unwrap(safeAreaSize)
		end)
	end

	overlayProvider.screen = screenGui
	overlayProvider.instance = safeAreaFrame

	return overlayProvider, function() 
		screenGui:Destroy()
		safeAreaFrame:Destroy()
		foundationStyleLink:Destroy()
		
		overlayProvider.screen = nil
		overlayProvider.instance = nil
		
		if cleanup then pcall(cleanup) end
	end
end