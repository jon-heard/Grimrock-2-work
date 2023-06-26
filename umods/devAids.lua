-- Enables / disables the subsequent active features.  Global so that other umods can use it.
DEV_MODE = true

-- If true, pressing the escape key will quit the app
local ESC_QUITS = true

-- Display mouse state
local SHOW_MOUSE_STATS = true

-- If true, a log file is opened & "dlog()" (which prints to console) also writes to this log file.
local WRITE_DEV_LOGS_TO_FILE = true

-- If set, the dungeon mod with this name will be autostarted when grimrock 2 is run.
local AUTOSTART_DUNGEON = ""

-- A umod listed here (instead of mods.cfg) is loaded but with all locals globalized ("\nlocal " is removed throughout).
local DEV_UMOD = ""





-- A table to store global stuff for debugging
g = g or {}
Config.g = g
Config._G = _G

-- A method to run lua code from "patch.lua" file (located beside "grimrock2.exe").
function patch()
	dofile("patch.lua")
end

-- Allows printing a string with multiple lines to the console (which bugs on "console:print()")
function console_printLines(linedText)
	local lines = string.split(linedText, "\n")
	for _,line in ipairs(lines) do
		console:print(line)
	end
end

-- Function to view the keys a table holds.  Prints to console AND returns what was printed.
function printKeys(val, page, showValues, filter)
	local result = ""
	if type(val) ~= "table" then
		result = result .. "The given value is " .. type(val) .. " (table expected)."
	else
		page = page or 1
		filter = filter or ""
		local i = 0
		local count = 0
		for k,_ in pairs(val) do
			if type(k) ~= "string" or k:find(filter) then
				count = count + 1
			end
		end
		result = result .. "  Keys list (Page " .. page .. " of " .. math.ceil(count/10) .. ")"
		for k,v in pairs(val) do
			if type(k) ~= "string" or k:find(filter) then
				i = i + 1
				if math.ceil(i/10) == page then
					if showValues then
						result = result .. "\n  " .. i .. ". " .. k .. " = " .. tostring(v)
					else
						result = result .. "\n  " .. i .. ". " .. k
					end
				end
			end
		end
	end
	console_printLines(result)
	return result
end

-- Set a function to be called every "rate" seconds
function setHeartbeatFunction(rate, fnc)
	heartbeatFunction = fnc
	heartbeatRate = math.max(.25, rate)
	lastHeartbeatTime = 0
end
-- Call this each frame to run the heartbeat function
function updateHeartbeat()
	if heartbeatFunction == nil then return end
	local currentTime = Time.currentTime
	if currentTime - lastHeartbeatTime > heartbeatRate then
		lastHeartbeatTime = currentTime
		heartbeatFunction()
	end
end
local heartbeatFunction = nil
local heartbeatRate = 0
local lastHeartbeatTime = 0

-- Function to quickly quit
function x()
	sys.exit()
end

-- Easily view any RenderableTexture.  Assign it to "g.seeTex" and it will be drawn to the screen.
-- Optional params:
--   - g.seeTex_scale - Draw the texture at a scale other than 1.0
--   - g.seeTex_rect - Draw only a section of the texture
--   - g.seeTex_pos - Draw the texture at a position other than the top-left of the screen
local orig_gui_draw = Gui.draw
function Gui:draw(...)
	local result = orig_gui_draw(self, ...)
	if type(g.seeTex) == "userdata" then
		local scale = 1
		local rect = { 0, 0, g.seeTex:getWidth(), g.seeTex:getHeight() }
		local position = { 0, 0 }
		if type(g.seeTex_scale) == "number" then
			scale = g.seeTex_scale
		end
		if type(g.seeTex_rect) == "table" then
			rect = g.seeTex_rect
		end
		if type(g.seeTex_pos) == "table" then
			position = g.seeTex_pos
		end
		ImmediateMode.beginDraw()
		ImmediateMode.drawImage(
			g.seeTex,  position[1],position[2],  rect[1],rect[2],  rect[3],rect[4],  rect[3]*scale,rect[4]*scale,  Color.White)
		ImmediateMode.endDraw()
	end
	return result
end

-- Draw primitive objects to the scene
function drawSphereObject(sphere, color, transform)
	color = color or Color.White
	transform = transform or mat.identity()
	DebugDraw.drawSphere(mat.transformPoint(sphere.pos, transform), sphere.radius, color)
end
function drawBoxObject(box, color, transform)
	color = color or Color.White
	transform = transform or mat.identity()
	DebugDraw.drawBox3(box.pos - box.hsize, box.pos + box.hsize, transform, color)
end
function drawRayObject(ray, color, transform)
	color = color or Color.White
	transform = transform or mat.identity()
	local v1 = mat.transformPoint(ray.pos, transform)
	local v2 = mat.transformPoint(ray.pos + (ray.dir * 100), transform)
	DebugDraw.drawLine3(v1, v2, color)
end





-- Logic - have escape key quit the game
if DEV_MODE and ESC_QUITS then
	local orig_gameMode_keyPressed = GameMode.keyPressed
	function GameMode:keyPressed(event, ...)
		if event.key == "escape" and not event.isInjected then
			sys.exit()
		end
		return orig_gameMode_keyPressed(self, event, ...)
	end
end

-- Logic - show mouse stats
if DEV_MODE and SHOW_MOUSE_STATS then
	-- Copy these methods as they could be overridden later (they are by VR)
	local orig_sys_mousePos = sys.mousePos
	local orig_sys_mouseDown = sys.mouseDown

	-- Override Console:draw simply as something that draws regularly
	local orig_console_draw = Console.draw
	function Console:draw(...)
		local x, y = orig_sys_mousePos()
		local left = orig_sys_mouseDown(0) and 1 or 0
		local mid = orig_sys_mouseDown(1) and 1 or 0
		local right = orig_sys_mouseDown(2) and 1 or 0
		ImmediateMode.beginDraw()
		gui:drawTextAligned(
			x .. "x" .. y .. ", " .. left .. ", " .. mid .. ", " ..right,
			config.width - 20, config.height - 50, "right", FontType.Default)
		ImmediateMode.endDraw()

		return orig_console_draw(self, ...)
	end
end

-- Logic - log file written to by "dlog()".
devLogFileHandle = nil
if DEV_MODE and WRITE_DEV_LOGS_TO_FILE then
	devLogFileHandle = io.open("devAids.log", "w")
end
function dlog(toLog)
	toLog = tostring(toLog)
	console:print(toLog)
	if devLogFileHandle then
		devLogFileHandle:write(tostring(toLog) .. "\n")
		devLogFileHandle:flush()
	end
end

-- Logic - load and run DEV_UMOD
if DEV_MODE and DEV_UMOD and DEV_UMOD ~= "" then
	local scriptFile = io.open(config.documentsFolder .. "/Mods/" .. (DEV_UMOD or ""))
	if scriptFile == nil then
		dlog("DevAids: Umod '" .. DEV_UMOD .. "' not opened.")
	else
		local scriptText = scriptFile:read("*all")
		scriptFile:close()
		scriptText = scriptText:gsub("\nlocal ", "\n")
		dlog("DevAids: Loading Umod '" .. DEV_UMOD .. "'...")
		local scriptLua, scriptLuaError = loadstring(scriptText)
		if scriptLua == nil then
			dlog("DevAids: Error on loading umod '" .. DEV_UMOD .. "': " .. scriptLuaError)
		else
			scriptLua()
			dlog("DevAids: Umod '" .. DEV_UMOD .. "' successfully loaded with globalized locals.")
		end
	end
end

-- One extra log to separate init logs from user logs
function initLogsFinished()
	dlog("----------------")
	dlog("")
end

-- Logic - autostart dungeon
if DEV_MODE and AUTOSTART_DUNGEON and AUTOSTART_DUNGEON ~= "" then
	local orig_gameMode_update = GameMode.update
	function GameMode:update(...)
		local mod = modSystem:getModByGuid(AUTOSTART_DUNGEON:lower())
		if mod then
			dlog("DevAids: Loading autostart dungeon mod: \"" .. AUTOSTART_DUNGEON .. "\"...")
			modSystem:initMod(mod.guid)
			gameMode:loadDefaultParty()
			gameMode:startGame()
			dlog("DevAids: Autostart dungeon mod loaded.")
		else
			dlog("DevAids: Autostart dungeon mod not found: \"" .. AUTOSTART_DUNGEON .. "\".")
		end
		initLogsFinished()

		-- only needed the function once
		GameMode.update = orig_gameMode_update
		GameMode.update(self, ...)
	end
elseif DEV_MODE then
	initLogsFinished()
end
