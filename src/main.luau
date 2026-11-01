--// Written by @TenebrisNoctua
--// The entry point for the RobloxModManager application.

const UIManager = require("@Frontend/managers/UIManager")
const Callbacks = require("@Backend")

UIManager.initialize(Callbacks)
UIManager.createUI()
