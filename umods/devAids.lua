-- A flag other scripts can check
DEV_MODE = true

-- If true, a log file is opened with "devLog_write()" to write to it
OPEN_DEV_LOG = true

-- The name of the umod under development.  All locals for this umod will be globalized.
DEV_UMOD = ""

-- If set, the dungeon mod with this name will be autostarted
AUTOSTART_DUNGEON = ""

-- A table to store global stuff for debugging
g = g or {}
Config.g = g
Config._G = _G

-- A method to run the "patch.lua" file.
function patch()
	dofile("patch.lua")
end

-- Function to view the keys a table holds
function printKeys(val, page, filter, showValues)
	if type(val) ~= "table" then
		console:print("The given value is " .. type(val) .. " (table expected).")
		return
	end
	page = page or 1
	filter = filter or ""
	local i = 0
	local count = 0
	for k,_ in pairs(val) do
		if type(k) ~= "string" or k:find(filter) then
			count = count + 1
		end
	end
	console:print("  Keys list (Page " .. page .. " of " .. math.ceil(count/10) .. ")")
	for k,v in pairs(val) do
		if type(k) ~= "string" or k:find(filter) then
			i = i + 1
			if math.ceil(i/10) == page then
				if showValues then
					console:print("  " .. i .. ". " .. k, v)
				else
					console:print("  " .. i .. ". " .. k)
				end
			end
		end
	end
end

-- Rapid app exit
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


-- Setup the log file
devLog = nil
if OPEN_DEV_LOG then
	devLog = io.open("devAids.log", "w")
end
function devLog_write(toWrite)
	console:print(toWrite)
	if devLog then
		devLog:write(toWrite .. "\n")
		devLog:flush()
	end
end

-- load the DEV_UMOD into Grimrock 2
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

-- Autostart dungeon
if AUTOSTART_DUNGEON and AUTOSTART_DUNGEON ~= "" then
	local orig_gameMode_update = GameMode.update
	function GameMode:update()
		GameMode.update = orig_gameMode_update
		local mod = modSystem:getModByGuid(AUTOSTART_DUNGEON:lower())
		if mod then
			devLog_write("DevAids: Loading autostart dungeon mod: \"" .. AUTOSTART_DUNGEON .. "\".")
			modSystem:initMod(mod.guid)
			gameMode:loadDefaultParty()
			gameMode:startGame()
		else
			devLog_write("DevAids: Autostart dungeon mod not found: \"" .. AUTOSTART_DUNGEON .. "\".")
		end
	end
end
