-- A flag other scripts can check
DEV_MODE = true

-- If true, pressing the escape key will quit the app
ESC_QUITS = true

-- If true, a log file is opened.
-- "devLog_write()" writes to this log file.  "devLog_write()" prints to console regardless.
WRITE_DEV_LOGS_TO_FILE = false

-- If set, the dungeon mod with this name will be autostarted when grimrock 2 is run.
AUTOSTART_DUNGEON = "z_TestInteraction"

-- A umod listed here (instead of mods.cfg) is loaded but with all locals globalized ("\nlocal " is removed throughout).
DEV_UMOD = "vr_dev"

-- A table to store global stuff for debugging
g = g or {}
Config.g = g
Config._G = _G





-- A method to run lua code from "patch.lua" file (located beside "grimrock2.exe").
function patch()
	dofile("patch.lua")
end

-- Function to view the keys a table holds.  Prints to console AND returns what was printed.
function printKeys(val, page, filter, showValues)
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
if ESC_QUITS then
	local orig_gameMode_keyPressed = GameMode.keyPressed
	function GameMode:keyPressed(event)
		if event.key == "escape" then
			sys.exit()
		end
		return orig_gameMode_keyPressed(self, event)
	end
end

-- Logic - log file written to by "devLog_write()".
devLog = nil
if WRITE_DEV_LOGS_TO_FILE then
	devLog = io.open("devAids.log", "w")
end
function devLog_write(toWrite)
	console:print(toWrite)
	if devLog then
		devLog:write(tostring(toWrite) .. "\n")
		devLog:flush()
	end
end

-- Logic - load and run DEV_UMOD
if DEV_UMOD and DEV_UMOD ~= "" then
	local scriptFile = io.open(config.documentsFolder .. "/mods/" .. (DEV_UMOD or "") .. ".lua")
	if scriptFile == nil then
		devLog_write("DevAids: Umod '" .. DEV_UMOD .. "' not opened.")
	else
		local scriptText = scriptFile:read("*all")
		scriptFile:close()
		scriptText = scriptText:gsub("\nlocal ", "\n")
		devLog_write("DevAids: Loading Umod '" .. DEV_UMOD .. "'...")
		local scriptLua, scriptLuaError = loadstring(scriptText)
		if scriptLua == nil then
			devLog_write("DevAids: Error on loading umod '" .. DEV_UMOD .. "': " .. scriptLuaError)
		else
			scriptLua()
			devLog_write("DevAids: Umod '" .. DEV_UMOD .. "' successfully loaded with globalized locals.")
		end
	end
end

-- Logic - autostart dungeon
if AUTOSTART_DUNGEON and AUTOSTART_DUNGEON ~= "" then
	local orig_gameMode_update = GameMode.update
	function GameMode:update()
		GameMode.update = orig_gameMode_update
		local mod = modSystem:getModByGuid(AUTOSTART_DUNGEON:lower())
		if mod then
			devLog_write("DevAids: Loading autostart dungeon mod: \"" .. AUTOSTART_DUNGEON .. "\"...")
			modSystem:initMod(mod.guid)
			gameMode:loadDefaultParty()
			gameMode:startGame()
			devLog_write("DevAids: Autostart dungeon mod loaded.")
		else
			devLog_write("DevAids: Autostart dungeon mod not found: \"" .. AUTOSTART_DUNGEON .. "\".")
		end
	end
end
