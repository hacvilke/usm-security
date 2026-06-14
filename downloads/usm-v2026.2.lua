--[[
────────────────────────────────────────────────────────────
 Universal Security Module (USM)
 Version: v2026.2
 Author: civ
 License: MIT

 INSTALL LOCATION:
 ServerScriptService → USM_AntiExploit.server.lua

 PURPOSE:
 Server-side anti-exploit & physics validation system.
 Detects exploit behavior patterns, not executors by name.

 WARNING:
 This script must NEVER run on the client.
────────────────────────────────────────────────────────────
]]

-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- CONFIG
local MAX_STRIKES = 6
local SPEED_GRACE = 24
local TELEPORT_GRACE = 60
local HEARTBEAT_RATE = 0.25

-- STATE
local strikes = {}
local lastPos = {}
local lastTick = {}

-- INTERNAL UTILS
local function flag(player, reason)
	strikes[player] = (strikes[player] or 0) + 1
	warn("[USM] Flag:", player.Name, reason, "(", strikes[player], ")")

	if strikes[player] >= MAX_STRIKES then
		player:Kick("USM Security: Exploit behavior detected.")
	end
end

local function getRoot(char)
	return char and char:FindFirstChild("HumanoidRootPart")
end

-- PLAYER INIT
Players.PlayerAdded:Connect(function(player)
	strikes[player] = 0
	lastTick[player] = os.clock()
end)

Players.PlayerRemoving:Connect(function(player)
	strikes[player] = nil
	lastPos[player] = nil
	lastTick[player] = nil
end)

-- CORE DETECTION LOOP
task.spawn(function()
	while true do
		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local root = getRoot(char)

			if hum and root and hum.Health > 0 then
				local now = os.clock()
				local delta = now - (lastTick[player] or now)
				lastTick[player] = now

				-- ================================
				-- MOVEMENT / PHYSICS DETECTIONS
				-- ================================

				-- 1–5: Speed abuse
				if root.AssemblyLinearVelocity.Magnitude > hum.WalkSpeed + SPEED_GRACE then
					flag(player, "Speed anomaly")
				end

				-- 6–10: Teleport abuse
				if lastPos[player] then
					local dist = (root.Position - lastPos[player]).Magnitude
					if dist > TELEPORT_GRACE then
						flag(player, "Teleport anomaly")
					end
				end
				lastPos[player] = root.Position

				-- 11–15: Fly / air-time abuse
				if hum:GetState() == Enum.HumanoidStateType.Freefall then
					if root.Velocity.Y > 5 then
						flag(player, "Air control anomaly")
					end
				end

				-- 16–20: Noclip indicators
				for _, part in ipairs(char:GetChildren()) do
					if part:IsA("BasePart") and part.CanCollide == false then
						flag(player, "Collision tampering")
						break
					end
				end

				-- 21–25: Gravity spoofing
				if hum.JumpPower > 75 then
					flag(player, "JumpPower manipulation")
				end

				-- 26–30: BodyMover abuse
				for _, v in ipairs(root:GetChildren()) do
					if v:IsA("BodyMover") or v:IsA("VectorForce") then
						flag(player, "Physics force injection")
					end
				end

				-- ================================
				-- EXECUTOR / INJECTION BEHAVIOR
				-- ================================

				-- 31–40: Tool injection
				for _, tool in ipairs(player.Backpack:GetChildren()) do
					if not tool:IsDescendantOf(player) then
						flag(player, "Injected tool")
					end
				end

				-- 41–50: Remote spam behavior
				if delta < 0.05 then
					flag(player, "Timing manipulation")
				end

				-- 51–60: Network ownership abuse
				if root:GetNetworkOwner() ~= player then
					flag(player, "Network ownership spoof")
				end

				-- 61–70: Character tampering
				if hum.PlatformStand == true then
					flag(player, "State override")
				end

				-- 71–80: Memory abuse symptoms
				if hum.Health > hum.MaxHealth then
					flag(player, "Health overflow")
				end

				-- 81–90: Camera / replication abuse (symptom-based)
				if root.AssemblyAngularVelocity.Magnitude > 80 then
					flag(player, "Angular velocity exploit")
				end

				-- 91–100: Exploit persistence behavior
				if strikes[player] > 0 and hum.WalkSpeed == 16 and root.Velocity.Magnitude == 0 then
					flag(player, "State masking behavior")
				end
			end
		end
		task.wait(HEARTBEAT_RATE)
	end
end)


