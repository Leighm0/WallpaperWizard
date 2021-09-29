---------------
-- Globals
---------------
do
	EX_CMD = {}
	LUA_ACTION = {}
end

-----------------------------------------------------------------------------
--Function Name : SendToDevices
--Parameters    : tList(table), strCommand(string), tParams(table)
--Description   : Function called to send wallpaper change to Identity agent.
-----------------------------------------------------------------------------
function SendToDevices(tList, strCommand, strWallpaper)
	tList = trim(tList) .. ","
	local tParams = {}
	local agent = "control4_agent_identity.c4i"
	local devices = C4:GetDevicesByC4iName(agent)
	local proxyId = ""
	if (devices ~= nil) then
		for k,v in pairs(devices) do
			if (v == "Identity") then proxyId = k end
		end
    end
	if (proxyId == "") then return end
	for id in tList:gfind("(%d+),") do
		local roomId = tonumber(id) or 0
		if (roomId == 0) then break end
		tParams["USERNAME"] = "primaryuser"
		tParams["LOCATION_ID"] = roomId
		tParams["NAME"] = "wallpaper"
		tParams["VALUE"] = strWallpaper
		C4:SendToDevice(proxyId, strCommand, tParams)
		Dbg("C4:SendToDevice(5, \"" .. strCommand .. "\", " .. formatParams(tParams) .. ")")
	end
end

----------------------------------------------------------------------------------
--Function Name : EX_CMD.SETWALLPAPER
--Parameters    : tParams(table)
--Description   : Function called when "Set Wallpaper" ExecuteCommand is received.
----------------------------------------------------------------------------------
function EX_CMD.SETWALLPAPER(tParams)
	Dbg("[EX_CMD] Set Wallpaper" .. " (" .. formatParams(tParams) .. ")")
    local list = tParams["Room Selection"] or ""
    local wallpaper = tParams["Wallpaper"] or ""
    if (list == "") or (wallpaper == "") then return end
    SendToDevices(list, "SET_LOCATION_PREFERENCE", wallpaper)
end

-----------------------------------------------------------------------------
--Function Name : EX_CMD.LUA_ACTION
--Parameters    : tParams(table)
--Description   : Function called when LUA ACTION ExecuteCommand is received.
-----------------------------------------------------------------------------
function EX_CMD.LUA_ACTION(tParams)
	Dbg("[EX_CMD] LUA_ACTION" .. " (" ..  formatParams(tParams) .. ")")
	if (tParams ~= nil) then
		for cmd, cmdv in pairs(tParams) do 
			if (cmd == "ACTION" and cmdv ~= nil) then
				local status, err = pcall(LUA_ACTION[cmdv], tParams)
				if (not status) then
					print("LUA_ERROR: " .. err)
				end
				break
			end
		end
	end
end

-----------------------------------------------------------------------------------------------------
--Function Name : ExecuteCommand
--Parameters    : strCommand(string), tParams(table)
--Description   : Function called by Director when a command is received for this DriverWorks driver.
-----------------------------------------------------------------------------------------------------
function ExecuteCommand(strCommand, tParams)
	Dbg("ExecuteCommand: " .. strCommand .. " (" ..  formatParams(tParams) .. ")")
	local strCommand = string.upper(strCommand)
	local trimmedCommand = string.gsub(strCommand, " ", "")
	local status, err
	if (EX_CMD[strCommand] ~= nil and type(EX_CMD[strCommand]) == "function") then
		status, err = pcall(EX_CMD[strCommand], tParams)
	elseif (EX_CMD[trimmedCommand] ~= nil and type(EX_CMD[trimmedCommand]) == "function") then
		status, err = pcall(EX_CMD[trimmedCommand], tParams)
	elseif (EX_CMD[strCommand] ~= nil) then
		QueueCommand(EX_CMD[strCommand])
		status = true
	else
		print("ExecuteCommand: Unhandled command = " .. strCommand)
		status = true
	end
	if (not status) then
		print("LUA_ERROR: " .. err)
	end
end

----------------------------------------------------------------------------
--Function Name : OnPropertyChanged(strProperty)
--Parameters    : strProperty(string)
--Description   : Function called by Director when a property changes value.
----------------------------------------------------------------------------
function OnPropertyChanged(strProperty)
	local prop = Properties[strProperty]
	if (strProperty == "Debug Mode") then
		gDbgTimer = C4:KillTimer(gDbtTimer or 0)
		gDbgPrint, gDbgLog = (prop:find("Print") ~= nil), (prop:find("Log") ~= nil)
		if (prop == "Off") then return end
		gDbgTimer = C4:AddTimer(8, "HOURS")
		Dbg("Enabled Debug Timer for 8 hours")
		return
	end
end

--------------------------------------------------------------------------
--Function Name : GetWallpaperList
--Parameters    : currentValue(string)
--Description   : Function called with CUSTOM_SELECT Property in Commands.
--------------------------------------------------------------------------
function GetWallpaperList (currentValue)
	local list = {}
	local wallpapers = {}
	
	-- Custom Wallpapers
	local custom_dir = C4:FileSetDir("/media/wallpaper/onscreen/custom")
	local custom_wallpapers = C4:FileList(custom_dir)

	---- Add in custom wallpaper list from files on controller
	for id, filename in pairs (custom_wallpapers) do
		local item = {
			value = "/media/wallpaper/onscreen/custom/" .. filename,
			text = filename,
		}
		table.insert (list, item)
	end

	-- Default Wallpapers
	local def_dir = C4:FileSetDir("/media/wallpaper/onscreen/default")
	local def_wallpapers = C4:FileList(def_dir)

	---- Add in wallpaper list from files on controller
	for id, filename in pairs (def_wallpapers) do
		local item = {
			value = "/media/wallpaper/onscreen/default/" .. filename,
			text = filename,
		}
		table.insert (list, item)
	end

	local _sort = function (a, b)
		return (a.text < b.text)
	end

	table.sort (list, _sort)

	return list
end

---------------------------------------------------------------------------------------------
--Function Name : Dbg
--Parameters    : strDebugText(string)
--Description   : Function called when debug information is to be printed/logged (if enabled)
---------------------------------------------------------------------------------------------
function Dbg(strDebugText)
	if (gDbgPrint) then print(strDebugText) end
	if (gDbgLog) then C4:DebugLog("\r\n" .. strDebugText) end
end

----------------------------------------------------------------
--Function Name : trim
--Parameters    : s(string)
--Description   : Function called to trim whitespace in a string
----------------------------------------------------------------
function trim(s)
	return s:gsub("^%s*(.-)%s*$", "%1")
end

---------------------------------------------------------
--Function Name : formatParams
--Parameters    : tParams(table)
--Description   : Function called to format table params.
---------------------------------------------------------
function formatParams(tParams)
	tParams = tParams or {}
	local out = {}
	for k,v in pairs(tParams) do
		if (type(v) == "string") then
			table.insert(out, k .. " = \"" .. v .. "\"")
		else
			table.insert(out, k .. " = " .. tostring(v))
		end
	end
	return "{" .. table.concat(out, ", ") .. "}"
end

-----------------------------------------------------------------------------------------------------------------------------
--Function Name : OnDriverDestroyed
--Description   : Function called when a driver is deleted from a project, updated within a project or Director is shut down.
-----------------------------------------------------------------------------------------------------------------------------
function OnDriverDestroyed()
	gDbgTimer = C4:KillTimer(gDbgTimer or 0)
end

----------------------------------------------------------------------------
--Function Name : OnDriverInit
--Description   : Function invoked when a driver is loaded or being updated.
----------------------------------------------------------------------------
function OnDriverInit()
	C4:AllowExecute(true)
end

------------------------------------------------------------------------------------------------
--Function Name : OnDriverLateInit
--Description   : Function that serves as a callback into a project after the project is loaded.
------------------------------------------------------------------------------------------------
function OnDriverLateInit()
	for k,v in pairs(Properties) do OnPropertyChanged(k) end
end

print("Driver Loaded..." .. os.date())
