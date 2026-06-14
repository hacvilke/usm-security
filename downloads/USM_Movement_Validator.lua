--[[
────────────────────────────────────────────────────────────
 Universal Security Module (USM) - Movement Validator
 Version: v2026.2
 Author: civ
 License: MIT

 INSTALL LOCATION:
 ServerScriptService → USM_Movement_Validator.lua

 PURPOSE:
 Specialized movement validation module with advanced
 physics analysis and trajectory prediction.

 WARNING:
 This script must NEVER run on the client.
────────────────────────────────────────────────────────────
]]

-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- LOAD CONFIGURATION
local Config = require(script.Parent.USM_Configuration)

-- VALIDATE SERVER-SIDE
if RunService:IsRunning() and not RunService:IsServer() then
	error("[USM-Movement] CRITICAL: This script must run on the server only!")
end

-- ================================
-- STATE MANAGEMENT
-- ================================

local PlayerMovementData = {}

-- ================================
-- MOVEMENT ANALYSIS
-- ================================

local function InitializeMovementData(player)
	PlayerMovementData[player] = {
		PositionHistory = {},
		VelocityHistory = {},
		AccelerationHistory = {},
		LastGroundedTime = 0,
		LastJumpTime = 0,
		LastTeleportTime = 0,
		TrajectoryPredictions = {},
		AnomalyCount = 0,
	}
end

local function GetHumanoidRootPart(character)
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function GetHumanoid(character)
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- ================================
-- TRAJECTORY PREDICTION
-- ================================

local function PredictTrajectory(rootPart, deltaTime)
	local velocity = rootPart.AssemblyLinearVelocity
	local position = rootPart.Position
	local gravity = Workspace.Gravity
	
	-- Simple projectile motion prediction
	local predictedPosition = position + (velocity * deltaTime)
	predictedPosition = predictedPosition + Vector3.new(0, -0.5 * gravity * deltaTime * deltaTime, 0)
	
	return predictedPosition
end

local function ValidateTrajectory(player, rootPart)
	local data = PlayerMovementData[player]
	if not data then return end
	
	local deltaTime = 0.1
	local predictedPos = PredictTrajectory(rootPart, deltaTime)
	local actualPos = rootPart.Position
	
	-- Check if actual position matches prediction
	local deviation = (actualPos - predictedPos).Magnitude
	
	-- Allow some tolerance for network latency
	local tolerance = 5 + (rootPart.AssemblyLinearVelocity.Magnitude * deltaTime)
	
	if deviation > tolerance then
		return false, deviation, tolerance
	end
	
	return true, deviation, tolerance
end

-- ================================
-- ACCELERATION ANALYSIS
-- ================================

local function CalculateAcceleration(player, rootPart)
	local data = PlayerMovementData[player]
	if not data then return 0 end
	
	local currentVelocity = rootPart.AssemblyLinearVelocity
	local currentTime = tick()
	
	if #data.VelocityHistory > 0 then
		local lastEntry = data.VelocityHistory[#data.VelocityHistory]
		local deltaTime = currentTime - lastEntry.time
		
		if deltaTime > 0 then
			local acceleration = (currentVelocity - lastEntry.velocity).Magnitude / deltaTime
			return acceleration, deltaTime
		end
	end
	
	return 0, 0
end

local function ValidateAcceleration(player, rootPart)
	local acceleration, deltaTime = CalculateAcceleration(player, rootPart)
	
	if acceleration > Config.Movement.MaxAcceleration then
		return false, acceleration
	end
	
	return true, acceleration
end

-- ================================
-- GROUND DETECTION
-- ================================

local function IsGrounded(rootPart)
	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = {rootPart.Parent}
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	
	local rayResult = Workspace:Raycast(
		rootPart.Position,
		Vector3.new(0, -5, 0),
		rayParams
	)
	
	return rayResult ~= nil
end

local function ValidateGroundedState(player, rootPart, humanoid)
	local data = PlayerMovementData[player]
	if not data then return end
	
	local grounded = IsGrounded(rootPart)
	local state = humanoid:GetState()
	
	-- Check for flying without legitimate reason
	if not grounded and state == Enum.HumanoidStateType.Freefall then
		local airTime = tick() - data.LastGroundedTime
		
		if airTime > Config.Movement.MaxAirTime then
			return false, airTime
		end
	elseif grounded then
		data.LastGroundedTime = tick()
	end
	
	return true, 0
end

-- ================================
-- SPEED VALIDATION
-- ================================

local function ValidateSpeed(player, rootPart, humanoid)
	local currentSpeed = rootPart.AssemblyLinearVelocity.Magnitude
	local maxSpeed = humanoid.WalkSpeed * Config.Movement.MaxSpeedMultiplier
	
	-- Check for speed anomaly
	if currentSpeed > maxSpeed then
		return false, currentSpeed, maxSpeed
	end
	
	return true, currentSpeed, maxSpeed
end

-- ================================
-- TELEPORTATION DETECTION
-- ================================

local function ValidateTeleportation(player, rootPart)
	local data = PlayerMovementData[player]
	if not data then return end
	
	if #data.PositionHistory > 0 then
		local lastEntry = data.PositionHistory[#data.PositionHistory]
		local distance = (rootPart.Position - lastEntry.position).Magnitude
		local deltaTime = tick() - lastEntry.time
		
		-- Calculate maximum possible distance given speed
		local maxDistance = Config.Movement.MaxTeleportDistance + (rootPart.AssemblyLinearVelocity.Magnitude * deltaTime)
		
		if distance > maxDistance then
			return false, distance, maxDistance
		end
	end
	
	return true, 0, 0
end

-- ================================
-- JUMP VALIDATION
-- ================================

local function ValidateJump(player, rootPart, humanoid)
	local data = PlayerMovementData[player]
	if not data then return end
	
	local state = humanoid:GetState()
	
	if state == Enum.HumanoidStateType.Jumping then
		if not data.JumpStartPosition then
			data.JumpStartPosition = rootPart.Position.Y
			data.JumpStartTime = tick()
		end
	elseif data.JumpStartPosition then
		-- Calculate jump height
		local jumpHeight = rootPart.Position.Y - data.JumpStartPosition
		local maxJumpHeight = (humanoid.JumpPower ^ 2) / (2 * Workspace.Gravity)
		
		if jumpHeight > maxJumpHeight * Config.Movement.JumpPowerMultiplier then
			return false, jumpHeight, maxJumpHeight
		end
		
		data.JumpStartPosition = nil
		data.JumpStartTime = nil
	end
	
	return true, 0, 0
end

-- ================================
-- PATTERN RECOGNITION
-- ================================

local function AnalyzeMovementPatterns(player)
	local data = PlayerMovementData[player]
	if not data then return end
	
	if #data.PositionHistory < 10 then return end
	
	-- Check for repetitive movement patterns (bot-like behavior)
	local positions = {}
	for i = #data.PositionHistory - 9, #data.PositionHistory do
		table.insert(positions, data.PositionHistory[i].position)
	end
	
	-- Calculate variance in movement
	local totalDistance = 0
	for i = 2, #positions do
		totalDistance = totalDistance + (positions[i] - positions[i-1]).Magnitude
	end
	
	local avgDistance = totalDistance / (#positions - 1)
	
	-- Check for suspiciously consistent movement
	local variance = 0
	for i = 2, #positions do
		local dist = (positions[i] - positions[i-1]).Magnitude
		variance = variance + math.abs(dist - avgDistance)
	end
	
	variance = variance / (#positions - 1)
	
	-- Low variance could indicate automated movement
	if variance < 0.1 and avgDistance > 5 then
		return false, "Consistent movement pattern detected"
	end
	
	return true, "Normal movement"
end

-- ================================
-- MAIN VALIDATION FUNCTION
-- ================================

local function ValidatePlayerMovement(player)
	local character = player.Character
	if not character then return end
	
	local humanoid = GetHumanoid(character)
	local rootPart = GetHumanoidRootPart(character)
	
	if not humanoid or not rootPart or humanoid.Health <= 0 then return end
	
	local data = PlayerMovementData[player]
	if not data then return end
	
	local anomalies = {}
	
	-- Speed validation
	local speedValid, currentSpeed, maxSpeed = ValidateSpeed(player, rootPart, humanoid)
	if not speedValid then
		table.insert(anomalies, {
			type = "Speed",
			value = currentSpeed,
			expected = maxSpeed,
			severity = (currentSpeed - maxSpeed) / maxSpeed
		})
	end
	
	-- Teleportation validation
	local teleportValid, distance, maxDistance = ValidateTeleportation(player, rootPart)
	if not teleportValid then
		table.insert(anomalies, {
			type = "Teleport",
			value = distance,
			expected = maxDistance,
			severity = distance / maxDistance
		})
	end
	
	-- Grounded state validation
	local groundedValid, airTime = ValidateGroundedState(player, rootPart, humanoid)
	if not groundedValid then
		table.insert(anomalies, {
			type = "Fly",
			value = airTime,
			expected = Config.Movement.MaxAirTime,
			severity = airTime / Config.Movement.MaxAirTime
		})
	end
	
	-- Jump validation
	local jumpValid, jumpHeight, maxJumpHeight = ValidateJump(player, rootPart, humanoid)
	if not jumpValid then
		table.insert(anomalies, {
			type = "Jump",
			value = jumpHeight,
			expected = maxJumpHeight,
			severity = jumpHeight / maxJumpHeight
		})
	end
	
	-- Acceleration validation
	local accelValid, acceleration = ValidateAcceleration(player, rootPart)
	if not accelValid then
		table.insert(anomalies, {
			type = "Acceleration",
			value = acceleration,
			expected = Config.Movement.MaxAcceleration,
			severity = acceleration / Config.Movement.MaxAcceleration
		})
	end
	
	-- Trajectory validation
	local trajectoryValid, deviation, tolerance = ValidateTrajectory(player, rootPart)
	if not trajectoryValid then
		table.insert(anomalies, {
			type = "Trajectory",
			value = deviation,
			expected = tolerance,
			severity = deviation / tolerance
		})
	end
	
	-- Pattern analysis
	local patternValid, patternMessage = AnalyzeMovementPatterns(player)
	if not patternValid then
		table.insert(anomalies, {
			type = "Pattern",
			value = patternMessage,
			expected = "Normal movement",
			severity = 0.5
		})
	end
	
	-- Update history
	table.insert(data.PositionHistory, {
		position = rootPart.Position,
		time = tick()
	})
	table.insert(data.VelocityHistory, {
		velocity = rootPart.AssemblyLinearVelocity,
		time = tick()
	})
	
	-- Limit history size
	if #data.PositionHistory > 50 then
		table.remove(data.PositionHistory, 1)
	end
	if #data.VelocityHistory > 50 then
		table.remove(data.VelocityHistory, 1)
	end
	
	return anomalies
end

-- ================================
-- EXPORTED API
-- ================================

local MovementValidator = {
	Initialize = function(player)
		InitializeMovementData(player)
	end,
	
	Cleanup = function(player)
		PlayerMovementData[player] = nil
	end,
	
	Validate = function(player)
		return ValidatePlayerMovement(player)
	end,
	
	GetMovementData = function(player)
		return PlayerMovementData[player]
	end,
	
	IsGrounded = function(character)
		local rootPart = GetHumanoidRootPart(character)
		return rootPart and IsGrounded(rootPart) or false
	end,
	
	PredictTrajectory = function(rootPart, deltaTime)
		return PredictTrajectory(rootPart, deltaTime or 0.1)
	end,
}

return MovementValidator
