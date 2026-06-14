--[[
────────────────────────────────────────────────────────────
 Universal Security Module (USM) - Main Anti-Cheat
 Version: v2026.2
 Author: civ
 License: MIT

 INSTALL LOCATION:
 ServerScriptService → USM_Main_AntiCheat.lua

 PURPOSE:
 Advanced server-side anti-cheat with suspicion scoring,
 BanAsync integration, and behavioral analysis.
 Based on Roblox Dev Forum best practices.

 WARNING:
 This script must NEVER run on the client.
────────────────────────────────────────────────────────────
]]

-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local BanService = game:GetService("BanService")
local HTTPService = game:GetService("HttpService")

-- LOAD CONFIGURATION
local Config = require(script.Parent.USM_Configuration)

-- VALIDATE SERVER-SIDE
if RunService:IsRunning() and not RunService:IsServer() then
	error("[USM] CRITICAL: This script must run on the server only!")
end

-- ================================
-- STATE MANAGEMENT
-- ================================
local PlayerState = {} -- Per-player state
local DetectionHistory = {} -- Detection logs
local GracePeriods = {} -- Active grace periods
local WebhookCooldowns = {} -- Webhook cooldown tracking

-- ================================
-- DATA STORE
-- ================================
local LogStore = Config.Logging.UseDataStore and DataStoreService:GetDataStore(Config.Logging.DataStoreName) or nil

-- ================================
-- UTILITY FUNCTIONS
-- ================================

local function Log(message, level)
	if not Config.Logging.Enabled then return end
	
	level = level or Config.Logging.LogLevel
	local timestamp = os.date("%Y-%m-%d %H:%M:%S")
	local logMessage = string.format("[%s] [USM-%s] %s", timestamp, level, message)
	
	if Config.LogToOutput then
		if level == "Error" then
			warn(logMessage)
		elseif level == "Warning" then
			warn(logMessage)
		else
			print(logMessage)
		end
	end
	
	-- Log to DataStore if enabled
	if LogStore and level ~= "Debug" then
		task.spawn(function()
			local success, err = pcall(function()
				local key = string.format("log_%d_%s", tick(), math.random(10000, 99999))
				LogStore:SetAsync(key, {
					message = message,
					level = level,
					timestamp = timestamp,
				}, Config.Logging.RetentionDays * 86400)
			end)
			if not success then
				warn("[USM] Failed to log to DataStore:", err)
			end
		end)
	end
end

local function IsWhitelisted(player)
	if not Config.Whitelist.Enabled then return false end
	
	-- Check user ID
	if table.find(Config.Whitelist.UserIds, player.UserId) then
		return true
	end
	
	-- Check group membership
	for _, groupId in ipairs(Config.Whitelist.GroupIds) do
		if player:IsInGroup(groupId) then
			return true
		end
	end
	
	-- Check game passes (would require MarketplaceService)
	-- This is a placeholder for game pass checking
	
	return false
end

local function SetGracePeriod(player, graceType, duration)
	if not GracePeriods[player] then
		GracePeriods[player] = {}
	end
	GracePeriods[player][graceType] = tick() + duration
end

local function IsInGracePeriod(player, graceType)
	if not GracePeriods[player] then return false end
	local expiry = GracePeriods[player][graceType]
	return expiry and tick() < expiry
end

local function ClearGracePeriod(player, graceType)
	if GracePeriods[player] then
		GracePeriods[player][graceType] = nil
	end
end

-- ================================
-- WEBHOOK NOTIFICATIONS
-- ================================

local function SendWebhookNotification(player, eventType, details)
	if not Config.Webhook.Enabled then return end
	if not Config.Webhook.URL or Config.Webhook.URL == "" then return end
	
	-- Check cooldown
	local now = tick()
	local lastNotification = WebhookCooldowns[player] or 0
	if now - lastNotification < Config.Webhook.CooldownBetweenNotifications then
		return
	end
	WebhookCooldowns[player] = now
	
	-- Build webhook payload
	local payload = {
		username = "USM Security",
		avatar_url = "https://tr.rbxcdn.com/38c6edcb50633730ff4cf39ac8859840/420/420/Hat/Png",
	}
	
	-- Add embed if enabled
	if Config.Webhook.UseEmbeds then
		local color = Config.Webhook.EmbedColor
		if eventType == "Ban" then
			color = 16711680 -- Red
		elseif eventType == "Kick" then
			color = 16776960 -- Orange
		elseif eventType == "HighSuspicion" then
			color = 16744192 -- Yellow-Orange
		end
		
		local fields = {}
		
		if Config.Webhook.IncludePlayerInfo then
			table.insert(fields, {
				name = "Player",
				value = string.format("%s (ID: %d)", player.Name, player.UserId),
				inline = true
			})
		end
		
		if Config.Webhook.IncludeGameInfo then
			table.insert(fields, {
				name = "Game",
				value = game.Name,
				inline = true
			})
			table.insert(fields, {
				name = "Place ID",
				value = tostring(game.PlaceId),
				inline = true
			})
		end
		
		if Config.Webhook.IncludeDetectionDetails then
			table.insert(fields, {
				name = "Event Type",
				value = eventType,
				inline = true
			})
			table.insert(fields, {
				name = "Details",
				value = details or "No additional details",
				inline = false
			})
			
			if PlayerState[player] then
				table.insert(fields, {
					name = "Suspicion Score",
					value = tostring(PlayerState[player].SuspicionScore),
					inline = true
				})
				table.insert(fields, {
					name = "Detection Count",
					value = tostring(PlayerState[player].DetectionCount),
					inline = true
				})
			end
		end
		
		payload.embeds = {{
			title = Config.Webhook.EmbedTitle,
			color = color,
			fields = fields,
			timestamp = DateTime.now():ToIsoDate(),
		}}
	else
		-- Simple message format
		payload.content = string.format("**%s** - %s\nPlayer: %s (%d)\nDetails: %s",
			Config.Webhook.EmbedTitle,
			eventType,
			player.Name,
			player.UserId,
			details or "No additional details"
		)
	end
	
	-- Send webhook
	task.spawn(function()
		local success, err = pcall(function()
			local url = Config.Webhook.UseProxy and Config.Webhook.ProxyURL ~= "" 
				and Config.Webhook.ProxyURL .. "?url=" .. HTTPService:UrlEncode(Config.Webhook.URL)
				or Config.Webhook.URL
			
			HTTPService:PostAsync(url, HTTPService:JSONEncode(payload), Enum.HttpContentType.ApplicationJson)
		end)
		
		if success then
			Log(string.format("Webhook notification sent for %s: %s", player.Name, eventType), "Info")
		else
			Log(string.format("Failed to send webhook notification: %s", tostring(err)), "Warning")
		end
	end)
end

-- ================================
-- SUSPICION SCORING SYSTEM
-- ================================

local function InitializePlayerState(player)
	PlayerState[player] = {
		SuspicionScore = 0,
		LastPunishmentTime = 0,
		DetectionCount = 0,
		PositionHistory = {},
		VelocityHistory = {},
		LastPosition = nil,
		LastVelocity = nil,
		LastUpdateTime = tick(),
		SpawnTime = tick(),
	}
end

local function AddSuspicion(player, amount, reason)
	if not PlayerState[player] then return end
	if IsWhitelisted(player) then return end
	if IsInGracePeriod(player, "all") then return end
	
	local state = PlayerState[player]
	state.SuspicionScore = math.clamp(state.SuspicionScore + amount, 0, 100)
	state.DetectionCount = state.DetectionCount + 1
	
	-- Log detection
	Log(string.format("Player %s (%d) - Suspicion +%d (Total: %d) - Reason: %s", 
		player.Name, player.UserId, amount, state.SuspicionScore, reason), "Warning")
	
	-- Record detection history
	if not DetectionHistory[player] then
		DetectionHistory[player] = {}
	end
	table.insert(DetectionHistory[player], {
		reason = reason,
		score = state.SuspicionScore,
		timestamp = tick(),
	})
	
	-- Check thresholds
	if state.SuspicionScore >= Config.Punishment.BanThreshold then
		BanPlayer(player, reason)
	elseif state.SuspicionScore >= Config.Punishment.KickThreshold then
		KickPlayer(player, reason)
	elseif state.SuspicionScore >= Config.Webhook.HighSuspicionThreshold and Config.Webhook.NotifyOnHighSuspicion then
		SendWebhookNotification(player, "HighSuspicion", string.format("Suspicion score: %d, Reason: %s", state.SuspicionScore, reason))
	end
end

local function DecaySuspicion(player)
	if not PlayerState[player] then return end
	
	local state = PlayerState[player]
	if state.SuspicionScore > 0 then
		state.SuspicionScore = math.max(0, state.SuspicionScore - Config.Punishment.ScoreDecayRate)
	end
end

-- ================================
-- PUNISHMENT SYSTEM
-- ================================

local function KickPlayer(player, reason)
	if not PlayerState[player] then return end
	
	local state = PlayerState[player]
	local now = tick()
	
	-- Check cooldown
	if now - state.LastPunishmentTime < Config.Punishment.CooldownBetweenPunishments then
		return
	end
	
	state.LastPunishmentTime = now
	
	local kickMessage = string.format("%s\nReason: %s\nSuspicion Score: %d", 
		Config.Punishment.KickReason, reason, state.SuspicionScore)
	
	Log(string.format("Kicking player %s (%d) - Reason: %s", player.Name, player.UserId, reason), "Error")
	
	-- Send webhook notification
	if Config.Webhook.NotifyOnKick then
		SendWebhookNotification(player, "Kick", string.format("Reason: %s, Score: %d", reason, state.SuspicionScore))
	end
	
	task.spawn(function()
		player:Kick(kickMessage)
	end)
end

local function BanPlayer(player, reason)
	if not PlayerState[player] then return end
	
	local state = PlayerState[player]
	local now = tick()
	
	-- Check cooldown
	if now - state.LastPunishmentTime < Config.Punishment.CooldownBetweenPunishments then
		return
	end
	
	state.LastPunishmentTime = now
	
	Log(string.format("Banning player %s (%d) - Reason: %s", player.Name, player.UserId, reason), "Error")
	
	-- Send webhook notification
	if Config.Webhook.NotifyOnBan then
		SendWebhookNotification(player, "Ban", string.format("Reason: %s, Score: %d", reason, state.SuspicionScore))
	end
	
	if Config.Punishment.UseBanAsync then
		-- Use Roblox's BanAsync for universe-wide ban
		task.spawn(function()
			local success, err = pcall(function()
				BanService:BanAsync({
					UserId = player.UserId,
					Duration = Config.Punishment.BanDuration,
					Reason = Config.Punishment.BanReason,
					DisplayName = player.Name,
					Source = "USM Anti-Cheat",
				})
			end)
			
			if success then
				Log(string.format("Successfully banned player %s (%d) via BanAsync", player.Name, player.UserId), "Info")
				player:Kick(Config.Punishment.BanReason)
			else
				warn("[USM] BanAsync failed:", err)
				-- Fallback to kick
				player:Kick(Config.Punishment.BanReason)
			end
		end)
	else
		-- Fallback to kick
		player:Kick(Config.Punishment.BanReason)
	end
end

-- ================================
-- MOVEMENT VALIDATION
-- ================================

local function ValidateMovement(player)
	if not Config.Movement.Enabled then return end
	if not PlayerState[player] then return end
	
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	
	if not hum or not root or hum.Health <= 0 then return end
	
	local state = PlayerState[player]
	local now = tick()
	local deltaTime = now - state.LastUpdateTime
	state.LastUpdateTime = now
	
	-- Skip if in grace period
	if IsInGracePeriod(player, "spawn") or IsInGracePeriod(player, "teleport") then
		return
	end
	
	-- Speed detection
	local currentSpeed = root.AssemblyLinearVelocity.Magnitude
	local maxAllowedSpeed = hum.WalkSpeed * Config.Movement.MaxSpeedMultiplier
	
	if currentSpeed > maxAllowedSpeed and not IsInGracePeriod(player, "speed") then
		local severity = (currentSpeed - maxAllowedSpeed) / maxAllowedSpeed
		AddSuspicion(player, math.min(severity * 15, 25), "Speed anomaly")
	end
	
	-- Teleport detection
	if state.LastPosition then
		local distance = (root.Position - state.LastPosition).Magnitude
		local maxDistance = Config.Movement.MaxTeleportDistance + (currentSpeed * deltaTime)
		
		if distance > maxDistance and not IsInGracePeriod(player, "teleport") then
			local severity = distance / maxDistance
			AddSuspicion(player, math.min(severity * 20, 30), "Teleport anomaly")
		end
	end
	
	-- Fly detection (air time)
	if hum:GetState() == Enum.HumanoidStateType.Freefall then
		if not state.AirStartTime then
			state.AirStartTime = now
		else
			local airTime = now - state.AirStartTime
			if airTime > Config.Movement.MaxAirTime and not IsInGracePeriod(player, "jump") then
				local severity = airTime / Config.Movement.MaxAirTime
				AddSuspicion(player, math.min(severity * 10, 20), "Fly anomaly")
			end
		end
	else
		state.AirStartTime = nil
	end
	
	-- Jump detection
	if hum:GetState() == Enum.HumanoidStateType.Jumping then
		if not state.JumpStartTime then
			state.JumpStartTime = now
			state.JumpStartPosition = root.Position.Y
		end
	elseif state.JumpStartTime then
		local jumpHeight = root.Position.Y - state.JumpStartPosition
		local maxJumpHeight = hum.JumpPower * Config.Movement.JumpPowerMultiplier / workspace.Gravity * 2
		
		if jumpHeight > maxJumpHeight and not IsInGracePeriod(player, "jump") then
			local severity = jumpHeight / maxJumpHeight
			AddSuspicion(player, math.min(severity * 15, 25), "Jump anomaly")
		end
		
		state.JumpStartTime = nil
		state.JumpStartPosition = nil
	end
	
	-- Acceleration detection
	if state.LastVelocity then
		local acceleration = (root.AssemblyLinearVelocity - state.LastVelocity).Magnitude / deltaTime
		if acceleration > Config.Movement.MaxAcceleration then
			local severity = acceleration / Config.Movement.MaxAcceleration
			AddSuspicion(player, math.min(severity * 10, 20), "Acceleration anomaly")
		end
	end
	
	-- Update state
	state.LastPosition = root.Position
	state.LastVelocity = root.AssemblyLinearVelocity
	
	-- Track position history for pattern analysis
	table.insert(state.PositionHistory, {
		position = root.Position,
		time = now,
	})
	if #state.PositionHistory > Config.Advanced.BehaviorSampleSize then
		table.remove(state.PositionHistory, 1)
	end
end

-- ================================
-- PHYSICS VALIDATION
-- ================================

local function ValidatePhysics(player)
	if not Config.Physics.Enabled then return end
	
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	
	if not hum or not root or hum.Health <= 0 then return end
	
	-- Noclip detection via raycast
	if Config.Physics.CheckNoclip and not IsInGracePeriod(player, "teleport") then
		local rayParams = RaycastParams.new()
		rayParams.FilterDescendantsInstances = {char}
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		
		local rayResult = workspace:Raycast(root.Position, root.CFrame.LookVector * Config.Physics.NoclipRaycastDistance, rayParams)
		
		if rayResult then
			-- Check if player is moving into a wall
			local velocity = root.AssemblyLinearVelocity
			local direction = velocity.Magnitude > 0 and velocity.Unit or root.CFrame.LookVector
			local wallRay = workspace:Raycast(root.Position, direction * 2, rayParams)
			
			if wallRay and velocity.Magnitude > 10 then
				AddSuspicion(player, 10, "Noclip indicator")
			end
		end
	end
	
	-- BodyMover detection
	if Config.Physics.CheckBodyMovers then
		for _, child in ipairs(root:GetChildren()) do
			if child:IsA("BodyMover") or child:IsA("VectorForce") or child:IsA("LinearVelocity") then
				if not table.find(Config.Physics.AllowedBodyMovers, child.ClassName) then
					AddSuspicion(player, 15, "Unauthorized BodyMover detected")
				end
			end
		end
	end
	
	-- Network ownership check
	if Config.Physics.CheckNetworkOwnership then
		local owner = root:GetNetworkOwner()
		if owner ~= player then
			AddSuspicion(player, 20, "Network ownership mismatch")
		end
	end
end

-- ================================
-- CHARACTER VALIDATION
-- ================================

local function ValidateCharacter(player)
	if not Config.Character.Enabled then return end
	
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	
	if not hum or hum.Health <= 0 then return end
	
	-- Health validation
	if Config.Character.CheckHealth then
		if hum.Health > hum.MaxHealth * Config.Character.MaxHealthMultiplier then
			AddSuspicion(player, 25, "Health overflow")
		end
	end
	
	-- State validation
	if Config.Character.CheckStates then
		local currentState = hum:GetState()
		if table.find(Config.Character.InvalidStates, currentState) then
			AddSuspicion(player, 15, "Invalid humanoid state")
		end
	end
	
	-- Tool validation
	if Config.Character.CheckTools then
		local equippedCount = 0
		for _, tool in ipairs(char:GetChildren()) do
			if tool:IsA("Tool") then
				equippedCount = equippedCount + 1
			end
		end
		
		if equippedCount > Config.Character.MaxToolsEquipped then
			AddSuspicion(player, 10, "Too many tools equipped")
		end
	end
end

-- ================================
-- BEHAVIORAL ANALYSIS
-- ================================

local function AnalyzeBehavior(player)
	if not Config.Advanced.Enabled then return end
	if not Config.Advanced.TrackBehaviorPatterns then return end
	if not PlayerState[player] then return end
	
	local state = PlayerState[player]
	
	-- Analyze position history for patterns
	if #state.PositionHistory >= Config.Advanced.BehaviorSampleSize then
		local totalDistance = 0
		local totalTime = state.PositionHistory[#state.PositionHistory].time - state.PositionHistory[1].time
		
		for i = 2, #state.PositionHistory do
			totalDistance = totalDistance + (state.PositionHistory[i].position - state.PositionHistory[i-1].position).Magnitude
		end
		
		if totalTime > 0 then
			local averageSpeed = totalDistance / totalTime
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			
			if hum and averageSpeed > hum.WalkSpeed * 3 then
				AddSuspicion(player, 15, "Behavioral pattern: Sustained high speed")
			end
		end
	end
end

-- ================================
-- PLAYER EVENT HANDLERS
-- ================================

local function OnPlayerAdded(player)
	InitializePlayerState(player)
	SetGracePeriod(player, "spawn", Config.GracePeriods.AfterSpawn)
	
	Log(string.format("Player %s (%d) joined - Initializing anti-cheat", player.Name, player.UserId), "Info")
	
	player.CharacterAdded:Connect(function(char)
		InitializePlayerState(player)
		SetGracePeriod(player, "spawn", Config.GracePeriods.AfterSpawn)
		SetGracePeriod(player, "respawn", Config.GracePeriods.AfterRespawn)
		
		char:WaitForChild("Humanoid")
		char:WaitForChild("HumanoidRootPart")
		
		Log(string.format("Character loaded for %s (%d)", player.Name, player.UserId), "Debug")
	end)
end

local function OnPlayerRemoving(player)
	PlayerState[player] = nil
	DetectionHistory[player] = nil
	GracePeriods[player] = nil
	
	Log(string.format("Player %s (%d) left - Cleaning up state", player.Name, player.UserId), "Debug")
end

-- ================================
-- MAIN DETECTION LOOP
-- ================================

local function StartDetectionLoop()
	task.spawn(function()
		while true do
			for _, player in ipairs(Players:GetPlayers()) do
				if PlayerState[player] and not IsWhitelisted(player) then
					-- Run validations
					ValidateMovement(player)
					ValidatePhysics(player)
					ValidateCharacter(player)
					AnalyzeBehavior(player)
					
					-- Decay suspicion
					DecaySuspicion(player)
				end
			end
			
			task.wait(0.1) -- 10Hz detection rate
		end
	end)
end

-- ================================
-- INITIALIZATION
-- ================================

local function Initialize()
	if not Config.Enabled then
		warn("[USM] Anti-cheat is disabled in configuration")
		return
	end
	
	Log("Initializing USM Anti-Cheat v2026.2", "Info")
	
	-- Connect player events
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(OnPlayerAdded, player)
	end
	
	Players.PlayerAdded:Connect(OnPlayerAdded)
	Players.PlayerRemoving:Connect(OnPlayerRemoving)
	
	-- Start detection loop
	StartDetectionLoop()
	
	-- Initialize update checker if enabled
	if Config.UpdateChecker.Enabled then
		task.spawn(function()
			local success, UpdateChecker = pcall(function()
				return require(script.Parent.USM_UpdateChecker)
			end)
			
			if success then
				Log("USM Update Checker initialized", "Info")
			else
				Log("Failed to load Update Checker (optional module)", "Warning")
			end
		end)
	end
	
	Log("USM Anti-Cheat initialized successfully", "Info")
end

-- Run initialization
Initialize()
