--[[
────────────────────────────────────────────────────────────
 Universal Security Module (USM) - Remote Event Protection
 Version: v2026.2
 Author: civ
 License: MIT

 INSTALL LOCATION:
 ServerScriptService → USM_Remote_Protection.lua

 PURPOSE:
 Advanced remote event protection with rate limiting,
 argument validation, and exploit pattern detection.

 WARNING:
 This script must NEVER run on the client.
────────────────────────────────────────────────────────────
]]

-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- LOAD CONFIGURATION
local Config = require(script.Parent.USM_Configuration)

-- VALIDATE SERVER-SIDE
if RunService:IsRunning() and not RunService:IsServer() then
	error("[USM-Remote] CRITICAL: This script must run on the server only!")
end

-- ================================
-- STATE MANAGEMENT
-- ================================

local RemoteCallHistory = {} -- Tracks call history per player
local ProtectedRemotes = {} -- List of protected remotes
local RemoteMetadata = {} -- Metadata for each remote

-- ================================
-- UTILITY FUNCTIONS
-- ================================

local function Log(message, level)
	if not Config.Logging.Enabled then return end
	
	level = level or Config.Logging.LogLevel
	local timestamp = os.date("%Y-%m-%d %H:%M:%S")
	local logMessage = string.format("[%s] [USM-Remote-%s] %s", timestamp, level, message)
	
	if Config.LogToOutput then
		if level == "Error" then
			warn(logMessage)
		elseif level == "Warning" then
			warn(logMessage)
		else
			print(logMessage)
		end
	end
end

local function SanitizeArgument(arg)
	local argType = typeof(arg)
	
	-- Convert to string for validation
	if argType == "string" then
		return arg
	elseif argType == "number" then
		return tostring(arg)
	elseif argType == "boolean" then
		return tostring(arg)
	elseif argType == "Vector3" then
		return string.format("Vector3(%f, %f, %f)", arg.X, arg.Y, arg.Z)
	elseif argType == "CFrame" then
		return "CFrame"
	elseif argType == "Instance" then
		return arg.ClassName
	elseif argType == "table" then
		return "table"
	else
		return argType
	end
end

local function ContainsBlacklistedPattern(argument)
	if not Config.RemoteEvents.ValidateArguments then return false end
	
	local argString = SanitizeArgument(argument)
	
	for _, pattern in ipairs(Config.RemoteEvents.BlacklistedPatterns) do
		if string.find(argString:lower(), pattern:lower()) then
			return true, pattern
		end
	end
	
	return false, nil
end

local function ValidateArgumentSize(argument)
	if not Config.RemoteEvents.ValidateArguments then return true end
	
	local argString = SanitizeArgument(argument)
	return #argString <= Config.RemoteEvents.MaxArgumentSize
end

-- ================================
-- RATE LIMITING
-- ================================

local function InitializePlayerRemoteData(player)
	RemoteCallHistory[player] = {
		Calls = {}, -- Timestamp history
		TotalCalls = 0,
		Violations = 0,
		LastViolationTime = 0,
	}
end

local function CheckRateLimit(player)
	if not Config.RemoteEvents.Enabled then return true end
	
	local data = RemoteCallHistory[player]
	if not data then return true end
	
	local now = tick()
	local windowStart = now - Config.RemoteEvents.RateLimitWindow
	
	-- Clean old calls
	while #data.Calls > 0 and data.Calls[1] < windowStart do
		table.remove(data.Calls, 1)
	end
	
	-- Check if over limit
	if #data.Calls >= Config.RemoteEvents.MaxCallsPerSecond then
		data.Violations = data.Violations + 1
		data.LastViolationTime = now
		
		Log(string.format("Rate limit exceeded for %s (%d) - %d calls in %.1fs", 
			player.Name, player.UserId, #data.Calls, Config.RemoteEvents.RateLimitWindow), "Warning")
		
		return false
	end
	
	-- Add current call
	table.insert(data.Calls, now)
	data.TotalCalls = data.TotalCalls + 1
	
	return true
end

local function GetRemoteCallStats(player)
	local data = RemoteCallHistory[player]
	if not data then return nil end
	
	return {
		totalCalls = data.TotalCalls,
		violations = data.Violations,
		callsInWindow = #data.Calls,
		lastViolation = data.LastViolationTime,
	}
end

-- ================================
-- REMOTE PROTECTION
-- ================================

local function ProtectRemote(remote)
	if not remote then return false end
	
	local remoteType = remote.ClassName
	if remoteType ~= "RemoteEvent" and remoteType ~= "RemoteFunction" then
		return false
	end
	
	-- Store original methods
	local originalFireServer = remote.FireServer
	local originalInvokeServer = remote.InvokeServer
	
	-- Wrap RemoteEvent:FireServer
	if remoteType == "RemoteEvent" then
		remote.FireServer = function(...)
			local args = {...}
			local player = args[1]
			
			-- Validate player
			if typeof(player) ~= "Instance" or not player:IsA("Player") then
				Log("Invalid player argument to RemoteEvent", "Error")
				return
			end
			
			-- Check rate limit
			if not CheckRateLimit(player) then
				Log(string.format("Blocked remote call from %s due to rate limit", player.Name), "Warning")
				return
			end
			
			-- Validate arguments
			local hasBlacklist = false
			local blacklistPattern = nil
			
			for i = 2, #args do
				if not ValidateArgumentSize(args[i]) then
					Log(string.format("Argument size exceeded for %s", player.Name), "Warning")
					return
				end
				
				local found, pattern = ContainsBlacklistedPattern(args[i])
				if found then
					hasBlacklist = true
					blacklistPattern = pattern
					break
				end
			end
			
			if hasBlacklist then
				Log(string.format("Blacklisted pattern detected from %s: %s", player.Name, blacklistPattern), "Error")
				return
			end
			
			-- Call original
			return originalFireServer(remote, ...)
		end
	end
	
	-- Wrap RemoteFunction:InvokeServer
	if remoteType == "RemoteFunction" then
		remote.InvokeServer = function(...)
			local args = {...}
			local player = args[1]
			
			-- Validate player
			if typeof(player) ~= "Instance" or not player:IsA("Player") then
				Log("Invalid player argument to RemoteFunction", "Error")
				return nil
			end
			
			-- Check rate limit
			if not CheckRateLimit(player) then
				Log(string.format("Blocked remote invoke from %s due to rate limit", player.Name), "Warning")
				return nil
			end
			
			-- Validate arguments
			local hasBlacklist = false
			local blacklistPattern = nil
			
			for i = 2, #args do
				if not ValidateArgumentSize(args[i]) then
					Log(string.format("Argument size exceeded for %s", player.Name), "Warning")
					return nil
				end
				
				local found, pattern = ContainsBlacklistedPattern(args[i])
				if found then
					hasBlacklist = true
					blacklistPattern = pattern
					break
				end
			end
			
			if hasBlacklist then
				Log(string.format("Blacklisted pattern detected from %s: %s", player.Name, blacklistPattern), "Error")
				return nil
			end
			
			-- Call original
			return originalInvokeServer(remote, ...)
		end
	end
	
	-- Store metadata
	RemoteMetadata[remote] = {
		Name = remote.Name,
		Type = remoteType,
		Protected = true,
		ProtectionTime = tick(),
	}
	
	table.insert(ProtectedRemotes, remote)
	
	Log(string.format("Protected remote: %s (%s)", remote.Name, remoteType), "Info")
	
	return true
end

local function UnprotectRemote(remote)
	local metadata = RemoteMetadata[remote]
	if not metadata then return false end
	
	-- Restore original methods would require storing them
	-- For now, just mark as unprotected
	metadata.Protected = false
	
	-- Remove from protected list
	local index = table.find(ProtectedRemotes, remote)
	if index then
		table.remove(ProtectedRemotes, index)
	end
	
	Log(string.format("Unprotected remote: %s", remote.Name), "Info")
	
	return true
end

-- ================================
-- AUTOMATIC PROTECTION
-- ================================

local function AutoProtectRemotes()
	if not Config.RemoteEvents.Enabled then return end
	
	-- Protect all remotes in ReplicatedStorage
	for _, item in ipairs(ReplicatedStorage:GetDescendants()) do
		if item:IsA("RemoteEvent") or item:IsA("RemoteFunction") then
			-- Skip if already protected
			if not RemoteMetadata[item] then
				ProtectRemote(item)
			end
		end
	end
	
	-- Watch for new remotes
	ReplicatedStorage.DescendantAdded:Connect(function(item)
		if item:IsA("RemoteEvent") or item:IsA("RemoteFunction") then
			if not RemoteMetadata[item] then
				task.spawn(function()
					task.wait(0.1) -- Small delay to ensure fully loaded
					ProtectRemote(item)
				end)
			end
		end
	end)
	
	Log("Automatic remote protection enabled", "Info")
end

-- ================================
-- PLAYER EVENT HANDLERS
-- ================================

local function OnPlayerAdded(player)
	InitializePlayerRemoteData(player)
	Log(string.format("Initialized remote protection for %s (%d)", player.Name, player.UserId), "Debug")
end

local function OnPlayerRemoving(player)
	RemoteCallHistory[player] = nil
	Log(string.format("Cleaned up remote data for %s (%d)", player.Name, player.UserId), "Debug")
end

-- ================================
-- EXPORTED API
-- ================================

local RemoteProtection = {
	-- Protect a specific remote
	Protect = function(remote)
		return ProtectRemote(remote)
	end,
	
	-- Unprotect a specific remote
	Unprotect = function(remote)
		return UnprotectRemote(remote)
	end,
	
	-- Check if a remote is protected
	IsProtected = function(remote)
		local metadata = RemoteMetadata[remote]
		return metadata and metadata.Protected or false
	end,
	
	-- Get all protected remotes
	GetProtectedRemotes = function()
		return ProtectedRemotes
	end,
	
	-- Get remote metadata
	GetRemoteMetadata = function(remote)
		return RemoteMetadata[remote]
	end,
	
	-- Get player call stats
	GetPlayerStats = function(player)
		return GetRemoteCallStats(player)
	end,
	
	-- Enable automatic protection
	EnableAutoProtect = function()
		AutoProtectRemotes()
	end,
	
	-- Add custom blacklist pattern
	AddBlacklistPattern = function(pattern)
		table.insert(Config.RemoteEvents.BlacklistedPatterns, pattern)
		Log(string.format("Added blacklist pattern: %s", pattern), "Info")
	end,
	
	-- Remove blacklist pattern
	RemoveBlacklistPattern = function(pattern)
		local index = table.find(Config.RemoteEvents.BlacklistedPatterns, pattern)
		if index then
			table.remove(Config.RemoteEvents.BlacklistedPatterns, index)
			Log(string.format("Removed blacklist pattern: %s", pattern), "Info")
		end
	end,
}

-- ================================
-- INITIALIZATION
-- ================================

local function Initialize()
	if not Config.RemoteEvents.Enabled then
		warn("[USM-Remote] Remote protection is disabled in configuration")
		return
	end
	
	Log("Initializing USM Remote Protection v2026.2", "Info")
	
	-- Connect player events
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(OnPlayerAdded, player)
	end
	
	Players.PlayerAdded:Connect(OnPlayerAdded)
	Players.PlayerRemoving:Connect(OnPlayerRemoving)
	
	-- Enable automatic protection
	AutoProtectRemotes()
	
	Log("USM Remote Protection initialized successfully", "Info")
end

-- Run initialization
Initialize()

return RemoteProtection
