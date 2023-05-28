-- Enables / disables the subsequent active features
DEV_MODE = true

-- If true, pressing the escape key will quit the app
ESC_QUITS = true

-- If true, a log file is opened & "dlog()" (which prints to console) also writes to this log file.
WRITE_DEV_LOGS_TO_FILE = true

-- If set, the dungeon mod with this name will be autostarted when grimrock 2 is run.
AUTOSTART_DUNGEON = ""

-- A umod listed here (instead of mods.cfg) is loaded but with all locals globalized ("\nlocal " is removed throughout).
DEV_UMOD = ""





-- A table to store global stuff for debugging
g = g or {}
Config.g = g
Config._G = _G

-- A method to run lua code from "patch.lua" file (located beside "grimrock2.exe").
function patch()
	dofile("patch.lua")
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
	local lines = string.split(result, "\n")
	for _,v in ipairs(lines) do
		console:print(v)
	end
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
	function GameMode:keyPressed(event)
		if event.key == "escape" then
			sys.exit()
		end
		return orig_gameMode_keyPressed(self, event)
	end
end

-- Logic - log file written to by "dlog()".
devLogFileHandle = nil
if DEV_MODE and WRITE_DEV_LOGS_TO_FILE then
	devLogFileHandle = io.open("devAids.log", "w")
end
function dlog(toWrite)
	console:print(toWrite)
	if devLogFileHandle then
		devLogFileHandle:write(tostring(toWrite) .. "\n")
		devLogFileHandle:flush()
	end
end

-- Logic - load and run DEV_UMOD
if DEV_MODE and DEV_UMOD and DEV_UMOD ~= "" then
	local scriptFile = io.open(config.documentsFolder .. "/Mods/" .. (DEV_UMOD or "") .. ".lua")
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

-- Logic - autostart dungeon
if DEV_MODE and AUTOSTART_DUNGEON and AUTOSTART_DUNGEON ~= "" then
	local orig_gameMode_update = GameMode.update
	function GameMode:update()
		GameMode.update = orig_gameMode_update
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
	end
end
