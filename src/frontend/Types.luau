--// Fusion Types

export type Scope = any
export type Value<T> = any
export type UsedAs<T> = T | any

--// Data Types

export type DeployVersion = {
	Id: string,
	Text: string,
	Unsupported: boolean
}

export type VersionHistory = {
	-- The deploy logs of the channel, newest first.
	Versions: {DeployVersion},
	-- The selected version's id, "" for (Use Latest).
	TargetVersion: string,
	-- Whether a version can be picked (HasHistory and a default channel).
	AllowTargetSelection: boolean,
	-- False when the channel name and token couldn't be used. The backend has already reset them to
	-- LIVE and no token.
	ChannelValid: boolean
}

-- One row of the flag lists, made for the row being shown and dropped once it scrolls away.
export type FlagData = {
	-- The flag's type and name together, what's copied to the clipboard.
	Key: string,
	Name: string,
	Type: string,
	Value: string,
	-- Whether it's overridden locally, highlighted in red in View Flags.
	Overridden: boolean
}

export type DialogResult = "Primary" | "None"
export type DialogIcon = "None" | "Information" | "Warning" | "Error"
export type DialogButton = "Primary" | "Close"

export type DialogOptions = {
	Title: string,
	-- A message, or a function building the content in the dialog's scope, no wider than maxWidth.
	Content: string | (scope: Scope, maxWidth: number) -> any,
	-- Hidden when nil or empty.
	PrimaryButtonText: string?,
	CloseButtonText: string,
	DefaultButton: DialogButton?,
	Icon: DialogIcon?,
	-- The window it belongs to, which takes no input while the dialog is open.
	Owner: any?,
	-- Whether the OS notification sound plays, true when left out.
	PlaySound: boolean?,
	-- Called when the primary button is pressed, before the dialog closes. Returning false keeps it open.
	OnPrimaryButtonClick: (() -> boolean)?
}

--// Component States

export type MainStates = {
	ReleaseTag: Value<string>,
	-- The Target Version items after.
	TargetVersions: Value<{DeployVersion}>,
	-- The selected version's id, "" for (Use Latest).
	SelectedVersion: Value<string>,
	TargetVersionEnabled: Value<boolean>,
	ChannelName: Value<string>,
	ChannelToken: Value<string>,
	ForceReinstall: Value<boolean>,
	-- While true the window takes no input and the loading ring spins.
	Busy: Value<boolean>
}

-- Given to the backend while it installs Studio.
export type BootstrapStates = {
	-- StatusFeed
	Status: Value<string>,
	Progress: Value<number>,
	MaxProgress: Value<number>,
	Indeterminate: Value<boolean>,
	-- EchoFeed: adds a line to the log.
	Echo: (message: string) -> (),
	-- ConfirmFeed: asks with an OK/Cancel warning, yields until it's answered.
	Confirm: (message: string, title: string) -> boolean,
	-- Closes the window without the "installation hasn't finished" prompt.
	RequestClose: () -> (),
	-- The window, as a dialog Owner.
	Window: any
}

export type FlagEditorStates = {
	-- How many flags View Flags lists, with the search applied.
	FlagCount: Value<number>,
	OverrideCount: Value<number>,
	-- The key of the selected row of each list, nil without one.
	SelectedFlag: Value<string?>,
	SelectedOverride: Value<string?>,
	Search: Value<string>,
	-- 1 for View Flags, 2 for Overrides.
	SelectedTab: Value<number>,
	Busy: Value<boolean>,
	-- Shows the rows again, after the backend changed flags.
	Refresh: () -> ()
}

--// Callbacks

export type AppCallbacks = {
	GetReleaseTag: () -> string,
	-- The program is ending, the state should be saved.
	Exiting: () -> ()
}

export type MainCallbacks = {
	-- Whether the mod manager was started with arguments, which launch Studio right away.
	HasLaunchArguments: () -> boolean,
	-- The latest release's tag, nil when it couldn't be fetched.
	FetchLatestReleaseTag: () -> string?,
	-- Opens the release page of the tag in the browser.
	OpenReleasePage: (releaseTag: string) -> (),
	FetchVersionHistory: (channelName: string, channelToken: string) -> VersionHistory,
	-- "" for (Use Latest).
	SetTargetVersion: (versionId: string) -> (),
	-- Installs and patches Studio, feeding the bootstrapper's states, copies the mod files over and
	-- starts Studio. Returns whether Studio was started, the program then ends.
	LaunchStudio: (forceReinstall: boolean, bootstrapper: BootstrapStates) -> boolean,
	OpenModFolder: () -> (),
	OpenStudioDirectory: () -> (),
	GetFlagWarningDisabled: () -> boolean,
	SetFlagWarningDisabled: (disabled: boolean) -> (),
	-- The version guid of the current Studio version.
	GetCurrentVersion: () -> string
}

export type BootstrapCallbacks = {
	-- The installed version's guid, "" when it isn't installed.
	GetInstalledVersion: () -> string,
	-- Installs the current version, feeding the bootstrapper's states.
	Install: (bootstrapper: BootstrapStates) -> (),
	-- The bootstrapper window closed, the state should be saved.
	Closed: () -> ()
}

export type FlagEditorCallbacks = {
	-- Loads every flag, returns how many there are.
	FetchAllFlags: () -> number,
	-- Applies the search, returns how many flags match. Matches are sorted by name.
	SearchFlags: (search: string) -> number,
	-- The flag at an index of the search's matches.
	GetFlag: (index: number) -> FlagData?,
	-- Returns how many overrides there are. Sorted by name.
	FetchOverrides: () -> number,
	GetOverride: (index: number) -> FlagData?,
	-- Overrides the flag, flipping a boolean flag's value.
	OverrideFlag: (key: string) -> (),
	RemoveOverride: (key: string) -> (),
	-- Removes every override, and the custom flags.
	RemoveAllOverrides: () -> (),
	-- Returns the value the override now has: the reset value when the input was bad, such as
	-- a non-number for an Int.
	SetOverrideValue: (key: string, value: string) -> string,
	-- Creates the custom flag, and overrides it. flagType is the class and type, such as "DFInt".
	AddCustomFlag: (flagType: string, name: string) -> (),
	-- The editor closed, the state should be saved.
	Closed: () -> ()
}

export type Callbacks = {
	App: AppCallbacks,
	Main: MainCallbacks,
	Bootstrap: BootstrapCallbacks,
	FlagEditor: FlagEditorCallbacks
}

return {}
