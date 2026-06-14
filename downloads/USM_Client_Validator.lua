--[[
────────────────────────────────────────────────────────────
 Universal Security Module (USM) - Client Validator
 Version: v2026.2
 Author: civ
 License: MIT

 INSTALL LOCATION:
 StarterPlayerScripts → USM_Client_Validator.lua

 PURPOSE:
 Client-side validation script that sends verification
 data to the server for cross-validation. This is NOT a
 client-side anti-cheat - it's a data collection system.

 IMPORTANT:
 This script runs on the client but does NOT make security
 decisions. All validation happens on the server.
────────────────────────────────────────────────────────────
]]

-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ================================
-- CONFIGURATION
-- ================================

local ClientConfig = {
	Enabled = true,
	SendInterval = 0.5, -- Seconds between data sends
	MaxHistorySize = 20,
}

-- ================================
-- STATE MANAGEMENT
-- ================================

local LocalPlayer = Players.LocalPlayer
local VerificationData = {
	PositionHistory = {},
	VelocityHistory = {},
	InputHistory = {},
	LastSendTime = 0,
	SessionStartTime = tick(),
}

-- ================================
-- REMOTE SETUP
-- ================================

-- Create remote for verification
local VerifyRemote = Instance.new("RemoteEvent")
VerifyRemote.Name = "USM_Verification"
VerifyRemote.Parent = ReplicatedStorage

-- ================================
-- DATA COLLECTION
-- ================================

local function CollectVerificationData()
	local character = LocalPlayer.Character
	if not character then return nil end
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	
	if not humanoid or not rootPart or humanoid.Health <= 0 then return nil end
	
	local data = {
		timestamp = tick(),
		position = rootPart.Position,
		velocity = rootPart.AssemblyLinearVelocity,
		angularVelocity = rootPart.AssemblyAngularVelocity,
		walkSpeed = humanoid.WalkSpeed,
		jumpPower = humanoid.JumpPower,
		health = humanoid.Health,
		maxHealth = humanoid.MaxHealth,
		state = humanoid:GetState(),
		isOnFloor = humanoid.FloorMaterial ~= Enum.Material.Air,
		cameraCFrame = workspace.CurrentCamera.CFrame,
	}
	
	return data
end

local function CollectInputData()
	local data = {
		timestamp = tick(),
		keyboardEnabled = UserInputService.KeyboardEnabled,
		mouseEnabled = UserInputService.MouseEnabled,
		gamepadEnabled = UserInputService.GamepadEnabled,
		touchEnabled = UserInputService.TouchEnabled,
	}
	
	return data
end

-- ================================
-- DATA SENDING
-- ================================

local function SendVerificationData()
	local now = tick()
	
	-- Rate limit
	if now - VerificationData.LastSendTime < ClientConfig.SendInterval then
		return
	end
	
	VerificationData.LastSendTime = now
	
	local charData = CollectVerificationData()
	local inputData = CollectInputData()
	
	if charData then
		-- Store in history
		table.insert(VerificationData.PositionHistory, charData.position)
		table.insert(VerificationData.VelocityHistory, charData.velocity)
		
		-- Limit history size
		if #VerificationData.PositionHistory > ClientConfig.MaxHistorySize then
			table.remove(VerificationData.PositionHistory, 1)
		end
		if #VerificationData.VelocityHistory > ClientConfig.MaxHistorySize then
			table.remove(VerificationData.VelocityHistory, 1)
		end
		
		-- Send to server
		local payload = {
			character = charData,
			input = inputData,
			sessionDuration = now - VerificationData.SessionStartTime,
		}
		
		pcall(function()
			VerifyRemote:FireServer(payload)
		end)
	end
end

-- ================================
-- HEARTBEAT LOOP
-- ================================

local function StartVerificationLoop()
	if not ClientConfig.Enabled then return end
	
	RunService.Heartbeat:Connect(function()
		SendVerificationData()
	end)
end

-- ================================
-- INITIALIZATION
-- ================================

local function Initialize()
	-- Wait for remote to be ready
	if not VerifyRemote then
		warn("[USM-Client] Failed to create verification remote")
		return
	end
	
	print("[USM-Client] Client validator initialized")
	
	-- Start verification loop
	StartVerificationLoop()
end

-- Run initialization
Initialize()
