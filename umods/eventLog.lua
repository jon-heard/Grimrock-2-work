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
	"GuiItem", "Gui:draw", "GameMode:newGame", "GameMode:loadGame", "Champion:setEnabled",
	"DungeonEditor:playPreview", "GameMode:keyPressed", "UsableItemComponent:onUseItem", "Champion:addToBackpack", "CharSheet:slotClicked",
	"ChestComponent:onClick", "ItemComponent:dropItemToFloor", "ItemComponent:dragItemToThrowZone", "ThrowAttackComponent:start", "ItemComponent:onClickComponent",
	"LockComponent:onClick", "SmallFishControllerComponent:onClick", "SocketComponent:onClick", "SurfaceComponent:onClick", "CraftPotionComponent:brewPotion",
	"MonsterComponent:throwItem", "MonsterComponent:shootProjectile", "MonsterComponent:onAttackedByChampion", "MonsterAttackComponent:attackParty", "damageTile",
	"ItemComponent:projectileHitEntity", "MonsterComponent:damage", "Champion:damage", "FirearmAttackComponent:start", "MonsterComponent:die",
	"Champion:regainHealth", "Champion:regainEnergy", "Champion:setCondition", "Champion:updateConditions", "MonsterComponent:setCondition",
	"PartyComponent:updateDiving", "PartyComponent:onFallingImpact", "PoisonCondition:tick", "ButtonComponent:onClick", "FloorTriggerComponent:activate",
	"FloorTriggerComponent:deactivate", "LeverComponent:toggle", "PartyComponent:rest", "PartyComponent:wakeUp", "CrystalComponent:onClick",
	"SecretComponent:activate", "Champion:levelUp", "DiggingToolComponent:diggingFinished", "Champion:gainExp", "Champion:trainSkill",
	"Champion:addTrait", "Champion:upgradeBaseStat"
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
local TITLE_OFFSET_Y = 19
local BUTTON_CLEAR_OFFSET_X = 400
local BUTTON_CLEAR_OFFSET_Y = 557
local BUTTON_COPY_OFFSET_X = 329
local BUTTON_COPY_OFFSET_Y = 559
local FILTER_OFFSET_X = 83
local FILTER_OFFSET_Y = 563
local FILTER_WIDTH = 280
local SCROLL_OFFSET_X = 46
local SCROLL_OFFSET_Y = 103
local SCROLL_WIDTH = 447
local SCROLL_HEIGHT = 446
local SCROLL_TEXT_OFFSET_X = 2
local SCROLL_TEXT_OFFSET_Y = 19
local CATEGORY_WIDTH = 86
local BASE_FILTERS = { "EFFECT", "ACTION", "ITEM", "STATS", "ALL", "COMBAT" }
local INDEX_OF_ALL_FILTER = 5
local RECIPROCAL_TYPES = { { "taken from", "given to" }, { "held in", "removed from" }, { "worn on", "removed from" } }

-- Gui images
local imagePath = "assets/textures/gui/gui_items.tga"
GuiItem["logMinBack1"]   = { x = 551;  y = 2308;      width = 575; height = 112;  image = imagePath }
GuiItem["logMinBack2"]   = { x = 708;  y = 2501;      width = 250; height = 21;   image = imagePath }
GuiItem["logMaxBack"]    = { x = 0;    y = 775;       width = 550; height = 652;  image = imagePath }
GuiItem["logOpen"]       = { x = 2162; y = 2220+42*0; width = 42;  height = 42;   image = imagePath }
GuiItem["logClose"]      = { x = 2162; y = 2220+42*1; width = 42;  height = 42;   image = imagePath }
GuiItem["logOpenHover"]  = { x = 2162; y = 2220+42*2; width = 42;  height = 42;   image = imagePath }
GuiItem["logCloseHover"] = { x = 2162; y = 2220+42*3; width = 42;  height = 42;   image = imagePath }

-- "Internal" fields
local scrollInnerHeight = 8
local scrollPosition = 0
local scrollSmooth = 0
local filteredItems = {}
-- The game crashes if rendering too many logs.  300 appears safe (never crashed under ~340).
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

-- I'm surprised these Gui functions aren't already part of the Gui system.  They are
-- copy/paste/modify jobs of existing Gui functions.  I wouldn't have added spurious methods to the
-- Gui system, but it seemed like the best way to access member fields self.guiScale, etc.

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

	local font = FontType.PalatinoSmall
	local color = Color.White
	if style == "disabled" then color = {100,100,100,255} end
	gui:drawTextCentered(choices[value], x + width/2 - leftSideOffset, y + 15, font, color)

	return value
end


-----------
-- Class --
-----------
EventLog.items = {}
EventLog.isUiMaximized = false
EventLog.currentFilterIndex = INDEX_OF_ALL_FILTER
EventLog.filters = {}

-- Adds a new item to the event log
function EventLog:addLogItem(category, text, forceWhileResting)
	-- Don't accept items unless the real filters are setup
	if #self.filters == 0 then return end

	-- Block most items while resting
	if party.resting and not forceWhileResting then return end

	local newItem = { category, text }

	-- Check for items that undo the prior item ("taken from" & "given to" for example)
	if self:handleReciprocalItems(newItem) then
		return
	end

	-- Add the new log item
	self.items[#self.items + 1] = newItem
	if self:itemMatchesFilter(newItem, self.filters[self.currentFilterIndex]) then
		filteredItems[#filteredItems+1] = newItem
	end

	-- Limit log item count to avoid memory bloat
	while #self.items > self.maxHistory do
		if areArraysEquivalent(filteredItems[1], self.items[1]) then
			table.remove(filteredItems, 1)
		end
		table.remove(self.items, 1)
	end

	self:calculateScrollUi()
end

function EventLog:removeLogItem()
	if areArraysEquivalent(filteredItems[#filteredItems], self.items[#self.items]) then
		table.remove(filteredItems)
	end
	local result = table.remove(self.items)
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

	-- Clear items - change of party means change of game.  Don't keep items from old game
	self.items = {}
	filteredItems = {}
end

function EventLog:itemMatchesFilter(item, filter)
	if filter == "ALL" then
		return true
	elseif filter:sub(1,8) == "COMBAT: " then
		-- Champion-specific combat filters - must be combat category and start with champion name
		return (
			item[1] == "COMBAT" and
			item[2]:sub(1, filter:len()-8) == filter:sub(9))
	else
		return (item[1] == filter)
	end
end

function EventLog:handleReciprocalItems(newItem)
	local latestItem = self.items[#self.items]
	if latestItem == nil then return false end -- If there aren't any items yet, do nothing

	-- Reciprocal items have the same category and different messages
	if newItem[1] ~= latestItem[1] or newItem[2] == latestItem[2] then return false end

	-- check each reciprocal type
	for _,v in ipairs(RECIPROCAL_TYPES) do
		if latestItem[2] == newItem[2]:gsub(v[1], v[2]) or
		   latestItem[2] == newItem[2]:gsub(v[2], v[1]) then
			self:removeLogItem()
			return true
		end
	end

	return false
end

function EventLog:calculateScrollUi(forceSnapToBottom)
	-- Determine scroll height based on count of filtered items
	scrollInnerHeight = #filteredItems * FULL_TEXT_HEIGHT + 8

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
	if #filteredItems > 0 then
		gui:drawText(filteredItems[#filteredItems][1] .. ":  " .. filteredItems[#filteredItems][2], MIN_WIN_LEFT + PADDING * 2 + MIN_TEXT_OFFSET_X, MIN_WIN_BOTTOM - PADDING * 2 + MIN_TEXT_OFFSET_Y)
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
	gui:drawTextCentered("Event log", leftOffset + TITLE_OFFSET_X, topOffset + TITLE_OFFSET_Y, FontType.MenuSmall)

	-- Button - clear
	if gui:button("clear", GuiItem.ButtonClear, leftOffset + BUTTON_CLEAR_OFFSET_X, topOffset + BUTTON_CLEAR_OFFSET_Y, GuiItem.ButtonClearHover, "Clear the log.") then
		self.items = {}
		filteredItems = {}
		self:calculateScrollUi()
	end

	-- Button - copy
	if gui:button("copy", GuiItem.MapButtonHover, leftOffset + BUTTON_COPY_OFFSET_X, topOffset + BUTTON_COPY_OFFSET_Y, GuiItem.MapButtonHover, "Copy the log to the clipboard.") then
		local logText = ""
		for i = 1, #filteredItems do
			logText = logText .. filteredItems[i][1] .. ":  " .. filteredItems[i][2] .. "\n"
		end
		sys.setClipboard(logText)
		gui:hudPrint("Log copied to the clipboard")
	end

	-- Combo - filter
	local newFilterIndex = gui:comboBox_customWidth("logFilter", leftOffset + FILTER_OFFSET_X, topOffset + FILTER_OFFSET_Y, FILTER_WIDTH, self.currentFilterIndex, self.filters, nil, "Filter the log by event type.")
	if newFilterIndex ~= self.currentFilterIndex then
		self.currentFilterIndex = newFilterIndex
		filteredItems = {}
		for i = 1, #self.items do
			if self:itemMatchesFilter(self.items[i], self.filters[self.currentFilterIndex]) then
				filteredItems[#filteredItems+1] = self.items[i]
			end
		end
		self:calculateScrollUi(true)
	end

	-- Start a scroll area for the log items
	scrollPosition = gui:beginScrollArea("logScroll", leftOffset + SCROLL_OFFSET_X, topOffset + SCROLL_OFFSET_Y, SCROLL_WIDTH, SCROLL_HEIGHT, scrollPosition, scrollInnerHeight, FULL_TEXT_HEIGHT)
	scrollPosition, scrollSmooth = gui:smoothScroll(scrollPosition, scrollSmooth)

	-- Draw the log items
	local listOffset = 0
	for i= 1, #filteredItems do
		gui:drawText(filteredItems[i][1], leftOffset + SCROLL_OFFSET_X + SCROLL_TEXT_OFFSET_X, topOffset - scrollSmooth + listOffset + SCROLL_OFFSET_Y + SCROLL_TEXT_OFFSET_Y)
		gui:drawText(filteredItems[i][2], leftOffset + SCROLL_OFFSET_X + SCROLL_TEXT_OFFSET_X + CATEGORY_WIDTH, topOffset - scrollSmooth + listOffset + SCROLL_OFFSET_Y + SCROLL_TEXT_OFFSET_Y)
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
function Gui:draw()
	EventLog:drawUi(true) -- Draw EventLog before the rest so that tooltips show over it
	return orig_gui_draw(self)
end
local orig_pauseMenu_update = PauseMenu.update
function PauseMenu:update()
	local result = orig_pauseMenu_update(self)
	EventLog:drawUi() -- Draw EventLog after the rest so that it's on top of the dimmer
	return result
end
local orig_mainMenu_update = MainMenu.update
function MainMenu:update()
	if #EventLog.filters > 0 then
		EventLog:drawUi()
	end
	return orig_mainMenu_update(self)
end

-- These overrides are all to populate the filters based on champion names
local orig_gameMode_newGame = GameMode.newGame
function GameMode:newGame()
	EventLog.filters = {} -- Disable filters while setting up the characters
	local result = orig_gameMode_newGame(self)
	EventLog:init()
	return result
end
local orig_gameMode_loadGame = GameMode.loadGame
function GameMode:loadGame(filename)
	EventLog.filters = {} -- Disable filters while setting up the characters
	local result = orig_gameMode_loadGame(self, filename)
	EventLog:init()
	return result
end
local orig_champion_setEnabled = Champion.setEnabled
function Champion:setEnabled(enabled)
	EventLog.filters = {} -- Disable filters while setting up the characters
	local result = orig_champion_setEnabled(self, enabled)
	EventLog:init()
	return result
end
local orig_dungeonEditor_playPreview = DungeonEditor.playPreview
function DungeonEditor:playPreview()
	EventLog.filters = {} -- Disable filters while setting up the characters
	local result = orig_dungeonEditor_playPreview(self)
	-- Party can be nil if run-game button is hit without a dungeon loaded
	if party ~= nil then
		EventLog:init()
	end
	return result
end

-- "Escape" will unmaximize the event log
-- "O" key will toggle maximizing the event log
local orig_gameMode_keyPressed = GameMode.keyPressed
function GameMode:keyPressed(event)
	if event.key == "escape" and EventLog.isUiMaximized then
		EventLog.isUiMaximized = false
		return
	end
	if event.key == "O" then
		EventLog.isUiMaximized = not EventLog.isUiMaximized
	end
	return orig_gameMode_keyPressed(self, event)
end


---------------------------------
-- EVENTS TO LOG - HELPER FNCS --
---------------------------------
-- Set to true during special xp monitors (killing mobs & digging chests) so that the generic xp+
-- logs don't trigger
local isMonitoringXp = false
-- Since attack logs need info from multiple functions, these vars are set from those functions.
local attackerName = nil
local dualWieldText = ""

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
		if change > 0 then
			EventLog:addLogItem(category, changeMessage:gsub("$name", party.champions[i].name):gsub("$change", change))
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
		if change > 0 then
			EventLog:addLogItem(category, changeMessage:gsub("$name", party.champions[i].name):gsub("$change", change))
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
			EventLog:addLogItem("STATS", collectiveGain .. " XP gained by " .. championTexts .. ".", true)
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
		EventLog:addLogItem(category, changeMessage:gsub("$name", firstToUpper(monster.go.arch.name)):gsub("$change", change))
	end
end

-------------------
-- EVENTS TO LOG --
-------------------
-- ITEM - Consumed
local orig_usableItemComponent_onUseItem = UsableItemComponent.onUseItem
function UsableItemComponent:onUseItem(champion)
	local result = orig_usableItemComponent_onUseItem(self, champion)

	if result then
		EventLog:addLogItem("ITEM", champion.name .. " consumed " .. getItemDisplayName(self.go.item) .. ".")
	end

	return result
end

-- ITEM - Add to inventory
local orig_champion_addToBackpack = Champion.addToBackpack
function Champion:addToBackpack(item, autoEquip)
	EventLog:addLogItem("ITEM", getItemDisplayName(item) .. " given to " .. self.name .. ".")
	return orig_champion_addToBackpack(self, item, autoEquip)
end

local SLOT_NAMES = { "right hand", "left hand", "head", "torso", "legs", "feet", "back", "neck", "hands", "wrist" }

-- ITEM - added to or removed from item slot
local orig_charSheet_slotClicked = CharSheet.slotClicked
function CharSheet:slotClicked(owner, button, slot)
	local oldState = getItemState()

	local result = orig_charSheet_slotClicked(self, owner, button, slot)

	if itemStateHasChanged(oldState) then
		local newState = getItemState()
		local inSlot = getItemStateDisplayName(getLossBetweenItemStates(oldState, newState))
		local inHand = getItemStateDisplayName(getLossBetweenItemStates(newState, oldState))
		local championName = owner.stats and owner.name or self.champion.name -- Complicated by containers
		if inSlot ~= "" then
			if slot <= 2 then
				EventLog:addLogItem("ITEM", inSlot .. " held in " .. championName .. "'s " .. SLOT_NAMES[slot] .. ".")
			elseif slot <= #SLOT_NAMES then
				EventLog:addLogItem("ITEM", inSlot .. " worn on " .. championName .. "'s " .. SLOT_NAMES[slot] .. ".")
			else
				EventLog:addLogItem("ITEM", inSlot .. " given to " .. championName .. ".")
			end
		end
		if inHand ~= "" then
			if slot <= #SLOT_NAMES then
				EventLog:addLogItem("ITEM", inHand .. " removed from " .. championName .. "'s " .. SLOT_NAMES[slot] .. ".")
			else
				EventLog:addLogItem("ITEM", inHand .. " taken from " .. championName .. ".")
			end
		end
	end

	return result
end

-- ITEM - consumed to pick chest
local orig_chestComponent_onClick = ChestComponent.onClick
function ChestComponent:onClick()
	local oldState = getItemState()

	local result = orig_chestComponent_onClick(self)

	if itemStateHasChanged(oldState) then
		local state = getItemState()
		local loss = getLossBetweenItemStates(oldState, state)
		EventLog:addLogItem("ITEM", getItemStateDisplayName(loss) .. " used to unlock a chest.")
	end

	return result
end

-- ITEM - consumed to unlock a lock
local orig_lockComponent_onclick = LockComponent.onClick
function LockComponent:onClick()
	local oldState = getItemState()

	local result = orig_lockComponent_onclick(self)

	if itemStateHasChanged(oldState) then
		local state = getItemState()
		local loss = getLossBetweenItemStates(oldState, state)
		EventLog:addLogItem("ITEM", getItemStateDisplayName(loss) .. " used to unlock a lock.")
	end

	return result
end

-- ITEM - dropped
local orig_itemComponent_dropItemToFloor = ItemComponent.dropItemToFloor
function ItemComponent:dropItemToFloor(x, y)
	local oldState = getItemState()

	local result = orig_itemComponent_dropItemToFloor(self, x, y)

	if result then
		EventLog:addLogItem("ITEM", getItemStateDisplayName(oldState) .. " dropped.")
	end

	return result
end

-- ITEM - thrown
local orig_itemComponent_dragItemToThrowZone = ItemComponent.dragItemToThrowZone
function ItemComponent:dragItemToThrowZone(x, y)
	local oldState = getItemState()

	local result = orig_itemComponent_dragItemToThrowZone(self, x, y)

	if result then
		EventLog:addLogItem("ITEM", gameMode:getActiveChampion().name .. " threw " .. getItemStateDisplayName(oldState) .. ".")
	end

	return result
end

-- ITEM - thrown using item's attack
local throwAttackComponent_start = ThrowAttackComponent.start
function ThrowAttackComponent:start(champion, slot)
	EventLog:addLogItem("ITEM", champion.name .. " threw " .. getItemDisplayName(self.go.item, true) .. ".")
	return throwAttackComponent_start(self, champion, slot)
end

-- ITEM - shot a missile
local orig_rangedAttackComponent_start = RangedAttackComponent.start
function RangedAttackComponent:start(champion, slot)
	local otherSlot = slot==1 and 2 or 1
	local oldState = getItemState(champion:getItem(otherSlot), true)

	local result = orig_rangedAttackComponent_start(self, champion, slot)

	if itemStateHasChanged(oldState, champion:getItem(otherSlot), true) then
		local state = getItemState(champion:getItem(otherSlot), true)
		local loss = getLossBetweenItemStates(oldState, state)
		EventLog:addLogItem("ITEM", champion.name .. " shot " .. getItemStateDisplayName(loss) .. ".")
	end

	return result
end

-- ITEM / COMBAT - shot a firearm AND gun jamming
local orig_firearmAttackComponent_start = FirearmAttackComponent.start
function FirearmAttackComponent:start(champion, slot)
	local otherSlot = slot==1 and 2 or 1
	local oldState = getItemState(champion:getItem(otherSlot), true)

	local result = orig_firearmAttackComponent_start(self, champion, slot)

	if champion:getItem(slot):getJammed() then
		EventLog:addLogItem("COMBAT", champion.name .. "'s gun jammed.")
	elseif itemStateHasChanged(oldState, champion:getItem(otherSlot), true) then
		-- Firearm is fast enough that the attack log comes before the fired log.
		-- We thus remove the attack log and re-add it AFTER the fired log
		local attackLog = nil
		if string.startsWith(EventLog.items[#EventLog.items][2], champion.name .. " attacked ") then
			attackLog = EventLog:removeLogItem()
		end
		EventLog:addLogItem("ITEM", champion.name .. " shot " .. getItemDisplayName(champion:getItem(slot)) .. ".")
		if attackLog then
			EventLog:addLogItem(attackLog[1], attackLog[2])
		end
	end

	return result
end

-- ITEM - taken
local orig_itemComponent_onClickComponent = ItemComponent.onClickComponent
function ItemComponent:onClickComponent()
	local oldState = getItemState()

	local result = orig_itemComponent_onClickComponent(self)

	if itemStateHasChanged(oldState) then
		local state = getItemState()
		EventLog:addLogItem("ITEM", getItemStateDisplayName(state) .. " taken from the world.")
	end

	return result
end

-- ITEM - taken as a fish
local orig_smallFishControllerComponent_onClick = SmallFishControllerComponent.onClick
function SmallFishControllerComponent:onClick()
	local oldState = getItemState()

	local result = orig_smallFishControllerComponent_onClick(self)

	if itemStateHasChanged(oldState) then
		EventLog:addLogItem("ITEM", "Silver roach taken from the world.")
	end

	return result
end

-- ITEM - auto-pickup (ammo, thrown items, etc).  Each item is picked up individually, but a
-- collective log is wanted ("x picked up y (2)", not "x picked up y \n x picked up y").  So we
-- gather and combine pick up actions.
local autoPickupHappening = false
local autoPickupCounter = { {"", 0}, {"", 0}, {"", 0}, {"", 0} }
local orig_partyComponent_pickUpAmmo = PartyComponent.pickUpAmmo
function PartyComponent:pickUpAmmo()
	autoPickupCounter = { {"", 0}, {"", 0}, {"", 0}, {"", 0} }
	autoPickupHappening = true

	local result = orig_partyComponent_pickUpAmmo(self)

	autoPickupHappening = false
	-- log all auto-pickups
	for i = 1,4 do
		if autoPickupCounter[i][2] ~= 0 then
			EventLog:addLogItem("ITEM", self.champions[i].name .. " picked up " .. getItemStateDisplayName(autoPickupCounter[i]))
		end
	end

	return result
end
local orig_champion_autoPickUp = Champion.autoPickUp
function Champion:autoPickUp(item)
	local result = orig_champion_autoPickUp(self, item)

	if result == true then
		autoPickupCounter[self.championIndex][1] = getItemName(item)
		autoPickupCounter[self.championIndex][2] = autoPickupCounter[self.championIndex][2] + 1
	end

	return result
end

-- ITEM - placed in socket
local orig_socketComponent_onClick = SocketComponent.onClick
function SocketComponent:onClick()
	local oldState = getItemState()

	local result = orig_socketComponent_onClick(self)

	if itemStateHasChanged(oldState) then
		EventLog:addLogItem("ITEM", getItemStateDisplayName(oldState) .. " placed in " .. self.go.arch.name .. ".")
	end

	return result
end

-- ITEM - placed on surface
local orig_surfaceComponent_onClick = SurfaceComponent.onClick
function SurfaceComponent:onClick(button, x, y)
	local oldState = getItemState()

	local result = orig_surfaceComponent_onClick(self, button, x, y)

	if itemStateHasChanged(oldState) then
		EventLog:addLogItem("ITEM", getItemStateDisplayName(oldState) .. " placed on " .. self.go.arch.name .. ".")
	end

	return result
end

-- ITEM - Potion brewed
local orig_craftPotionComponent_brewPotion = CraftPotionComponent.brewPotion
function CraftPotionComponent:brewPotion(champion)
	local oldState = getItemState()
	local oldGroundItems = getPartyReachableItems()

	local result = orig_craftPotionComponent_brewPotion(self, champion)

	if itemStateHasChanged(oldState) then
		local state = getItemState()
		local gain = getLossBetweenItemStates(state, oldState)
		EventLog:addLogItem("ITEM", getItemStateDisplayName(gain) .. " brewed.")
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
					EventLog:addLogItem("ITEM", getItemDisplayName(newV) .. " brewed.")
					break
				end
			end
		end
	end

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
function MonsterComponent:throwItem(item, height, attackPower, originNode)
	local result = orig_monsterComponent_throwItem(self, item, height, attackPower, originNode)
	result.thrownByMonster = self
	return result
end
local orig_monsterComponent_shootProjectile = MonsterComponent.shootProjectile
function MonsterComponent:shootProjectile(projectile, height, attackPower, originNode)
	local result = orig_monsterComponent_shootProjectile(self, projectile, height, attackPower, originNode)
	result.projectile:setCastByChampion(self)
	return result
end

-- COMBAT - Party melee attack.  Store attack data for the log created by "MonsterComponent:damage()".
local orig_monsterComponent_onAttackedByChampion = MonsterComponent.onAttackedByChampion
function MonsterComponent:onAttackedByChampion(champion, weapon, attack, slot, dualWieldSide)
	attackerName = champion.name
	dualWieldText = (dualWieldSide == 1) and " left" or (dualWieldSide == 2) and " right" or ""

	local result = orig_monsterComponent_onAttackedByChampion(self, champion, weapon, attack, slot, dualWieldSide)

	if result == "miss" then
		EventLog:addLogItem("COMBAT", champion.name .. dualWieldText .. " attacked " .. self.go.arch.name .. "... miss.")
	end
	attackerName = nil

	return result
end

-- COMBAT - Monster melee attack.  Store attack data for the log created by "Champion:damage()".
local orig_monsterAttackComponent_attackParty = MonsterAttackComponent.attackParty
function MonsterAttackComponent:attackParty()
	attackerName = self.go.arch.name

	local result = orig_monsterAttackComponent_attackParty(self)

	attackerName = nil

	return result
end

-- COMBAT - AOE/spell attack (tile damager).  Store attack data for the log created by "monster/champion:damage()".
local orig_damageTime = damageTile
function damageTile(map, x, y, direction, elevation, damageFlags, damageType, power, screenEffect, hitCallback, hitContext)
	if hitContext then
		if hitContext.castByChampion then
			attackerName = party.champions[hitContext.castByChampion].name
			dualWieldText = ""
		elseif hitContext.castByMonster then
			attackerName = hitContext.castByMonster.go.arch.name
			dualWieldText = ""
		end
	end

	local result = orig_damageTime(map, x, y, direction, elevation, damageFlags, damageType, power, screenEffect, hitCallback, hitContext)

	attackerName = nil

	return result
end

-- COMBAT / EFFECT - Projectile damage.  If an attack, store attack data for the log created by "monster/champion:damage()".
local orig_itemComponent_projectileHitEntity = ItemComponent.projectileHitEntity
function ItemComponent:projectileHitEntity(target)
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

	local result = orig_itemComponent_projectileHitEntity(self, target)

	if result == "miss" or attackerName == nil then
		local damageText = (result == "miss") and "miss." or "$change damage."
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
			logMonsterHpChanges(oldState, target.monster, message, true, category, true)
		elseif target.party then
			logPartyHpStateChanges(oldState, message, true, category, true)
		end
	end

	attackerName = nil
	return result
end

-- COMBAT - All attacks on monsters are logged here.  Attack data comes from earlier functions.
local orig_monsterComponent_damage = MonsterComponent.damage
function MonsterComponent:damage(dmg, side, damageFlags, damageType, impactPos, heading)
	local oldState = getMonsterHpState(self)
	local isImmune = (self:getResistance(damageType) == "immune")

	local result = orig_monsterComponent_damage(self, dmg, side, damageFlags, damageType, impactPos, heading)

	if attackerName ~= nil then
		local attackText = (heading == "Backstab") and "backstabbed" or (heading == "Critical") and "criticaled" or "attacked"
		logMonsterHpChanges(oldState, self, attackerName .. dualWieldText .. " " .. attackText .. " $name" .. "... $change damage.", true, "COMBAT", isImmune)
	end

	return result
end

-- COMBAT - All attacks on party are logged here.  Attack data comes from earlier functions.
local orig_champion_damage = Champion.damage
function Champion:damage(dmg, damageType)
	local oldState = getPartyHpState()

	local result = orig_champion_damage(self, dmg, damageType)

	if attackerName ~= nil then
		logPartyHpStateChanges(oldState, attackerName .. " attacked $name... $change damage.", true, "COMBAT")
	end
	
	return result
end

-- COMBAT / STATS - Monster death AND ensuing xp
local orig_monsterComponent_die = MonsterComponent.die
function MonsterComponent:die(gainExp)
	isMonitoringXp = true
	EventLog:addLogItem("COMBAT", self.go.arch.name .. " died.")
	local oldState = getPartyXpState()

	local result = orig_monsterComponent_die(self, gainExp)

	logPartyXpStateChanges(oldState)
	isMonitoringXp = false

	return result
end

-- EFFECT - health gain
local orig_champion_regainHealth = Champion.regainHealth
function Champion:regainHealth(amount)
	local oldState = getPartyHpState()

	local result = orig_champion_regainHealth(self, amount)

	logPartyHpStateChanges(oldState, "$name is healed for $change hp.")

	return result
end

-- EFFECT - energy gain
local orig_champion_regainEnergy = Champion.regainEnergy
function Champion:regainEnergy(amount)
	local oldState = getPartyEpState()

	local result = orig_champion_regainEnergy(self, amount)

	logPartyEpStateChanges(oldState, "$name is energized for $change hp.")

	return result
end

-- EFFECT - condition added to champion
local orig_champion_setCondition = Champion.setCondition
function Champion:setCondition(name, value, forceLog)
	-- Don't log level-up condition.  Poisoned is checked separately (to include the damage).
	-- Empty champion name & condition="death" is a side-effect of game ending.  Don't log it.
	if (name == "level_up") or
	   (name == "poison" and value == true) or
	   (self.name == "" and name == "dead") then
		return orig_champion_setCondition(self, name, value)
	end
	local pre_condition = self:hasCondition(name)

	local result = orig_champion_setCondition(self, name, value)

	if self:hasCondition(name) == pre_condition and not forceLog then
		-- Nothing happened, don't log unless forced
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
		EventLog:addLogItem("EFFECT", self.name .. conditionText .. ".", true)
	else
		EventLog:addLogItem("EFFECT", self.name .. " no longer " .. conditionText .. ".", true)
	end

	return result
end

-- EFFECT - Timed conditions aren't removed through "Champion:setCondition()" (above).  This calls it for them to create the log.
local orig_champion_updateConditions = Champion.updateConditions
function Champion:updateConditions()
	local pre_conditions = {}
	for name,_ in pairs(self.conditions) do
		pre_conditions[#pre_conditions+1] = name
	end

	local result = orig_champion_updateConditions(self)

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
	
	return result
end

-- EFFECT - Condition added to monster
local orig_monsterComponent_setCondition = MonsterComponent.setCondition
function MonsterComponent:setCondition(condition, duration)
	local pre_hasCondition = self:hasCondition(condition)

	local result = orig_monsterComponent_setCondition(self, condition, duration)

	if not pre_hasCondition and self:hasCondition(condition) then
		if condition == "burning" then condition = "set on fire"
		elseif condition == "sleep" then condition = "put to sleep"
		elseif condition == "sleeping" then condition = "put to sleep" end
		EventLog:addLogItem("EFFECT", self.go.arch.name .. " was " .. condition .. ".")
	end

	return result
end

-- EFFECT - drowning
local orig_partyComponent_updateDiving = PartyComponent.updateDiving
function PartyComponent:updateDiving()
	local oldState = getPartyHpState()

	local result = orig_partyComponent_updateDiving(self)

	logPartyHpStateChanges(oldState, "$name is drowning... $change damage.", true)

	return result
end

-- EFFECT - Falling
local orig_partyComponent_onFallingImpact = PartyComponent.onFallingImpact
function PartyComponent:onFallingImpact(velocity, distanceFallen)
	local oldState = getPartyHpState()

	result = orig_partyComponent_onFallingImpact(self, velocity, distanceFallen)

	logPartyHpStateChanges(oldState, "$name fell... $change damage.", true)

	return result
end

-- EFFECT - Poison
local orig_poisonCondition_tick = PoisonCondition.tick
function PoisonCondition:tick(champion)
	local oldState = getPartyHpState()

	local result = orig_poisonCondition_tick(self, champion)

	logPartyHpStateChanges(oldState, "$name is poisoned... $change damage.", true)

	return result
end

-- ACTION - Button
local orig_buttonComponent_onClick = ButtonComponent.onClick
function ButtonComponent:onClick()
	EventLog:addLogItem("ACTION", "Button clicked.")
	return orig_buttonComponent_onClick(self)
end

-- ACTION - Floor trigger
local orig_floorTriggerComponent_activate = FloorTriggerComponent.activate
function FloorTriggerComponent:activate()
	EventLog:addLogItem("ACTION", "Pressure plate triggered.")
	return orig_floorTriggerComponent_activate(self)
end
local orig_floorTriggerComponent_deactivate = FloorTriggerComponent.deactivate
function FloorTriggerComponent:deactivate()
	EventLog:addLogItem("ACTION", "Pressure plate untriggered.")
	return orig_floorTriggerComponent_deactivate(self)
end

-- ACTION - Lever
local orig_leverComponent_toggle = LeverComponent.toggle
function LeverComponent:toggle()
	if self.activated then
		EventLog:addLogItem("ACTION", "Lever deactivated.")
	else
		EventLog:addLogItem("ACTION", "Lever activated.")
	end

	return orig_leverComponent_toggle(self)
end

-- ACTION - Rest begun
local orig_partyComponent_rest = PartyComponent.rest
function PartyComponent:rest(text, timeMultiplier)
	local result = orig_partyComponent_rest(self, text, timeMultiplier)

	if party.resting then
		EventLog:addLogItem("ACTION", "Resting.", true)
	end

	return result
end

-- ACTION - Rest ended
local orig_partyComponent_wakeUp = PartyComponent.wakeUp
function PartyComponent:wakeUp(restInterrupted)
	if party.resting then
		if restInterrupted then
			EventLog:addLogItem("ACTION", "Rest interrupted.", true)
		else
			EventLog:addLogItem("ACTION", "Rest ended.", true)
		end
	end

	return orig_partyComponent_wakeUp(self, restInterrupted)
end

-- ACTION - Used healing crystal
local orig_crystalComponent_onClick = CrystalComponent.onClick
function CrystalComponent:onClick()
	EventLog:addLogItem("ACTION", "Healing crystal used.", true)
	orig_crystalComponent_onClick(self)
end

-- ACTION - Find secret
local orig_secretComponent_activate = SecretComponent.activate
function SecretComponent:activate()
	EventLog:addLogItem("ACTION", "Secret found.", true)
	return orig_secretComponent_activate(self)
end

-- STATS - levelup
local orig_champion_levelUp = Champion.levelUp
function Champion:levelUp()
	EventLog:addLogItem("STATS", self.name .. " leveled to " .. (self.level+1) .. ".")
	return orig_champion_levelUp(self)
end

-- STATS - Experience from digging up chest
local orig_diggingToolComponent_diggingFinished = DiggingToolComponent.diggingFinished
function DiggingToolComponent:diggingFinished()
	isMonitoringXp = true
	local oldState = getPartyXpState()

	local result = orig_diggingToolComponent_diggingFinished(self)

	logPartyXpStateChanges(oldState)
	isMonitoringXp = false

	return result
end

-- STATS - Experience from anything not otherwise handled
local orig_champion_gainExp = Champion.gainExp
function Champion:gainExp(xp)
	if isMonitoringXp then
		return orig_champion_gainExp(self, xp)
	end
	local oldState = getPartyXpState()

	local result = orig_champion_gainExp(self, xp)

	logPartyXpStateChanges(oldState)

	return result
end

-- STATS - skill increase
local orig_champion_trainSkill = Champion.trainSkill
function Champion:trainSkill(name, times, spendPoints)
	EventLog:addLogItem("STATS", self.name .. " gained " .. times .. " in " .. name .. " skill.")
	return orig_champion_trainSkill(self, name, times, spendPoints)
end

-- STATS - gain trait
local orig_champion_addTrait = Champion.addTrait
function Champion:addTrait(name)
	local pre_hasTrait = self:hasTrait(name)

	local result = orig_champion_addTrait(self, name)

	if not pre_hasTrait and self:hasTrait(name) then
		EventLog:addLogItem("STATS", self.name .. " learned " .. name .. " trait.")
	end

	return result
end

-- STATS - stat increase
local orig_champion_upgradeBaseStat = Champion.upgradeBaseStat
function Champion:upgradeBaseStat(name, value)
	EventLog:addLogItem("STATS", self.name .. "'s " .. name .. " raised.  " .. (self.stats[name].current ) .. " to " .. (self.stats[name].current + value) .. ".")
	return orig_champion_upgradeBaseStat(self, name, value)
end
