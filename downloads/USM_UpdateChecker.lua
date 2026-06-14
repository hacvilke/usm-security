--[[
────────────────────────────────────────────────────────────
 Universal Security Module (USM) - Update Checker
 Version: v2026.2
 Author: civ
 License: MIT

 INSTALL LOCATION:
 ServerScriptService → USM_UpdateChecker.lua

 PURPOSE:
 Checks GitHub for USM updates using version.json.
 Runs server-side without requiring your own server.

 IMPORTANT:
 This script uses HTTPService to fetch version info from GitHub.
 Make sure HTTPService is enabled in your game settings.
────────────────────────────────────────────────────────────
]]

-- SERVICES
local HTTPService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- LOAD CONFIGURATION
local Config = require(script.Parent.USM_Configuration)

-- VALIDATE SERVER-SIDE
if RunService:IsRunning() and not RunService:IsServer() then
	error("[USM-Update] CRITICAL: This script must run on the server only!")
end

-- CONFIGURATION
local UpdateConfig = Config.UpdateChecker or {
	Enabled = true,
	CheckInterval = 3600,
	VersionURL = "https://raw.githubusercontent.com/hacvilke/usm-security/main/version.json",
	CurrentVersion = "2026.2.0",
	NotifyOnUpdate = true,
	AutoNotifyAdmins = true,
}

-- STATE
local LastCheckTime = 0
local NotifiedVersion = nil

-- ================================
-- VERSION COMPARISON
-- ================================

local function CompareVersions(version1, version2)
	-- Split versions into parts
	local v1Parts = string.split(version1, ".")
	local v2Parts = string.split(version2, ".")
	
	-- Compare each part
	for i = 1, math.max(#v1Parts, #v2Parts) do
		local v1 = tonumber(v1Parts[i]) or 0
		local v2 = tonumber(v2Parts[i]) or 0
		
		if v1 > v2 then
			return 1
		elseif v1 < v2 then
			return -1
		end
	end
	
	return 0
end

-- ================================
-- UPDATE CHECKING
-- ================================

local function CheckForUpdates()
	if not UpdateConfig.Enabled then return end
	
	local now = tick()
	if now - LastCheckTime < UpdateConfig.CheckInterval then
		return
	end
	LastCheckTime = now
	
	local success, response = pcall(function()
		return HTTPService:GetAsync(UpdateConfig.VersionURL)
	end)
	
	if not success then
		warn("[USM-Update] Failed to check for updates:", response)
		return
	end
	
	local successDecode, data = pcall(function()
		return HTTPService:JSONDecode(response)
	end)
	
	if not successDecode then
		warn("[USM-Update] Failed to decode version JSON")
		return
	end
	
	-- Check if update is available
	local comparison = CompareVersions(data.version, UpdateConfig.CurrentVersion)
	
	if comparison > 0 then
		-- New version available
		if NotifiedVersion ~= data.version then
			NotifiedVersion = data.version
			
			print("═══════════════════════════════════════════════════════════════")
			print("[USM-Update] NEW VERSION AVAILABLE!")
			print("═══════════════════════════════════════════════════════════════")
			print(string.format("Current Version: %s", UpdateConfig.CurrentVersion))
			print(string.format("Latest Version:  %s", data.version))
			print(string.format("Version Name:     %s", data.versionName or "N/A"))
			print(string.format("Release Date:     %s", data.releaseDate or "N/A"))
			print("═══════════════════════════════════════════════════════════════")
			
			if data.changelog and #data.changelog > 0 then
				print("Changelog:")
				for _, change in ipairs(data.changelog) do
					print(string.format("  • %s", change))
				end
			end
			
			print("═══════════════════════════════════════════════════════════════")
			
			if data.downloadUrl then
				print(string.format("Download: %s", data.downloadUrl))
			end
			print("═══════════════════════════════════════════════════════════════")
			
			-- Notify admins if enabled
			if UpdateConfig.AutoNotifyAdmins then
				NotifyAdmins(data)
			end
		end
	elseif comparison == 0 then
		print("[USM-Update] USM is up to date (v" .. UpdateConfig.CurrentVersion .. ")")
	else
		print("[USM-Update] Running a newer version than GitHub (v" .. UpdateConfig.CurrentVersion .. ")")
	end
end

-- ================================
-- ADMIN NOTIFICATION
-- ================================

local function NotifyAdmins(updateData)
	local Players = game:GetService("Players")
	
	for _, player in ipairs(Players:GetPlayers()) do
		-- You can customize this to check for admin ranks
		-- For now, we'll just print to console
		-- You could integrate with your admin system here
	end
end

-- ================================
-- INITIALIZATION
-- ================================

local function Initialize()
	if RunService:IsRunning() and not RunService:IsServer() then
		error("[USM-Update] This script must run on the server only!")
		return
	end
	
	print("[USM-Update] Update checker initialized")
	print(string.format("[USM-Update] Current version: %s", UpdateConfig.CurrentVersion))
	print(string.format("[USM-Update] Checking for updates every %d seconds", UpdateConfig.CheckInterval))
	
	-- Initial check
	task.spawn(CheckForUpdates)
	
	-- Periodic checks
	task.spawn(function()
		while true do
			task.wait(60) -- Check every minute
			CheckForUpdates()
		end
	end)
end

-- Run initialization
Initialize()

-- ================================
-- EXPORTED API
-- ================================

local USM_UpdateChecker = {
	-- Manually check for updates
	Check = function()
		LastCheckTime = 0 -- Force check
		CheckForUpdates()
	end,
	
	-- Get current version
	GetCurrentVersion = function()
		return UpdateConfig.CurrentVersion
	end,
	
	-- Enable/disable update checking
	SetEnabled = function(enabled)
		UpdateConfig.Enabled = enabled
	end,
	
	-- Set custom version URL
	SetVersionURL = function(url)
		UpdateConfig.VersionURL = url
	end,
	
	-- Get update configuration
	GetConfig = function()
		return UpdateConfig
	end,
}

return USM_UpdateChecker
