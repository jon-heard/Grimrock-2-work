-- A flag other scripts can check
DEV_MODE = true

-- If true, a log file is opened with "devLog_write()" to write to it
--OPEN_DEV_LOG = true

-- The name of the umod under development.  All locals for this umod will be globalized.
--DEV_SCRIPT = ""

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
function drawRay(ray, color, transform)
	color = color or Color.White
	transform = transform or mat.identity()
	local v1 = mat.transformPoint(ray.pos, transform)
	local v2 = mat.transformPoint(ray.pos + (ray.direction * 100), transform)
	DebugDraw.drawLine3(v1, v2, color)
end


-- Setup the log file
devLog = nil
if OPEN_DEV_LOG then
	devLog = io.open("devAids.log", "w")
end
function devLog_write(toWrite)
	if not devLog then return end
	devLog:write(toWrite .. "\n")
	devLog:flush()
end

-- load the DEV_SCRIPT into Grimrock 2
local scriptFile = io.open(config.documentsFolder .. "/mods/" .. (DEV_SCRIPT or "") .. ".lua")
if not DEV_SCRIPT or DEV_SCRIPT == "" then
	-- Do nothing as dev_script isn't defined
elseif scriptFile == nil then
	devLog_write("DevAids: Umod '" .. DEV_SCRIPT .. "' not opened.")
else
	local scriptText = scriptFile:read("*all")
	scriptFile:close()
	scriptText = scriptText:gsub("\nlocal ", "\n")
	local scriptLua, scriptLuaError = loadstring(scriptText)
	if scriptLua == nil then
		devLog_write("DevAids: Error on compiling umod '" .. DEV_SCRIPT .. "': ", scriptLuaError)
	else
		scriptLua()
		devLog_write("DevAids: Umod '" .. DEV_SCRIPT .. "' loaded with globalized locals.")
	end
end
