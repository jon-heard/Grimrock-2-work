DEV_MODE = true

g = g or {}
Config.g = g
Config._G = _G

function patch()
	dofile("patch.lua")
end

function printKeys(val, page, includeValues)
	page = page or 1
	local i = 0
	local count = 0
	for _,_ in pairs(val) do
		count = count + 1
	end
	console:print("  Keys list (Page " .. page .. " of " .. math.ceil(count/10) .. ")")
	for k,v in pairs(val) do
		i = i + 1
		if math.ceil(i/10) == page then
			if includeValues then
				console:print("  " .. i .. ". " .. k, v)
			else
				console:print("  " .. i .. ". " .. k)
			end
		end
	end
end