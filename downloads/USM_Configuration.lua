--[[
────────────────────────────────────────────────────────────
 Universal Security Module (USM) - Configuration
 Version: v2026.2
 Author: civ
 License: MIT

 INSTALL LOCATION:
 ServerScriptService → USM_Configuration.lua

 PURPOSE:
 Centralized configuration for all USM anti-cheat modules.
 Customize thresholds and behaviors for your game.
────────────────────────────────────────────────────────────
]]

return {
	-- ================================
	-- GENERAL SETTINGS
	-- ================================
	Enabled = true,
	DebugMode = false,
	LogToOutput = true,
	
	-- ================================
	-- PUNISHMENT SYSTEM
	-- ================================
	Punishment = {
		-- Suspicion score thresholds (0-100)
		KickThreshold = 80,
		BanThreshold = 95,
		
		-- Score decay (points lost per second)
		ScoreDecayRate = 0.5,
		
		-- Minimum time between punishments (seconds)
		CooldownBetweenPunishments = 30,
		
		-- Ban settings
		UseBanAsync = true, -- Use Roblox's universe-wide ban system
		BanDuration = 604800, -- 7 days in seconds (nil = permanent)
		BanReason = "USM Security: Exploit behavior detected",
		
		-- Kick message
		KickReason = "USM Security: Suspicious activity detected",
	},
	
	-- ================================
	-- MOVEMENT VALIDATION
	-- ================================
	Movement = {
		Enabled = true,
		
		-- Speed detection
		MaxSpeedMultiplier = 2.5, -- Multiplier of WalkSpeed
		SpeedGracePeriod = 0.5, -- Seconds after spawn before checking
		
		-- Teleport detection
		MaxTeleportDistance = 50, -- Studs
		TeleportGracePeriod = 2.0, -- Seconds after teleport/respawn
		
		-- Fly detection
		MaxAirTime = 3.0, -- Maximum seconds in air without jumping
		FlyGracePeriod = 1.0, -- Seconds after jump before checking
		
		-- Jump detection
		MaxJumpHeight = 50, -- Studs
		JumpPowerMultiplier = 2.0, -- Multiplier of JumpPower
		
		-- Acceleration detection
		MaxAcceleration = 100, -- Studs/second²
		AccelerationSampleRate = 0.1, -- Seconds between samples
	},
	
	-- ================================
	-- PHYSICS VALIDATION
	-- ================================
	Physics = {
		Enabled = true,
		
		-- Noclip detection
		CheckNoclip = true,
		NoclipRaycastDistance = 5, -- Studs
		NoclipIgnoreGracePeriod = 0.5, -- Seconds after teleport
		
		-- Gravity manipulation
		CheckGravity = true,
		MinGravity = 0, -- Workspace.Gravity minimum
		MaxGravity = 200, -- Workspace.Gravity maximum
		
		-- BodyMover detection
		CheckBodyMovers = true,
		AllowedBodyMovers = {}, -- Class names to allow (empty = none allowed)
		
		-- Network ownership
		CheckNetworkOwnership = true,
	},
	
	-- ================================
	-- REMOTE EVENT PROTECTION
	-- ================================
	RemoteEvents = {
		Enabled = true,
		
		-- Rate limiting
		MaxCallsPerSecond = 20,
		RateLimitWindow = 1.0, -- Seconds
		
		-- Argument validation
		ValidateArguments = true,
		MaxArgumentSize = 1000, -- Characters per argument
		
		-- Blacklisted functions/strings
		BlacklistedPatterns = {
			"require",
			"getfenv",
			"setfenv",
			"loadstring",
			"game:GetService('HttpService')",
		},
	},
	
	-- ================================
	-- CHARACTER VALIDATION
	-- ================================
	Character = {
		Enabled = true,
		
		-- Health validation
		CheckHealth = true,
		MaxHealthMultiplier = 1.5, -- Multiplier of MaxHealth
		
		-- State validation
		CheckStates = true,
		InvalidStates = {
			Enum.HumanoidStateType.FallingDown,
		},
		
		-- Tool validation
		CheckTools = true,
		MaxToolsEquipped = 2,
		
		-- Animation validation
		CheckAnimations = true,
		MaxAnimationSpeed = 2.0,
	},
	
	-- ================================
	-- WHITELIST SYSTEM
	-- ================================
	Whitelist = {
		Enabled = false,
		
		-- Whitelisted user IDs
		UserIds = {},
		
		-- Whitelisted group IDs (members won't be checked)
		GroupIds = {},
		
		-- Whitelisted game passes (owners won't be checked)
		GamePassIds = {},
	},
	
	-- ================================
	-- GRACE PERIODS
	-- ================================
	GracePeriods = {
		AfterSpawn = 3.0, -- Seconds after character loads
		AfterTeleport = 2.0, -- Seconds after scripted teleport
		AfterRespawn = 2.0, -- Seconds after respawning
		AfterMapChange = 5.0, -- Seconds after map change
	},
	
	-- ================================
	-- ADVANCED DETECTION
	-- ================================
	Advanced = {
		Enabled = true,
		
		-- Behavioral analysis
		TrackBehaviorPatterns = true,
		BehaviorSampleSize = 10, -- Number of samples to analyze
		
		-- Statistical analysis
		UseStatisticalOutlierDetection = true,
		OutlierThreshold = 2.0, -- Standard deviations
		
		-- Machine learning (simple heuristic-based)
		UseHeuristicScoring = true,
	},
	
	-- ================================
	-- LOGGING
	-- ================================
	Logging = {
		Enabled = true,
		
		-- Log to DataStore
		UseDataStore = true,
		DataStoreName = "USM_Logs",
		
		-- Log retention (days)
		RetentionDays = 30,
		
		-- Log level
		LogLevel = "Warning", -- Debug, Info, Warning, Error
	},
	
	-- ================================
	-- WEBHOOK NOTIFICATIONS
	-- ================================
	Webhook = {
		Enabled = false,
		
		-- Discord webhook URL (use a proxy service for security)
		URL = "", -- Your webhook URL here
		
		-- Webhook proxy service (recommended for security)
		UseProxy = true,
		ProxyURL = "", -- Your proxy service URL
		
		-- Notification settings
		NotifyOnKick = true,
		NotifyOnBan = true,
		NotifyOnHighSuspicion = true,
		HighSuspicionThreshold = 70,
		
		-- Rate limiting (prevent spam)
		CooldownBetweenNotifications = 60, -- Seconds
		
		-- Embed settings
		UseEmbeds = true,
		EmbedColor = 9910230, -- Discord color (decimal)
		EmbedTitle = "USM Security Alert",
		
		-- Include player info
		IncludePlayerInfo = true,
		IncludeGameInfo = true,
		IncludeDetectionDetails = true,
	},
	
	-- ================================
	-- UPDATE CHECKING
	-- ================================
	UpdateChecker = {
		Enabled = true,
		CheckInterval = 3600, -- Check every hour (in seconds)
		VersionURL = "https://raw.githubusercontent.com/hacvilke/usm-security/main/version.json",
		CurrentVersion = "2026.2.0",
		NotifyOnUpdate = true,
		AutoNotifyAdmins = true,
	},
}
