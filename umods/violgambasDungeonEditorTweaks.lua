
local orig_dungeonEditor_addObjectTool = DungeonEditor.addObjectTool
function DungeonEditor:addObjectTool(x, y, width, height, pressed)
	local result = orig_dungeonEditor_addObjectTool(self, x, y, width, height, pressed)
	if pressed and not sys.keyDown("control") then
		self:selectTool("select")
	end
	if imgui.state.rightDown then
		self:selectTool("select")
	end
end
