-- This file contains sections of Legend of Grimrock 2 source code; anything you
-- do with this file must comply with the Grimrock modding terms:
-- http://www.grimrock.net/modding_log1/modding-and-asset-usage-terms/
--
-- You are free to alter this mod or reuse its code in other Grimrock mods.

--[=[
=== UModManager Info Section ===
id = "eventLog"
name = "Event Log"
description = [[This mod adds an in-game event log GUI to allow review of all in-game events.

Made by Violgamba.]]
version = "1.0"
modifiedFields = {
	"GuiItem", "Gui:draw", "PauseMenu:update", "MainMenu:update", "GameMode:newGame", "GameMode:loadGame", "Champion:setEnabled", "DungeonEditor:playPreview", "GameMode:keyPressed", "UsableItemComponent:onUseItem", "Champion:addToBackpack", "CharSheet:slotClicked", "ChestComponent:onClick", "LockComponent:onClick", "ItemComponent:dropItemToFloor", "ItemComponent:dragItemToThrowZone", "ThrowAttackComponent:start", "RangedAttackComponent:start", "FirearmAttackComponent:start", "ItemComponent:onClickComponent", "SmallFishControllerComponent:onClick", "PartyComponent:pickUpAmmo", "Champion:autoPickUp", "SocketComponent:onClick", "SurfaceComponent:onClick", "CraftPotionComponent:brewPotion", "TileDamagerComponent:setCastByChampion", "MonsterComponent:throwItem", "MonsterComponent:shootProjectile", "MonsterComponent:onAttackedByChampion", "MonsterAttackComponent:attackParty", "damageTile", "ItemComponent:projectileHitEntity", "MonsterComponent:damage", "Champion:damage", "MonsterComponent:die", "Champion:regainHealth", "Champion:regainEnergy", "Champion:setCondition", "Champion:updateConditions", "MonsterComponent:setCondition", "PartyComponent:updateDiving", "PartyComponent:onFallingImpact", "PoisonCondition:tick", "ButtonComponent:onClick", "FloorTriggerComponent:activate", "FloorTriggerComponent:deactivate", "LeverComponent:toggle", "PartyComponent:rest", "PartyComponent:wakeUp", "DiggingToolComponent:onPartyWakeUp", "RopeToolComponent:onPartyWakeUp", "CrystalComponent:onClick", "SecretComponent:activate", "Champion:levelUp", "Champion:addSkillPoints", "CharSheet:skillsTab", "DiggingToolComponent:diggingFinished", "Champion:gainExp", "Champion:trainSkill", "Champion:addTrait", "Champion:modifyBaseStat"
}
overwrittenFields = { "TileDamagerComponent:setCastByChampion" }
compatibilityOverrides = {}
requiredMods = {}
=== End of Mod Info ===
]=]

EventLog = class()

-- Consts
local SHORT_TEXT_HEIGHT = 19
local FULL_TEXT_HEIGHT = 22
local PADDING = 5
local MIN_WIN_WIDTH = 550
local MIN_WIN_HEIGHT = SHORT_TEXT_HEIGHT + PADDING * 4
local MIN_WIN_LEFT = config.width * 0.029
local MIN_WIN_BOTTOM = config.height - MIN_WIN_HEIGHT + config.height * .02
local MIN_INNER_BACK_SHORTENING = -39
local MIN_TEXT_OFFSET_X = 4
local MIN_TEXT_OFFSET_Y = -5
local BUTTON_MAX_TOGGLE_OFFSET_X = -42 
local BUTTON_MAX_TOGGLE_OFFSET_Y = -9
local MAX_WIN_WIDTH = 550
local MAX_WIN_HEIGHT = 652
local MAX_WIN_OFFSET = 2
local TITLE_OFFSET_X = 271
local TITLE_OFFSET_Y = 47
local FILTER_OFFSET_X = 79
local FILTER_OFFSET_Y = 563
local FILTER_WIDTH = 243
local BUTTON_CUSTOM_OFFSET_X = 290
local BUTTON_CUSTOM_OFFSET_Y = 563
local BUTTON_COPY_OFFSET_X = 334
local BUTTON_COPY_OFFSET_Y = 559
local BUTTON_CLEAR_OFFSET_X = 400
local BUTTON_CLEAR_OFFSET_Y = 557
local SCROLL_OFFSET_X = 36
local SCROLL_OFFSET_Y = 103
local SCROLL_WIDTH = 458
local SCROLL_HEIGHT = 446
local SCROLL_TEXT_OFFSET_X = 5
local SCROLL_TEXT_OFFSET_Y = 19
local CATEGORY_WIDTH = 85
local BASE_FILTERS = { "EFFECT", "ACTION", "ITEM", "STATS", "CUSTOM", "ALL", "COMBAT" }
local INDEX_OF_ALL_FILTER = 6
local RECIPROCAL_TYPES = { { "taken from", "given to" }, { "held in", "removed from" }, { "worn on", "removed from" } }

-- Gui images
local imagePath = "assets/textures/gui/gui_items.tga"
GuiItem["logMinBack1"]        = { x = 551;  y = 2308;      width = 575; height = 112;  image = imagePath }
GuiItem["logMinBack2"]        = { x = 708;  y = 2501;      width = 250; height = 21;   image = imagePath }
GuiItem["logOpen"]            = { x = 2162; y = 2220+42*0; width = 42;  height = 42;   image = imagePath }
GuiItem["logClose"]           = { x = 2162; y = 2220+42*1; width = 42;  height = 42;   image = imagePath }
GuiItem["logOpenHover"]       = { x = 2162; y = 2220+42*2; width = 42;  height = 42;   image = imagePath }
GuiItem["logCloseHover"]      = { x = 2162; y = 2220+42*3; width = 42;  height = 42;   image = imagePath }
GuiItem["logMaxBack"]         = { x = 0;    y = 775;       width = 550; height = 652;  image = imagePath }
GuiItem["logBtnCustom"]       = { x = 2443; y = 1892;      width = 37;  height = 21;   image = imagePath }
GuiItem["logBtnCustomHover"]  = { x = 2443; y = 2001;      width = 37;  height = 21;   image = imagePath }
-- "Internal" fields
local scrollInnerHeight = 8
local scrollPosition = 0
local scrollSmooth = 0
local filteredEntries = {}
local customLogText = nil
-- The game crashes if rendering too many logs.  300 appears safe (never seen it crash under ~340).
EventLog.maxHistory = 300


-----------------------
-- HELPER FUNCTIONS --
-----------------------
local function areArraysEquivalent(a1, a2)
	if #a1 ~= #a2 then return false end
	for i = 1, #a1 do
		if a1[i] ~= a2[i] then return false end
	end
	return true
end

-- Capitalize the first letter of the string
local function firstToUpper(str)
    return (str:gsub("^%l", string.upper))
end

-- Returns whether the given string starts with the given prefix
function string.startsWith(String,Start)
   return (string.sub(String, 1, string.len(Start)) == Start)
end

-- I'm surprised the following Gui functions aren't already part of the Gui system.  They are
-- modified versions of existing Gui functions.  I wouldn't have added spurious methods to the GUI
-- system, except that seemed like the best way to access member fields self.guiScale, etc.

-- Draw a gui item with a custom destination size
function Gui:drawGuiItem_scaled(item, x, y, dstWidth, dstHeight, color)
	color = color or Color.White
	if item.offsetX then x = x + item.offsetX end
	if item.offsetY then y = y + item.offsetY end

	x = x * self.guiScale + self.guiBiasX
	y = y * self.guiScale + self.guiBiasY

	dstWidth = dstWidth * self.guiScale
	dstHeight = dstHeight * self.guiScale

	if not item.texture then
		item.texture = RenderableTexture.load(item.image)
	end

	ImmediateMode.drawImage(item.texture, x, y, item.x, item.y, item.width, item.height, dstWidth, dstHeight, color)
end

-- Draw a combo box with a custom destination width
function Gui:comboBox_customWidth(id, x, y, width, value, choices, style, tooltip)
	local height = 20
	local leftSideOffset = 30 * width / 180 -- adjust the "left-button" size to match the width

	gui:drawGuiItem_scaled(GuiItem.ComboBox, x-leftSideOffset, y, width, height)
	if gui:buttonLogic(id, x-leftSideOffset, y, width, height, nil, tooltip) then
		local mx,my = sys.mousePos()
		if mx < x then
			-- left
			value = iff(value > 1, value - 1, #choices)
		else
			-- right
			value = iff(value < #choices, value + 1, 1)
		end
		soundSystem:playSound2D("click_down")
	end

	local font = FontType.PalatinoTinyScaled
	local color = Color.White
	if style == "disabled" then color = {100,100,100,255} end
	gui:drawTextCentered(choices[value], x + width/2 - leftSideOffset, y + 15, font, color)

	return value
end


-----------
-- Class --
-----------
EventLog.entries = {}
EventLog.isUiMaximized = false
EventLog.currentFilterIndex = INDEX_OF_ALL_FILTER
EventLog.filters = {}
-- Events often trigger other events (attack -> dead -> xp).  Most events are logged after they're
-- finished, so such chained events are logged in reverse order.  Stacking lets us reverse the order
EventLog.eventStack = {}
EventLog.eventStackLogEntries = {}

-- Adds a new entry to the event log
function EventLog:addLogEntry(category, text, forceWhileResting)
	-- Don't accept entries unless the real filters are setup
	if #self.filters == 0 then return end

	-- Block most entries while resting
	if party.resting and not forceWhileResting then return end

	local newEntry = { category, text }

	-- If events are stacked, store this log entry for later (for after event stacking is finished)
	if #self.eventStack > 0 then
		self.eventStackLogEntries[#self.eventStackLogEntries+1] = newEntry
		return
	end

	-- Check for whether this entry that undos the prior one ("taken from" & "given to" for example)
	if self:handleReciprocalEntries(newEntry) then
		return
	end

	-- Add the new log entry
	self.entries[#self.entries + 1] = newEntry
	if self:entryMatchesFilter(newEntry, self.filters[self.currentFilterIndex]) then
		filteredEntries[#filteredEntries+1] = newEntry
	end

	-- Limit log entry count to avoid memory bloat
	while #self.entries > self.maxHistory do
		self:removeLogEntry(true)
	end

	self:calculateScrollUi()
end

function EventLog:pushEvent(eventId)
	self.eventStack[#self.eventStack+1] = eventId
end

function EventLog:popEvent(eventId)
	local stackSize = #self.eventStack
	if stackSize > 0 then
		if self.eventStack[stackSize] == eventId then
			table.remove(self.eventStack)
		else
			console:print(
				"WARNING: EventLog event stack out of whack.  Resetting stack.  " +
				"(Expected '" .. self.eventStack[stackSize] .. "', given '" .. eventId .. "')")
			self.eventStack = {}
		end
		stackSize = #self.eventStack
	end
	if stackSize == 0 then
		for i = #self.eventStackLogEntries, 1, -1 do
			self:addLogEntry(self.eventStackLogEntries[i][1], self.eventStackLogEntries[i][2], true)
		end
		self.eventStackLogEntries = {}
	end
end

function EventLog:removeLogEntry(fromBack)
	if #self.entries == 0 then return end

	local filteredIndexToRemove = fromBack and 1 or #filteredEntries
	local rawIndexToRemove = fromBack and 1 or #self.entries

	if #filteredEntries ~= 0 and areArraysEquivalent(filteredEntries[filteredIndexToRemove], self.entries[rawIndexToRemove]) then
		table.remove(filteredEntries, filteredIndexToRemove)
	end
	local result = table.remove(self.entries, rawIndexToRemove)
	self:calculateScrollUi()
	return result
end

-- This is called AFTER the party is generated as some filters are based on party names.
function EventLog:init()
	-- Start with the base filters
	self.filters = {}
	for i = 1, #BASE_FILTERS do
	 self.filters[#self.filters+1] = BASE_FILTERS[i]
	end

	-- Add a combat filter for each character
	for i = 1, 4 do
		if party.champions[i].enabled then
			self.filters[#self.filters+1] = "COMBAT: " .. party.champions[i].name
		end
	end

	-- Reset current filter to "All"
	self.currentFilterIndex = INDEX_OF_ALL_FILTER

	-- Clear entries - change of party means change of game.  Don't keep entries from old game
	self.entries = {}
	filteredEntries = {}
end

function EventLog:entryMatchesFilter(entry, filter)
	if filter == "ALL" then
		return true
	elseif filter:sub(1,8) == "COMBAT: " then
		-- Champion-specific combat filters - must be combat category and start with champion name
		return (
			entry[1] == "COMBAT" and
			entry[2]:sub(1, filter:len()-8) == filter:sub(9))
	else
		return (entry[1] == filter)
	end
end

function EventLog:handleReciprocalEntries(newEntry)
	local latestEntry = self.entries[#self.entries]
	if latestEntry == nil then return false end -- If there aren't any entries yet, do nothing

	-- Reciprocal entries have the same category and different messages
	if newEntry[1] ~= latestEntry[1] or newEntry[2] == latestEntry[2] then return false end

	-- check each reciprocal type
	for _,v in ipairs(RECIPROCAL_TYPES) do
		if latestEntry[2] == newEntry[2]:gsub(v[1], v[2]) or
		   latestEntry[2] == newEntry[2]:gsub(v[2], v[1]) then
			self:removeLogEntry()
			return true
		end
	end

	return false
end

function EventLog:calculateScrollUi(forceSnapToBottom)
	-- Determine scroll height based on count of filtered entries
	scrollInnerHeight = #filteredEntries * FULL_TEXT_HEIGHT + 8

	-- Determine if scroll is near the bottom of the list
	local absoluteScrollPosition = (scrollInnerHeight - SCROLL_HEIGHT - scrollSmooth)
	local isNearBottom = (absoluteScrollPosition > 0) and (absoluteScrollPosition < FULL_TEXT_HEIGHT * 4)

	-- Snap to the bottom, if near it
	if scrollInnerHeight > SCROLL_HEIGHT then
		if isNearBottom or forceSnapToBottom then
			scrollPosition = (scrollInnerHeight - SCROLL_HEIGHT)
			scrollSmooth = scrollPosition
		end
	else
		scrollPosition = 0
		scrollSmooth = 0
	end
end

-- Called each frame by the modified GUI system
function EventLog:drawUi(setupImmediateMode)
	if setupImmediateMode then
		ImmediateMode.beginDraw()
	end

	-- ALWAYS draw the minimized ui
	self:drawMinimizedUi()

	-- Conditionally draw the maximized ui
	if self.isUiMaximized then
		self:drawMaximizedUi()
	end

	if setupImmediateMode then
		ImmediateMode.endDraw()
	end
end

function EventLog:drawMinimizedUi()

	-- Back
	gui:drawGuiItem_scaled(GuiItem.logMinBack1, MIN_WIN_LEFT, MIN_WIN_BOTTOM - MIN_WIN_HEIGHT, MIN_WIN_WIDTH, MIN_WIN_HEIGHT)

	-- Indented back
	gui:drawGuiItem_scaled(GuiItem.logMinBack2, MIN_WIN_LEFT + PADDING, MIN_WIN_BOTTOM - MIN_WIN_HEIGHT + PADDING, MIN_WIN_WIDTH - PADDING * 2 + MIN_INNER_BACK_SHORTENING, MIN_WIN_HEIGHT - PADDING * 2)

	-- Text
	if customLogText then
		gui:drawText(customLogText .. "_", MIN_WIN_LEFT + PADDING * 2 + MIN_TEXT_OFFSET_X, MIN_WIN_BOTTOM - PADDING * 2 + MIN_TEXT_OFFSET_Y, FontType.PalatinoTinyScaled)
	elseif #filteredEntries > 0 then
		gui:drawText(filteredEntries[#filteredEntries][1] .. ":  " .. filteredEntries[#filteredEntries][2], MIN_WIN_LEFT + PADDING * 2 + MIN_TEXT_OFFSET_X, MIN_WIN_BOTTOM - PADDING * 2 + MIN_TEXT_OFFSET_Y, FontType.PalatinoTinyScaled)
	end

	-- Button (open)
	if not self.isUiMaximized then
		if gui:button("logOpen", GuiItem.logOpen,   MIN_WIN_LEFT + MIN_WIN_WIDTH + BUTTON_MAX_TOGGLE_OFFSET_X, MIN_WIN_BOTTOM - MIN_WIN_HEIGHT + PADDING + BUTTON_MAX_TOGGLE_OFFSET_Y, GuiItem.logOpenHover, "Open the event log") then
			self.isUiMaximized = true
		end

	-- Button (close)
	else
		if gui:button("logClose", GuiItem.logClose, MIN_WIN_LEFT + MIN_WIN_WIDTH + BUTTON_MAX_TOGGLE_OFFSET_X, MIN_WIN_BOTTOM - MIN_WIN_HEIGHT + PADDING + BUTTON_MAX_TOGGLE_OFFSET_Y, GuiItem.logCloseHover, "Close the event log") then
			self.isUiMaximized = false
		end
	end
end

function EventLog:drawMaximizedUi()
	-- Ui position
	local leftOffset = MIN_WIN_LEFT
	local topOffset = MIN_WIN_BOTTOM - MIN_WIN_HEIGHT - MAX_WIN_HEIGHT + MAX_WIN_OFFSET

	-- Backdrop
	gui:drawGuiItem(GuiItem.logMaxBack, leftOffset, topOffset)

	-- Title
	gui:drawTextCentered("Event Log", leftOffset + TITLE_OFFSET_X, topOffset + TITLE_OFFSET_Y, FontType.PalatinoLargeScaled)

	-- Combo - filter
	local newFilterIndex = gui:comboBox_customWidth("logFilter", leftOffset + FILTER_OFFSET_X, topOffset + FILTER_OFFSET_Y, FILTER_WIDTH, self.currentFilterIndex, self.filters, nil, "Filter the log by event type.")
	if newFilterIndex ~= self.currentFilterIndex then
		self.currentFilterIndex = newFilterIndex
		filteredEntries = {}
		for i = 1, #self.entries do
			if self:entryMatchesFilter(self.entries[i], self.filters[self.currentFilterIndex]) then
				filteredEntries[#filteredEntries+1] = self.entries[i]
			end
		end
		self:calculateScrollUi(true)
	end

	-- Button - custom log entry
	if gui:button("custom", GuiItem.logBtnCustom, leftOffset + BUTTON_CUSTOM_OFFSET_X, topOffset + BUTTON_CUSTOM_OFFSET_Y, GuiItem.logBtnCustomHover, not customLogText and "Add a custom log entry." or "Cancel custom log entry.") then
		if not customLogText then
			customLogText = ""
		else
			customLogText = nil
		end
	end

	-- Button - copy
	if gui:button("copy", GuiItem.MapButtonHover, leftOffset + BUTTON_COPY_OFFSET_X, topOffset + BUTTON_COPY_OFFSET_Y, GuiItem.MapButtonHover, "Copy the log to the clipboard.") then
		local logText = ""
		for i = 1, #filteredEntries do
			logText = logText .. filteredEntries[i][1] .. ":  " .. filteredEntries[i][2] .. "\n"
		end
		sys.setClipboard(logText)
		gui:hudPrint("Log copied to the clipboard")
	end

	-- Button - clear
	if gui:button("clear", GuiItem.ButtonClear, leftOffset + BUTTON_CLEAR_OFFSET_X, topOffset + BUTTON_CLEAR_OFFSET_Y, GuiItem.ButtonClearHover, "Clear the log.") then
		self.entries = {}
		filteredEntries = {}
		self:calculateScrollUi()
	end

	-- Start a scroll area for the log entries
	scrollPosition = gui:beginScrollArea("logScroll", leftOffset + SCROLL_OFFSET_X, topOffset + SCROLL_OFFSET_Y, SCROLL_WIDTH, SCROLL_HEIGHT, scrollPosition, scrollInnerHeight, FULL_TEXT_HEIGHT)
	scrollPosition, scrollSmooth = gui:smoothScroll(scrollPosition, scrollSmooth)

	-- Draw the log entries
	local listOffset = 0
	for i= 1, #filteredEntries do
		gui:drawText(filteredEntries[i][1], leftOffset + SCROLL_OFFSET_X + SCROLL_TEXT_OFFSET_X, topOffset - scrollSmooth + listOffset + SCROLL_OFFSET_Y + SCROLL_TEXT_OFFSET_Y, FontType.PalatinoTinyScaled)
		gui:drawText(filteredEntries[i][2], leftOffset + SCROLL_OFFSET_X + SCROLL_TEXT_OFFSET_X + CATEGORY_WIDTH, topOffset - scrollSmooth + listOffset + SCROLL_OFFSET_Y + SCROLL_TEXT_OFFSET_Y, FontType.PalatinoTinyScaled)
		listOffset = listOffset + FULL_TEXT_HEIGHT
	end

	-- End the scroll area
	gui:endScrollArea()
end


---------------
-- OVERRIDES --
---------------

-- These are overridden to render eventlog's ui
local orig_gui_draw = Gui.draw
function Gui:draw(...)
	self:setGuiScaling(self.uiScaleFactor, 0, config.height)
	EventLog:drawUi(true) -- Draw EventLog before the rest so that tooltips show over it
	return orig_gui_draw(self, ...)
end
local orig_pauseMenu_update = PauseMenu.update
function PauseMenu:update(...)
	local result = orig_pauseMenu_update(self, ...)
	EventLog:drawUi() -- Draw EventLog after the rest so that it's on top of the dimmer
	return result
end
local orig_mainMenu_update = MainMenu.update
function MainMenu:update(...)
	if #EventLog.filters > 0 then
		EventLog:drawUi()
	end
	return orig_mainMenu_update(self, ...)
end

-- These overrides are all to populate the filters based on champion names
local orig_gameMode_newGame = GameMode.newGame
function GameMode:newGame(...)
	EventLog.filters = {} -- Disable filters while setting up the characters
	local result = orig_gameMode_newGame(self, ...)
	EventLog:init()
	return result
end
local orig_gameMode_loadGame = GameMode.loadGame
function GameMode:loadGame(...)
	EventLog.filters = {} -- Disable filters while setting up the characters
	local result = orig_gameMode_loadGame(self, ...)
	EventLog:init()
	return result
end
local orig_champion_setEnabled = Champion.setEnabled
function Champion:setEnabled(...)
	EventLog.filters = {} -- Disable filters while setting up the characters
	local result = orig_champion_setEnabled(self, ...)
	EventLog:init()
	return result
end
local orig_dungeonEditor_playPreview = DungeonEditor.playPreview
function DungeonEditor:playPreview(...)
	EventLog.filters = {} -- Disable filters while setting up the characters
	local result = orig_dungeonEditor_playPreview(self, ...)
	-- Party can be nil if run-game button is hit without a dungeon loaded
	if party ~= nil then
		EventLog:init()
	end
	return result
end

-- "Escape" will unmaximize the event log
-- "O" key will toggle maximizing the event log
-- While in custom log entry mode, many keystrokes are used for the text entry
local orig_gameMode_keyPressed = GameMode.keyPressed
function GameMode:keyPressed(event, ...)
	if customLogText then
		if event.key == 'enter' then
			EventLog:addLogEntry("CUSTOM", customLogText, true)
			customLogText = nil
			return
		elseif event.key == 'escape' then
			customLogText = nil
			return
		elseif event.key == 'backspace' and #customLogText > 0 then
			customLogText = customLogText:sub(1, #customLogText - 1)
			return
		elseif event.char and FontType.PalatinoSmallScaled:isPrintable(event.char) and #customLogText < 200 then
			customLogText = customLogText .. event.char
			return
		end
	else
		if event.key == "escape" and EventLog.isUiMaximized then
			EventLog.isUiMaximized = false
			return
		end
		if event.key == "O" then
			EventLog.isUiMaximized = not EventLog.isUiMaximized
		end
	end
	return orig_gameMode_keyPressed(self, event, ...)
end


---------------------------------
-- EVENTS TO LOG - HELPER FNCS --
---------------------------------
-- Which stats to log changes for
local STATS_CHANGES_TO_LOG = {
	"max_health", "max_energy", "strength", "dexterity", "vitality", "willpower", "resist_fire",
	"resist_shock", "resist_poison", "resist_cold"
}
-- Set to true during special xp monitors (killing mobs & digging chests) so that the generic xp+
-- logs don't trigger
local isMonitoringXp = false
-- True during normal skill point count changes.  Allows logging unusual skill point bonuses (tome).
local isNormalSkillPointChange = false
-- Since attack logs need info from multiple functions, these vars are set from those functions.
local attackerName = nil
local dualWieldText = ""
-- The resting mechanism is used for actions such as digging and rope climbing.  Logging should
-- be handled differently in these cases.
local currentRestIsForAction = false
-- Store hp & ep before resting to log changes after resting
local preRestHp = nil
local preRestEp = nil

-- Get a list of all reachable entities that are items
function getPartyReachableItems()
	local result = {}
	for i,v in party:reachableEntities() do
		if v.item then
			result[#result+1] = v.item
		end
	end
	return result
end

-- Get name for the given item, including "" if the item is nil
local function getItemName(item)
	return item and item.go.arch.name or ""
end

-- Get counting for the given item, including 0 if the item is nil
local function getItemCount(item)
	return item and item.count or 0
end

-- Get the item state: type and count, of the given item (default: mouseItem) as a single value
local function getItemState(item, noDefault)
	if not noDefault then
		item = item or gui:getMouseItem()
	end
	return { getItemName(item), getItemCount(item) }
end

-- Return whether the given item's state (default: mouseItem) has changed from the given oldState
local function itemStateHasChanged(oldState, item, noDefault)
	if not noDefault then
		item = item or gui:getMouseItem()
	end
	local state = getItemState(item)
	return state[1] ~= oldState[1] or state[2] ~= oldState[2]
end

-- Figure out what, if anything, was lost between the given item states
local function getLossBetweenItemStates(oldState, newState)
	if oldState[1] ~= newState[1] then
		return oldState
	elseif oldState[2] > newState[2] then
		return { oldState[1], oldState[2] - newState[2] }
	else
		return { "", 0 }
	end
end

local function getItemStateDisplayName(state, skipTheCount)
	if state[1] == "" or state[2] == 0 then
		return ""
	else
		if state[2] == 1 or skipTheCount then
			return firstToUpper(state[1])
		else
			return firstToUpper(state[1]) .. " (" .. state[2] .. ")"
		end
	end
end

local function getItemDisplayName(item, skipTheCount)
	return getItemStateDisplayName(getItemState(item), skipTheCount)
end

-- Get the party's hp state as a single value
local function getPartyHpState()
	return {
		party.champions[1]:getHealth(),
		party.champions[2]:getHealth(),
		party.champions[3]:getHealth(),
		party.champions[4]:getHealth()
	}
end

-- Log any changes to the party's hp state from the given oldState
local function logPartyHpStateChanges(oldState, changeMessage, negate, category)
	category = category or "EFFECT"
	local state = getPartyHpState()
	for i=1,4 do
		local change = math.floor(state[i] - oldState[i])
		if negate then change = -change end
		if change ~= 0 then
			local msg = changeMessage:gsub("$name", party.champions[i].name):gsub("$change", change)
			EventLog:addLogEntry(category, msg)
		end
	end
end

-- Get the party's ep (energy point) state as a single value
local function getPartyEpState()
	return {
		party.champions[1]:getEnergy(),
		party.champions[2]:getEnergy(),
		party.champions[3]:getEnergy(),
		party.champions[4]:getEnergy()
	}
end

-- Log any changes to the party's ep (energy point) state from the given oldState
local function logPartyEpStateChanges(oldState, changeMessage, negate, category)
	category = category or "EFFECT"
	local state = getPartyEpState()
	for i=1,4 do
		local change = math.floor(state[i] - oldState[i])
		if negate then change = -change end
		if change ~= 0 then
			local msg = changeMessage:gsub("$name", party.champions[i].name):gsub("$change", change)
			EventLog:addLogEntry(category, msg)
		end
	end
end

-- Get the party's xp state as a single value
local function getPartyXpState()
	return {
		party.champions[1].exp,
		party.champions[2].exp,
		party.champions[3].exp,
		party.champions[4].exp
	}
end

-- Log any changes to the party's xp state from the given oldState
-- This is complicted to allow multiple champion names on one xp log
local function logPartyXpStateChanges(oldState)
	local state = getPartyXpState()
	local xpAmountsLogged = {}
	local xpToLog = true
	while xpToLog do
		local collectiveGain = -1
		local championTexts = ""
		xpToLog = false
		for i = 1,4 do
			if state[i] > oldState[i] then
				if collectiveGain == -1 then
					collectiveGain = state[i] - oldState[i]
					for i = 1, #xpAmountsLogged do
						if xpAmountsLogged[i] == collectiveGain then
							collectiveGain = -1
						end
					end
					if collectiveGain ~= -1 then
						championTexts = championTexts .. party.champions[i].name
					end
				elseif (party.champions[i].exp - oldState[i]) == collectiveGain then
					championTexts = championTexts .. ", " .. party.champions[i].name
				else
					xpToLog = true
				end
			end
		end
		if collectiveGain ~= -1 then
			EventLog:addLogEntry("STATS", collectiveGain .. " XP gained by " .. championTexts .. ".", true)
			xpAmountsLogged[#xpAmountsLogged+1] = collectiveGain
		end
	end
end

-- Get a monster's hp state as a single value
local function getMonsterHpState(monster)
	return monster:getHealth()
end

-- Log any changes to a monster's hp state from the given oldState
local function logMonsterHpChanges(oldState, monster, changeMessage, negate, category, forceMessage)
	local state = getMonsterHpState(monster)
	local change = math.floor(state - oldState)
	if negate then change = -change end
	if change ~= 0 or forceMessage then
		if change == 0 then change = 0 end -- get rid of negative zero
		changeMessage = changeMessage:gsub("$name", firstToUpper(monster.go.arch.name)):gsub("$change", change)
		EventLog:addLogEntry(category, changeMessage)
	end
end

-------------------
-- EVENTS TO LOG --
-------------------
-- ITEM - Consumed
local orig_usableItemComponent_onUseItem = UsableItemComponent.onUseItem
function UsableItemComponent:onUseItem(champion, ...)
	EventLog:pushEvent("orig_usableItemComponent_onUseItem")
	local result = orig_usableItemComponent_onUseItem(self, champion, ...)

	if result then
		EventLog:addLogEntry("ITEM", champion.name .. " consumed " .. getItemDisplayName(self.go.item) .. ".")
	end

	EventLog:popEvent("orig_usableItemComponent_onUseItem")
	return result
end

-- ITEM - Add to inventory
local orig_champion_addToBackpack = Champion.addToBackpack
function Champion:addToBackpack(item, ...)
	EventLog:addLogEntry("ITEM", getItemDisplayName(item) .. " given to " .. self.name .. ".")
	return orig_champion_addToBackpack(self, item, ...)
end

local SLOT_NAMES = { "right hand", "left hand", "head", "torso", "legs", "feet", "back", "neck", "hands", "wrist" }

-- ITEM - added to or removed from item slot
local orig_charSheet_slotClicked = CharSheet.slotClicked
function CharSheet:slotClicked(owner, button, slot, ...)
	local oldState = getItemState()

	EventLog:pushEvent("orig_charSheet_slotClicked")
	local result = orig_charSheet_slotClicked(self, owner, button, slot, ...)

	if itemStateHasChanged(oldState) then
		local newState = getItemState()
		local inSlot = getItemStateDisplayName(getLossBetweenItemStates(oldState, newState))
		local inHand = getItemStateDisplayName(getLossBetweenItemStates(newState, oldState))
		local championName = owner.name
		if not owner.stats then
			-- User put item into a container.  Grab real champion name
			championName = self.champion.name
			-- Avoid the named slot indices.
			slot = 99
		end
		if inSlot ~= "" then
			if slot <= 2 then
				EventLog:addLogEntry("ITEM", inSlot .. " put in " .. championName .. "'s " .. SLOT_NAMES[slot] .. ".")
			elseif slot <= #SLOT_NAMES then
				EventLog:addLogEntry("ITEM", inSlot .. " worn on " .. championName .. "'s " .. SLOT_NAMES[slot] .. ".")
			else
				EventLog:addLogEntry("ITEM", inSlot .. " given to " .. championName .. ".")
			end
		end
		if inHand ~= "" then
			if slot <= #SLOT_NAMES then
				EventLog:addLogEntry("ITEM", inHand .. " removed from " .. championName .. "'s " .. SLOT_NAMES[slot] .. ".")
			else
				EventLog:addLogEntry("ITEM", inHand .. " taken from " .. championName .. ".")
			end
		end
	end

	EventLog:popEvent("orig_charSheet_slotClicked")
	return result
end

-- ITEM - consumed to pick chest
local orig_chestComponent_onClick = ChestComponent.onClick
function ChestComponent:onClick(...)
	local oldState = getItemState()

	EventLog:pushEvent("orig_chestComponent_onClick")
	local result = orig_chestComponent_onClick(self, ...)

	if itemStateHasChanged(oldState) then
		local state = getItemState()
		local loss = getLossBetweenItemStates(oldState, state)
		EventLog:addLogEntry("ITEM", getItemStateDisplayName(loss) .. " used to unlock a chest.")
	end

	EventLog:popEvent("orig_chestComponent_onClick")
	return result
end

-- ITEM - consumed to unlock a lock
local orig_lockComponent_onclick = LockComponent.onClick
function LockComponent:onClick(...)
	local oldState = getItemState()

	EventLog:pushEvent("orig_lockComponent_onclick")
	local result = orig_lockComponent_onclick(self, ...)

	if itemStateHasChanged(oldState) then
		local state = getItemState()
		local loss = getLossBetweenItemStates(oldState, state)
		EventLog:addLogEntry("ITEM", getItemStateDisplayName(loss) .. " used to unlock a lock.")
	end

	EventLog:popEvent("orig_lockComponent_onclick")
	return result
end

-- ITEM - dropped
local orig_itemComponent_dropItemToFloor = ItemComponent.dropItemToFloor
function ItemComponent:dropItemToFloor(...)
	local oldState = getItemState()

	EventLog:pushEvent("orig_itemComponent_dropItemToFloor")
	local result = orig_itemComponent_dropItemToFloor(self, ...)

	if result then
		EventLog:addLogEntry("ITEM", getItemStateDisplayName(oldState) .. " dropped.")
	end

	EventLog:popEvent("orig_itemComponent_dropItemToFloor")
	return result
end

-- ITEM - thrown
local orig_itemComponent_dragItemToThrowZone = ItemComponent.dragItemToThrowZone
function ItemComponent:dragItemToThrowZone(...)
	local oldState = getItemState()

	EventLog:pushEvent("orig_itemComponent_dragItemToThrowZone")
	local result = orig_itemComponent_dragItemToThrowZone(self, ...)

	if result then
		EventLog:addLogEntry("ITEM", gameMode:getActiveChampion().name .. " threw " .. getItemStateDisplayName(oldState) .. ".")
	end

	EventLog:popEvent("orig_itemComponent_dragItemToThrowZone")
	return result
end

-- ITEM - thrown using item's attack
local throwAttackComponent_start = ThrowAttackComponent.start
function ThrowAttackComponent:start(champion, slot)
	EventLog:addLogEntry("ITEM", champion.name .. " threw " .. getItemDisplayName(self.go.item, true) .. ".")
	return throwAttackComponent_start(self, champion, slot)
end

-- ITEM - shot a missile
local orig_rangedAttackComponent_start = RangedAttackComponent.start
function RangedAttackComponent:start(champion, slot, ...)
	local otherSlot = slot==1 and 2 or 1
	local oldState = getItemState(champion:getItem(otherSlot), true)

	EventLog:pushEvent("orig_rangedAttackComponent_start")
	local result = orig_rangedAttackComponent_start(self, champion, slot, ...)

	if itemStateHasChanged(oldState, champion:getItem(otherSlot), true) then
		local state = getItemState(champion:getItem(otherSlot), true)
		local loss = getLossBetweenItemStates(oldState, state)
		EventLog:addLogEntry("ITEM", champion.name .. " shot " .. getItemStateDisplayName(loss) .. ".")
	end

	EventLog:popEvent("orig_rangedAttackComponent_start")
	return result
end

-- ITEM / COMBAT - shot a firearm AND gun jamming
local orig_firearmAttackComponent_start = FirearmAttackComponent.start
function FirearmAttackComponent:start(champion, slot, ...)
	local otherSlot = slot==1 and 2 or 1
	local oldState = getItemState(champion:getItem(otherSlot), true)

	EventLog:pushEvent("orig_firearmAttackComponent_start")
	local result = orig_firearmAttackComponent_start(self, champion, slot, ...)

	if champion:getItem(slot):getJammed() then
		EventLog:addLogEntry("COMBAT", champion.name .. "'s gun jammed.")
	elseif itemStateHasChanged(oldState, champion:getItem(otherSlot), true) then
		EventLog:addLogEntry("ITEM", champion.name .. " shot " .. getItemDisplayName(champion:getItem(slot)) .. ".")
	end

	EventLog:popEvent("orig_firearmAttackComponent_start")
	return result
end

-- ITEM - taken
local orig_itemComponent_onClickComponent = ItemComponent.onClickComponent
function ItemComponent:onClickComponent(...)
	local oldState = getItemState()

	EventLog:pushEvent("orig_itemComponent_onClickComponent")
	local result = orig_itemComponent_onClickComponent(self, ...)

	if itemStateHasChanged(oldState) then
		local state = getItemState()
		EventLog:addLogEntry("ITEM", getItemStateDisplayName(state) .. " taken.")
	end

	EventLog:popEvent("orig_itemComponent_onClickComponent")
	return result
end

-- ITEM - taken as a fish
local orig_smallFishControllerComponent_onClick = SmallFishControllerComponent.onClick
function SmallFishControllerComponent:onClick(...)
	local oldState = getItemState()

	EventLog:pushEvent("orig_smallFishControllerComponent_onClick")
	local result = orig_smallFishControllerComponent_onClick(self, ...)

	if itemStateHasChanged(oldState) then
		EventLog:addLogEntry("ITEM", "Silver roach taken.")
	end

	EventLog:popEvent("orig_smallFishControllerComponent_onClick")
	return result
end

-- ITEM - auto-pickup (ammo, thrown items, etc).  Each item is picked up individually, but a
-- collective log is wanted ("x picked up y (2)", not "x picked up y \n x picked up y").  So we
-- gather and combine pick up actions.
local autoPickupHappening = false
local autoPickupCounter = { {"", 0}, {"", 0}, {"", 0}, {"", 0} }
local orig_partyComponent_pickUpAmmo = PartyComponent.pickUpAmmo
function PartyComponent:pickUpAmmo(...)
	autoPickupCounter = { {"", 0}, {"", 0}, {"", 0}, {"", 0} }
	autoPickupHappening = true

	EventLog:pushEvent("orig_partyComponent_pickUpAmmo")
	local result = orig_partyComponent_pickUpAmmo(self, ...)

	autoPickupHappening = false
	-- log all auto-pickups
	for i = 1,4 do
		if autoPickupCounter[i][2] ~= 0 then
			EventLog:addLogEntry("ITEM", self.champions[i].name .. " picked up " .. getItemStateDisplayName(autoPickupCounter[i]))
		end
	end

	EventLog:popEvent("orig_partyComponent_pickUpAmmo")
	return result
end
local orig_champion_autoPickUp = Champion.autoPickUp
function Champion:autoPickUp(item, ...)
	EventLog:pushEvent("orig_champion_autoPickUp")
	local result = orig_champion_autoPickUp(self, item, ...)

	if result == true then
		autoPickupCounter[self.championIndex][1] = getItemName(item)
		autoPickupCounter[self.championIndex][2] = autoPickupCounter[self.championIndex][2] + 1
	end

	EventLog:popEvent("orig_champion_autoPickUp")
	return result
end

-- ITEM - placed in socket
local orig_socketComponent_onClick = SocketComponent.onClick
function SocketComponent:onClick(...)
	local oldState = getItemState()

	EventLog:pushEvent("orig_socketComponent_onClick")
	local result = orig_socketComponent_onClick(self, ...)

	if itemStateHasChanged(oldState) then
		EventLog:addLogEntry("ITEM", getItemStateDisplayName(oldState) .. " placed in " .. self.go.arch.name .. ".")
	end

	EventLog:popEvent("orig_socketComponent_onClick")
	return result
end

-- ITEM - placed on surface
local orig_surfaceComponent_onClick = SurfaceComponent.onClick
function SurfaceComponent:onClick(...)
	local oldState = getItemState()

	EventLog:pushEvent("orig_surfaceComponent_onClick")
	local result = orig_surfaceComponent_onClick(self, ...)

	if itemStateHasChanged(oldState) then
		EventLog:addLogEntry("ITEM", getItemStateDisplayName(oldState) .. " placed on " .. self.go.arch.name .. ".")
	end

	EventLog:popEvent("orig_surfaceComponent_onClick")
	return result
end

-- ITEM - Potion brewed
local orig_craftPotionComponent_brewPotion = CraftPotionComponent.brewPotion
function CraftPotionComponent:brewPotion(...)
	local oldState = getItemState()
	local oldGroundItems = getPartyReachableItems()

	EventLog:pushEvent("orig_craftPotionComponent_brewPotion")
	local result = orig_craftPotionComponent_brewPotion(self, ...)

	if itemStateHasChanged(oldState) then
		local state = getItemState()
		local gain = getLossBetweenItemStates(state, oldState)
		EventLog:addLogEntry("ITEM", getItemStateDisplayName(gain) .. " brewed.")
	else
		-- Look for a reachable item that wasn't there before
		local newGroundItems = getPartyReachableItems()
		if #newGroundItems > #oldGroundItems then
			for _,newV in ipairs(newGroundItems) do
				local found = false
				for _,oldV in ipairs(oldGroundItems) do
					if oldV == newV then
						found = true
						break
					end
				end
				if not found then
					EventLog:addLogEntry("ITEM", getItemDisplayName(newV) .. " brewed.")
					break
				end
			end
		end
	end

	EventLog:popEvent("orig_craftPotionComponent_brewPotion")
	return result
end

-- A monster's projectiles & thrown items aren't tied to the monster by default.  To log that info, the tie is created here.
function TileDamagerComponent:setCastByChampion(caster)
	if type(caster) == "table" and caster.name == "monster" then
		self.castByMonster = caster
	else
		self.castByChampion = caster
	end
end
local orig_monsterComponent_throwItem = MonsterComponent.throwItem
function MonsterComponent:throwItem(...)
	local result = orig_monsterComponent_throwItem(self, ...)
	result.thrownByMonster = self
	return result
end
local orig_monsterComponent_shootProjectile = MonsterComponent.shootProjectile
function MonsterComponent:shootProjectile(...)
	local result = orig_monsterComponent_shootProjectile(self, ...)
	result.projectile:setCastByChampion(self)
	return result
end

-- COMBAT - Party melee attack.  Store attack data for the log created by "MonsterComponent:damage()".
local orig_monsterComponent_onAttackedByChampion = MonsterComponent.onAttackedByChampion
function MonsterComponent:onAttackedByChampion(champion, weapon, attack, slot, dualWieldSide, ...)
	attackerName = champion.name
	dualWieldText = (dualWieldSide == 1) and " right" or (dualWieldSide == 2) and " left" or ""

	EventLog:pushEvent("orig_monsterComponent_onAttackedByChampion")
	local result = orig_monsterComponent_onAttackedByChampion(self, champion, weapon, attack, slot, dualWieldSide, ...)

	if result == "miss" then
		EventLog:addLogEntry("COMBAT", champion.name .. dualWieldText .. " attacked " .. self.go.arch.name .. "... miss.")
	end
	attackerName = nil

	EventLog:popEvent("orig_monsterComponent_onAttackedByChampion")
	return result
end

-- COMBAT - Monster melee attack.  Store attack data for the log created by "Champion:damage()".
local orig_monsterAttackComponent_attackParty = MonsterAttackComponent.attackParty
function MonsterAttackComponent:attackParty(...)
	attackerName = self.go.arch.name

	EventLog:pushEvent("orig_monsterAttackComponent_attackParty")
	local result = orig_monsterAttackComponent_attackParty(self, ...)

	attackerName = nil

	EventLog:popEvent("orig_monsterAttackComponent_attackParty")
	return result
end

-- COMBAT - AOE/spell attack (tile damager).  Store attack data for the log created by "monster/champion:damage()".
local orig_damageTime = damageTile
function damageTile(map, x, y, direction, elevation, damageFlags, damageType, power, screenEffect, hitCallback, hitContext, ...)
	if hitContext then
		if hitContext.castByChampion then
			attackerName = party.champions[hitContext.castByChampion].name
			dualWieldText = ""
		elseif hitContext.castByMonster then
			attackerName = hitContext.castByMonster.go.arch.name
			dualWieldText = ""
		end
	end

	EventLog:pushEvent("orig_damageTime")
	local result = orig_damageTime(map, x, y, direction, elevation, damageFlags, damageType, power, screenEffect, hitCallback, hitContext, ...)

	attackerName = nil

	EventLog:popEvent("orig_damageTime")
	return result
end

-- COMBAT / EFFECT - Projectile damage.  If an attack, store attack data for the log created by "monster/champion:damage()".
local orig_itemComponent_projectileHitEntity = ItemComponent.projectileHitEntity
function ItemComponent:projectileHitEntity(target, ...)
	local oldState
	if target.monster then
		oldState = getMonsterHpState(target.monster)
		if self.thrownByChampion then
			attackerName = party.champions[self.thrownByChampion].name
			dualWieldText = ""
		end
	elseif target.party then
		oldState = getPartyHpState()
		if self.thrownByMonster then
			attackerName = self.thrownByMonster.go.arch.name
			dualWieldText = ""
		end
	end

	EventLog:pushEvent("orig_itemComponent_projectileHitEntity")
	local result = orig_itemComponent_projectileHitEntity(self, target, ...)

	if result == "miss" or attackerName == nil then
		local damageText = (result == "miss") and "miss." or "$change HP."
		local category
		local message
		if attackerName == nil then
			category = "EFFECT"
			message = "$name hit by " .. getItemDisplayName(self) .. "... " .. damageText
		else
			category = "COMBAT"
			message = attackerName .. " attacked $name... " .. damageText
		end
		if target.monster then
			logMonsterHpChanges(oldState, target.monster, message, false, category, true)
		elseif target.party then
			logPartyHpStateChanges(oldState, message, false, category, true)
		end
	end
	attackerName = nil

	EventLog:popEvent("orig_itemComponent_projectileHitEntity")
	return result
end

-- COMBAT - All attacks on monsters are logged here.  Attack data comes from earlier functions.
local orig_monsterComponent_damage = MonsterComponent.damage
function MonsterComponent:damage(dmg, side, damageFlags, damageType, impactPos, heading, ...)
	local oldState = getMonsterHpState(self)
	local isImmune = (self:getResistance(damageType) == "immune")

	EventLog:pushEvent("orig_monsterComponent_damage")
	local result = orig_monsterComponent_damage(self, dmg, side, damageFlags, damageType, impactPos, heading, ...)

	if attackerName ~= nil then
		local attackText = (heading == "Backstab") and "backstabbed" or (heading == "Critical") and "criticaled" or "attacked"
		logMonsterHpChanges(oldState, self, attackerName .. dualWieldText .. " " .. attackText .. " $name" .. "... $change HP.", false, "COMBAT", isImmune)
	end

	EventLog:popEvent("orig_monsterComponent_damage")
	return result
end

-- COMBAT - All attacks on party are logged here.  Attack data comes from earlier functions.
local orig_champion_damage = Champion.damage
function Champion:damage(...)
	local oldState = getPartyHpState()

	EventLog:pushEvent("orig_champion_damage")
	local result = orig_champion_damage(self, ...)

	if attackerName ~= nil then
		logPartyHpStateChanges(oldState, attackerName .. " attacked $name... $change HP.", false, "COMBAT")
	end
	
	EventLog:popEvent("orig_champion_damage")
	return result
end

-- COMBAT / STATS - Monster death AND ensuing xp
local orig_monsterComponent_die = MonsterComponent.die
function MonsterComponent:die(...)
	isMonitoringXp = true
	local oldState = getPartyXpState()

	EventLog:pushEvent("orig_monsterComponent_die")
	local result = orig_monsterComponent_die(self, ...)

	logPartyXpStateChanges(oldState)
	isMonitoringXp = false
	EventLog:popEvent("orig_monsterComponent_die")
	EventLog:addLogEntry("COMBAT", self.go.arch.name .. " died.")

	return result
end

-- EFFECT - health gain
local orig_champion_regainHealth = Champion.regainHealth
function Champion:regainHealth(...)
	local oldState = getPartyHpState()

	EventLog:pushEvent("orig_champion_regainHealth")
	local result = orig_champion_regainHealth(self, ...)

	logPartyHpStateChanges(oldState, "$name healed... $change HP.")

	EventLog:popEvent("orig_champion_regainHealth")
	return result
end

-- EFFECT - energy gain
local orig_champion_regainEnergy = Champion.regainEnergy
function Champion:regainEnergy(...)
	local oldState = getPartyEpState()

	EventLog:pushEvent("orig_champion_regainEnergy")
	local result = orig_champion_regainEnergy(self, ...)

	logPartyEpStateChanges(oldState, "$name energized... $change EP.")

	EventLog:popEvent("orig_champion_regainEnergy")
	return result
end

-- EFFECT - condition added to champion
local orig_champion_setCondition = Champion.setCondition
function Champion:setCondition(name, value, forceLog, ...)
	-- Don't log level-up condition.  Poisoned is checked separately (to include the damage).
	-- Empty champion name & condition="death" is a side-effect of game ending.  Don't log it.
	if (name == "level_up") or
	   (name == "poison" and value == true) or
	   (self.name == "" and name == "dead") then
		return orig_champion_setCondition(self, name, value, ...)
	end
	local pre_condition = self:hasCondition(name)

	EventLog:pushEvent("orig_champion_setCondition")
	local result = orig_champion_setCondition(self, name, value, ...)

	if self:hasCondition(name) == pre_condition and not forceLog then
		-- Nothing happened, don't log unless forced
		EventLog:popEvent("orig_champion_setCondition")
		return result
	end
	local conditionText
	if name == "head_wound"            then conditionText = "wounded in the head"
	elseif name == "chest_wound"       then conditionText = "wounded in the chest"
	elseif name == "right_hand_wound"  then conditionText = "wounded in the right hand"
	elseif name == "left_hand_wound"   then conditionText = "wounded in the left hand"
	elseif name == "leg_wound"         then conditionText = "wounded in the leg"
	elseif name == "feet_wound"        then conditionText = "wounded in the foot"
	elseif name == "bear_form"         then conditionText = "a bear"
	elseif name == "protective_shield" then conditionText = "shielded"
	elseif name == "rage"              then conditionText = "enraged"
	elseif name == "haste"             then conditionText = "hasted"
	elseif name == "invisibility"      then conditionText = "invisible"
	elseif name == "blind" or name == "slow" or name == "poison" then conditionText = name .. "ed"
	else conditionText = name end
	if self:hasCondition(name) then
		if name == "dead" then
			conditionText = " died"
		elseif name == "diseased" or name == "invisibility" or name == "starving" or
		       name == "bear_form" or name == "overloaded" or name == "burdened" then
			conditionText = " became " .. conditionText
		else
			conditionText = " was " .. conditionText
		end
		EventLog:addLogEntry("EFFECT", self.name .. conditionText .. ".", true)
	else
		EventLog:addLogEntry("EFFECT", self.name .. " no longer " .. conditionText .. ".", true)
	end

	EventLog:popEvent("orig_champion_setCondition")
	return result
end

-- EFFECT - Timed conditions aren't removed through "Champion:setCondition()" (above).  This calls it for them to create the log.
local orig_champion_updateConditions = Champion.updateConditions
function Champion:updateConditions(...)
	local pre_conditions = {}
	for name,_ in pairs(self.conditions) do
		pre_conditions[#pre_conditions+1] = name
	end

	EventLog:pushEvent("orig_champion_updateConditions")
	local result = orig_champion_updateConditions(self, ...)

	for _,name in ipairs(pre_conditions) do
		local found = false
		for toCheck,_ in pairs(self.conditions) do
			if toCheck == name then
				found = true
				break
			end
		end
		if not found then
			-- don't call Champion:setCondition() for conditions that are ALREADY cleared by using it.
			if name ~= "dead" and name ~= "overloaded" and name ~= "burdened" then
				self:setCondition(name, false, true)
			end
		end
	end	
	
	EventLog:popEvent("orig_champion_updateConditions")
	return result
end

-- EFFECT - Condition added to monster
local orig_monsterComponent_setCondition = MonsterComponent.setCondition
function MonsterComponent:setCondition(condition, ...)
	local pre_hasCondition = self:hasCondition(condition)

	EventLog:pushEvent("orig_monsterComponent_setCondition")
	local result = orig_monsterComponent_setCondition(self, condition, ...)

	if not pre_hasCondition and self:hasCondition(condition) then
		if condition == "burning" then condition = "set on fire"
		elseif condition == "sleep" then condition = "put to sleep"
		elseif condition == "sleeping" then condition = "put to sleep" end
		EventLog:addLogEntry("EFFECT", self.go.arch.name .. " was " .. condition .. ".")
	end

	EventLog:popEvent("orig_monsterComponent_setCondition")
	return result
end

-- EFFECT - drowning
local orig_partyComponent_updateDiving = PartyComponent.updateDiving
function PartyComponent:updateDiving(...)
	local oldState = getPartyHpState()

	EventLog:pushEvent("orig_partyComponent_updateDiving")
	local result = orig_partyComponent_updateDiving(self, ...)

	logPartyHpStateChanges(oldState, "$name is drowning... $change HP.")

	EventLog:popEvent("orig_partyComponent_updateDiving")
	return result
end

-- EFFECT - Falling
local orig_partyComponent_onFallingImpact = PartyComponent.onFallingImpact
function PartyComponent:onFallingImpact(...)
	local oldState = getPartyHpState()

	EventLog:pushEvent("orig_partyComponent_onFallingImpact")
	result = orig_partyComponent_onFallingImpact(self, ...)

	logPartyHpStateChanges(oldState, "$name fell... $change HP.")

	EventLog:popEvent("orig_partyComponent_onFallingImpact")
	return result
end

-- EFFECT - Poison
local orig_poisonCondition_tick = PoisonCondition.tick
function PoisonCondition:tick(...)
	local oldState = getPartyHpState()

	EventLog:pushEvent("orig_poisonCondition_tick")
	local result = orig_poisonCondition_tick(self, ...)

	logPartyHpStateChanges(oldState, "$name is poisoned... $change HP.")

	EventLog:popEvent("orig_poisonCondition_tick")
	return result
end

-- ACTION - Button
local orig_buttonComponent_onClick = ButtonComponent.onClick
function ButtonComponent:onClick(...)
	EventLog:addLogEntry("ACTION", "Button clicked.")
	return orig_buttonComponent_onClick(self, ...)
end

-- ACTION - Floor trigger
local orig_floorTriggerComponent_activate = FloorTriggerComponent.activate
function FloorTriggerComponent:activate(...)
	if self.pressurePlate then
		EventLog:addLogEntry("ACTION", "Pressure plate triggered.")
	end
	return orig_floorTriggerComponent_activate(self, ...)
end
local orig_floorTriggerComponent_deactivate = FloorTriggerComponent.deactivate
function FloorTriggerComponent:deactivate(...)
	if self.pressurePlate then
		EventLog:addLogEntry("ACTION", "Pressure plate untriggered.")
	end
	return orig_floorTriggerComponent_deactivate(self, ...)
end

-- ACTION - Lever
local orig_leverComponent_toggle = LeverComponent.toggle
function LeverComponent:toggle(...)
	if self.activated then
		EventLog:addLogEntry("ACTION", "Lever deactivated.")
	else
		EventLog:addLogEntry("ACTION", "Lever activated.")
	end
	return orig_leverComponent_toggle(self, ...)
end

-- ACTION - Rest and rest-based actions begun
local orig_partyComponent_rest = PartyComponent.rest
function PartyComponent:rest(text, ...)
	preRestHp = getPartyHpState()
	preRestEp = getPartyEpState()

	EventLog:pushEvent("orig_partyComponent_rest")
	local result = orig_partyComponent_rest(self, text, ...)

	if party.resting then
		currentRestIsForAction = (text ~= nil)
		if not currentRestIsForAction then
			EventLog:addLogEntry("ACTION", "Resting.", true)
		else
			-- The non-resting messages use "...".  Remove that and use "." instead.
			EventLog:addLogEntry("ACTION", text:gsub("%.%.%.", "") .. ".", true)
		end
	end

	EventLog:popEvent("orig_partyComponent_rest")
	return result
end

-- ACTION - Rest ended
local orig_partyComponent_wakeUp = PartyComponent.wakeUp
function PartyComponent:wakeUp(restInterrupted, ...)
	if party.resting and not currentRestIsForAction then
		if restInterrupted then
			EventLog:addLogEntry("ACTION", "Rest interrupted.", true)
		else
			EventLog:addLogEntry("ACTION", "Rest ended.", true)
		end

		local result = orig_partyComponent_wakeUp(self, restInterrupted, ...)

		logPartyHpStateChanges(preRestHp, "$name healed... $change HP.")
		logPartyEpStateChanges(preRestEp, "$name energized... $change EP.")

		return result
	else
		orig_partyComponent_wakeUp(self, restInterrupted)
	end
end

-- ACTION - Shovel use interrupted
local orig_diggingToolComponent_onPartyWakeUp = DiggingToolComponent.onPartyWakeUp
function DiggingToolComponent:onPartyWakeUp(...)
	if not self.diggingCounter or self.diggingCounter < 7 then
		EventLog:addLogEntry("ACTION", "Dig interrupted.", true)
	end
	orig_diggingToolComponent_onPartyWakeUp(self, ...)
end

-- ACTION - Rope use interrupted
local orig_ropeToolComponent_onPartyWakeUp = RopeToolComponent.onPartyWakeUp
function RopeToolComponent:onPartyWakeUp(...)
	if not self.counter or self.counter < 7 then
		EventLog:addLogEntry("ACTION", "Climb interrupted.", true)
	end
	orig_ropeToolComponent_onPartyWakeUp(self, ...)
end

-- ACTION - Used healing crystal
local orig_crystalComponent_onClick = CrystalComponent.onClick
function CrystalComponent:onClick(...)
	EventLog:addLogEntry("ACTION", "Healing crystal used.", true)
	orig_crystalComponent_onClick(self, ...)
end

-- ACTION - Find secret
local orig_secretComponent_activate = SecretComponent.activate
function SecretComponent:activate(...)
	EventLog:addLogEntry("ACTION", "Secret found.", true)
	return orig_secretComponent_activate(self, ...)
end

-- STATS - levelup
local orig_champion_levelUp = Champion.levelUp
function Champion:levelUp(...)
	isNormalSkillPointChange = true
	EventLog:addLogEntry("STATS", self.name .. " leveled to " .. (self.level+1) .. ".")

	local result = orig_champion_levelUp(self, ...)

	isNormalSkillPointChange = false

	return result
end

-- STATS - add skill point
local orig_champion_addSkillPoints = Champion.addSkillPoints
function Champion:addSkillPoints(amount, ...)
	if not isNormalSkillPointChange then -- Don't log levelups and slotting skill points
		local plural_s = amount == 1 and "" or "s"
		EventLog:addLogEntry("STATS", self.name .. " gained " .. amount .. " skill point" .. plural_s .. ".")
	end
	return orig_champion_addSkillPoints(self, amount, ...)
end

-- Simply block skill point logs while slotting and unslotting skills
local orig_charSheet_skillsTab = CharSheet.skillsTab
function CharSheet:skillsTab(...)
	isNormalSkillPointChange = true
	local result = orig_charSheet_skillsTab(self, ...)
	isNormalSkillPointChange = false
	return result
end

-- STATS - Experience from digging up chest
local orig_diggingToolComponent_diggingFinished = DiggingToolComponent.diggingFinished
function DiggingToolComponent:diggingFinished(...)
	isMonitoringXp = true
	local oldState = getPartyXpState()

	EventLog:pushEvent("orig_diggingToolComponent_diggingFinished")
	local result = orig_diggingToolComponent_diggingFinished(self, ...)

	logPartyXpStateChanges(oldState)
	isMonitoringXp = false

	EventLog:popEvent("orig_diggingToolComponent_diggingFinished")
	return result
end

-- STATS - Experience from anything not otherwise handled
local orig_champion_gainExp = Champion.gainExp
function Champion:gainExp(...)
	if isMonitoringXp then
		return orig_champion_gainExp(self, ...)
	end
	local oldState = getPartyXpState()

	EventLog:pushEvent("orig_champion_gainExp")
	local result = orig_champion_gainExp(self, ...)

	logPartyXpStateChanges(oldState)

	EventLog:popEvent("orig_champion_gainExp")
	return result
end

-- STATS - skill increase
local orig_champion_trainSkill = Champion.trainSkill
function Champion:trainSkill(name, times, ...)
	isNormalSkillPointChange = true
	EventLog:addLogEntry("STATS", self.name .. " gained " .. (times or 1) .. " in " .. name:gsub("_", " ") .. " skill.")

	local result = orig_champion_trainSkill(self, name, times, ...)

	isNormalSkillPointChange = false

	return result
end

-- STATS - gain trait
local orig_champion_addTrait = Champion.addTrait
function Champion:addTrait(name, ...)
	local pre_hasTrait = self:hasTrait(name)

	EventLog:pushEvent("orig_champion_addTrait")
	local result = orig_champion_addTrait(self, name, ...)

	if not pre_hasTrait and self:hasTrait(name) then
		local trait = Skill.getTrait(name)
		if name == "nightstalker" then
			EventLog:addLogEntry("STATS", self.name .. " was somehow changed.")
		elseif not trait.hidden then
			EventLog:addLogEntry("STATS", self.name .. " learned " .. Skill.getTrait(name).uiName .. " trait.")
		end
	end

	EventLog:popEvent("orig_champion_addTrait")
	return result
end

-- STATS - general stat increases
local orig_champion_modifyBaseStat = Champion.modifyBaseStat
function Champion:modifyBaseStat(name, value, ...)
	for _,v in ipairs(STATS_CHANGES_TO_LOG) do
		if name == v then
			EventLog:addLogEntry("STATS", self.name .. "'s " .. getStatName(name) .. " changed.  " .. (self.stats[name].current) .. " to " .. (self.stats[name].current + value) .. ".")
		end
	end
	return orig_champion_modifyBaseStat(self, name, value, ...)
end
