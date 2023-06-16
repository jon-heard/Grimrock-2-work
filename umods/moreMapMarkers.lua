-- This file contains sections of Legend of Grimrock 2 source code; anything you
-- do with this file must comply with the Grimrock modding terms:
-- http://www.grimrock.net/modding_log1/modding-and-asset-usage-terms/
--
-- You are free to alter this mod or reuse its code in other Grimrock mods.

--[=[
=== UModManager Info Section ===
id = "moreMapMarkers"
name = "More Map Markers"
description = [[This mod adds 8 more icons to select from when marking up a dungeon map.

Made by Violgamba.]]
version = "1.1"
modifiedFields = { "GuiItem", "MapMode.MarkerSymbols" }
overwrittenFields = { "MapMode.updateToolBar" }
compatibilityOverrides = {}
requiredMods = {}
=== End of Mod Info ===
]=]

local leftColOffset = -20
local rightColOffset = 15
local extrasImagePath = config.documentsFolder .. "/mods/moreMapMarkers_symbols.tga"
GuiItem["MapToolsExtra1"]      = { width = 32; height = 32; x = 0;   y = 0;  image = extrasImagePath }
GuiItem["MapToolsExtra2"]      = { width = 32; height = 32; x = 32;  y = 0;  image = extrasImagePath }
GuiItem["MapToolsExtra3"]      = { width = 32; height = 32; x = 64;  y = 0;  image = extrasImagePath }
GuiItem["MapToolsExtra4"]      = { width = 32; height = 32; x = 96;  y = 0;  image = extrasImagePath }
GuiItem["MapToolsExtra5"]      = { width = 32; height = 32; x = 128; y = 0;  image = extrasImagePath }
GuiItem["MapToolsExtra6"]      = { width = 32; height = 32; x = 160; y = 0;  image = extrasImagePath }
GuiItem["MapToolsExtra7"]      = { width = 32; height = 32; x = 192; y = 0;  image = extrasImagePath }
GuiItem["MapToolsExtra8"]      = { width = 32; height = 32; x = 224; y = 0;  image = extrasImagePath }
GuiItem["MapToolsExtra1Hover"] = { width = 32; height = 32; x = 0;   y = 32; image = extrasImagePath }
GuiItem["MapToolsExtra2Hover"] = { width = 32; height = 32; x = 32;  y = 32; image = extrasImagePath }
GuiItem["MapToolsExtra3Hover"] = { width = 32; height = 32; x = 64;  y = 32; image = extrasImagePath }
GuiItem["MapToolsExtra4Hover"] = { width = 32; height = 32; x = 96;  y = 32; image = extrasImagePath }
GuiItem["MapToolsExtra5Hover"] = { width = 32; height = 32; x = 128; y = 32; image = extrasImagePath }
GuiItem["MapToolsExtra6Hover"] = { width = 32; height = 32; x = 160; y = 32; image = extrasImagePath }
GuiItem["MapToolsExtra7Hover"] = { width = 32; height = 32; x = 192; y = 32; image = extrasImagePath }
GuiItem["MapToolsExtra8Hover"] = { width = 32; height = 32; x = 224; y = 32; image = extrasImagePath }
MapMode.MarkerSymbols.extra1 = "MapToolsExtra1"
MapMode.MarkerSymbols.extra2 = "MapToolsExtra2"
MapMode.MarkerSymbols.extra3 = "MapToolsExtra3"
MapMode.MarkerSymbols.extra4 = "MapToolsExtra4"
MapMode.MarkerSymbols.extra5 = "MapToolsExtra5"
MapMode.MarkerSymbols.extra6 = "MapToolsExtra6"
MapMode.MarkerSymbols.extra7 = "MapToolsExtra7"
MapMode.MarkerSymbols.extra8 = "MapToolsExtra8"

function MapMode:updateToolBar()
	local width,height = GuiItem.MapToolsBackground.width, GuiItem.MapToolsBackground.height
	local x,y = config.width - width, config.height/2 - height/2

	gui:drawGuiItem(GuiItem.MapToolsBackground, x, y)

	gui:buttonLogic("toolbar", x, y, width, height)

	x = x + width/2 + 15
	y = y + 40

	-- close button
	if gui:button("map_close", GuiItem.MapToolsClose, x - GuiItem.MapToolsClose.width/2, y, GuiItem.MapToolsCloseHover) then
		self:close()
	end

-- UMOD

	y = y + 70

	if gui:button("map_text", GuiItem.MapToolsQuil, x - GuiItem.MapToolsQuil.width/2 + leftColOffset, y, GuiItem.MapToolsQuilHover) then
		self.tool = "place_marker"
		self.markerSymbol = "quil"
	end
	y = y + 40

	if gui:button("map_cross", GuiItem.MapToolsCross, x - GuiItem.MapToolsCross.width/2 + leftColOffset, y, GuiItem.MapToolsCrossHover) then
		self.tool = "place_marker"
		self.markerSymbol = "cross"
	end
	y = y + 40

	if gui:button("map_question", GuiItem.MapToolsQuestion, x - GuiItem.MapToolsQuestion.width/2 + leftColOffset, y, GuiItem.MapToolsQuestionHover) then
		self.tool = "place_marker"
		self.markerSymbol = "question"
	end
	y = y + 40

	if gui:button("map_exclamation", GuiItem.MapToolsExclamation, x - GuiItem.MapToolsExclamation.width/2 + leftColOffset, y, GuiItem.MapToolsExclamationHover) then
		self.tool = "place_marker"
		self.markerSymbol = "exclamation"
	end
	y = y + 40

	if gui:button("map_extra1", GuiItem.MapToolsExtra1, x - GuiItem.MapToolsExtra1.width/2 + leftColOffset, y, GuiItem.MapToolsExtra1Hover) then
		self.tool = "place_marker"
		self.markerSymbol = "extra1"
	end
	y = y + 40

	if gui:button("map_extra2", GuiItem.MapToolsExtra2, x - GuiItem.MapToolsExtra2.width/2 + leftColOffset, y, GuiItem.MapToolsExtra2Hover) then
		self.tool = "place_marker"
		self.markerSymbol = "extra2"
	end
	y = y - 200

	if gui:button("map_extra3", GuiItem.MapToolsExtra3, x - GuiItem.MapToolsExtra3.width/2 + rightColOffset, y, GuiItem.MapToolsExtra3Hover) then
		self.tool = "place_marker"
		self.markerSymbol = "extra3"
	end
	y = y + 40

	if gui:button("map_extra4", GuiItem.MapToolsExtra4, x - GuiItem.MapToolsExtra4.width/2 + rightColOffset, y, GuiItem.MapToolsExtra4Hover) then
		self.tool = "place_marker"
		self.markerSymbol = "extra4"
	end
	y = y + 40

	if gui:button("map_extra5", GuiItem.MapToolsExtra5, x - GuiItem.MapToolsExtra5.width/2 + rightColOffset, y, GuiItem.MapToolsExtra5Hover) then
		self.tool = "place_marker"
		self.markerSymbol = "extra5"
	end
	y = y + 40

	if gui:button("map_extra6", GuiItem.MapToolsExtra6, x - GuiItem.MapToolsExtra6.width/2 + rightColOffset, y, GuiItem.MapToolsExtra6Hover) then
		self.tool = "place_marker"
		self.markerSymbol = "extra6"
	end
	y = y + 40

	if gui:button("map_extra7", GuiItem.MapToolsExtra7, x - GuiItem.MapToolsExtra7.width/2 + rightColOffset, y, GuiItem.MapToolsExtra7Hover) then
		self.tool = "place_marker"
		self.markerSymbol = "extra7"
	end
	y = y + 40

	if gui:button("map_extra8", GuiItem.MapToolsExtra8, x - GuiItem.MapToolsExtra8.width/2 + rightColOffset, y, GuiItem.MapToolsExtra8Hover) then
		self.tool = "place_marker"
		self.markerSymbol = "extra8"
	end
	y = y + 35

	if gui:button("map_center", GuiItem.MapToolsCenter, x - GuiItem.MapToolsCenter.width/2, y, GuiItem.MapToolsCenterHover) then
		self:setFocus(party.go.map, party.go.x, party.go.y, true)
	end
	y = y + 90

-- /UMOD

	if gui:button("map_up", GuiItem.MapToolsLevelUp, x - GuiItem.MapToolsLevelUp.width/2, y, GuiItem.MapToolsLevelUpHover) then
		self:changeLevel(-1)
	end
	y = y + 60

	gui:drawGuiItem(GuiItem.MapToolsLevelDivider, x - GuiItem.MapToolsLevelDivider.width/2, y)
	y = y + 10
	if gui:button("map_down", GuiItem.MapToolsLevelDown, x - GuiItem.MapToolsLevelDown.width/2, y, GuiItem.MapToolsLevelDownHover) then
		self:changeLevel(1)
	end
	y = y + 60
end
