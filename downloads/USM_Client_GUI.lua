--[[
────────────────────────────────────────────────────────────
 Universal Security Module (USM) - Client GUI
 Version: v2026.2
 Author: civ
 License: MIT

 INSTALL LOCATION:
 StarterPlayerScripts → USM_Client_GUI.lua

 PURPOSE:
 Client-side GUI that displays loading status and detection alerts
 in the bottom right corner. Can be disabled by developers.

 IMPORTANT:
 This is a visual indicator only. All security decisions are made server-side.
────────────────────────────────────────────────────────────
]]

-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- ================================
-- CONFIGURATION
-- ================================

local GUIConfig = {
	Enabled = true,
	ShowLoadingScreen = true,
	ShowDetectionAlerts = true,
	AlertDuration = 5, -- Seconds
	MaxAlertsVisible = 3,
	Position = UDim2.new(1, -20, 1, -20), -- Bottom right
}

-- ================================
-- STATE
-- ================================

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local ScreenGui = nil
local LoadingFrame = nil
local AlertContainer = nil
local ActiveAlerts = {}

-- ================================
-- REMOTE SETUP
-- ================================

-- Create or get remote for GUI communication
local GUIRemote = ReplicatedStorage:FindFirstChild("USM_GUI_Remote")
if not GUIRemote then
	GUIRemote = Instance.new("RemoteEvent")
	GUIRemote.Name = "USM_GUI_Remote"
	GUIRemote.Parent = ReplicatedStorage
end

-- ================================
-- GUI CREATION
-- ================================

local function CreateScreenGui()
	if ScreenGui then return ScreenGui end
	
	ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "USM_SecurityGUI"
	ScreenGui.ResetOnSpawn = false
	ScreenGui.DisplayOrder = 100
	ScreenGui.Parent = PlayerGui
	
	-- Loading Frame
	if GUIConfig.ShowLoadingScreen then
		LoadingFrame = Instance.new("Frame")
		LoadingFrame.Name = "LoadingFrame"
		LoadingFrame.Size = UDim2.new(0, 250, 0, 120)
		LoadingFrame.Position = GUIConfig.Position
		LoadingFrame.AnchorPoint = Vector2.new(1, 1)
		LoadingFrame.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
		LoadingFrame.BorderSizePixel = 0
		LoadingFrame.Parent = ScreenGui
		
		-- Corner
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = LoadingFrame
		
		-- Stroke
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(99, 102, 241)
		stroke.Thickness = 2
		stroke.Parent = LoadingFrame
		
		-- Title
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.new(1, 0, 0, 30)
		title.Position = UDim2.new(0, 0, 0, 10)
		title.BackgroundTransparency = 1
		title.Text = "USM Security Loading"
		title.TextColor3 = Color3.fromRGB(165, 180, 252)
		title.TextSize = 16
		title.Font = Enum.Font.GothamBold
		title.Parent = LoadingFrame
		
		-- Status Container
		local statusContainer = Instance.new("Frame")
		statusContainer.Name = "StatusContainer"
		statusContainer.Size = UDim2.new(1, -20, 1, -50)
		statusContainer.Position = UDim2.new(0, 10, 0, 40)
		statusContainer.BackgroundTransparency = 1
		statusContainer.Parent = LoadingFrame
		
		LoadingFrame.StatusContainer = statusContainer
	end
	
	-- Alert Container
	if GUIConfig.ShowDetectionAlerts then
		AlertContainer = Instance.new("Frame")
		AlertContainer.Name = "AlertContainer"
		AlertContainer.Size = UDim2.new(0, 300, 0, 200)
		AlertContainer.Position = GUIConfig.Position
		AlertContainer.AnchorPoint = Vector2.new(1, 1)
		AlertContainer.BackgroundTransparency = 1
		AlertContainer.Parent = ScreenGui
		
		-- Layout
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 8)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
		layout.Parent = AlertContainer
	end
	
	return ScreenGui
end

-- ================================
-- LOADING STATUS
-- ================================

local LoadingStatus = {}

local function UpdateLoadingStatus(moduleName, status)
	if not LoadingFrame or not LoadingFrame.StatusContainer then return end
	
	LoadingStatus[moduleName] = status
	
	-- Clear existing status labels
	for _, child in ipairs(LoadingFrame.StatusContainer:GetChildren()) do
		child:Destroy()
	end
	
	-- Recreate status labels
	local yOffset = 0
	for name, stat in pairs(LoadingStatus) do
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0, 20)
		label.Position = UDim2.new(0, 0, 0, yOffset)
		label.BackgroundTransparency = 1
		label.Text = string.format("• %s: %s", name, stat)
		label.TextColor3 = stat == "Loaded" and Color3.fromRGB(74, 222, 128) or 
		                   stat == "Loading" and Color3.fromRGB(251, 191, 36) or
		                   Color3.fromRGB(156, 163, 175)
		label.TextSize = 12
		label.Font = Enum.Font.Gotham
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = LoadingFrame.StatusContainer
		
		yOffset = yOffset + 22
	end
	
	-- Check if all loaded
	local allLoaded = true
	for _, stat in pairs(LoadingStatus) do
		if stat ~= "Loaded" then
			allLoaded = false
			break
		end
	end
	
	if allLoaded and #LoadingStatus > 0 then
		-- Hide loading screen after delay
		task.delay(2, function()
			if LoadingFrame then
				local tween = TweenService:Create(LoadingFrame, TweenInfo.new(0.5), {
					Position = LoadingFrame.Position + UDim2.new(0, 300, 0, 0)
				})
				tween:Play()
				tween.Completed:Connect(function()
					if LoadingFrame then
						LoadingFrame.Visible = false
					end
				end)
			end
		end)
	end
end

-- ================================
-- DETECTION ALERTS
-- ================================

local function CreateDetectionAlert(message, severity)
	if not GUIConfig.ShowDetectionAlerts or not AlertContainer then return end
	
	-- Limit number of alerts
	if #ActiveAlerts >= GUIConfig.MaxAlertsVisible then
		-- Remove oldest alert
		local oldestAlert = table.remove(ActiveAlerts, 1)
		if oldestAlert then
			oldestAlert:Destroy()
		end
	end
	
	-- Create alert frame
	local alert = Instance.new("Frame")
	alert.Name = "Alert_" .. tick()
	alert.Size = UDim2.new(0, 280, 0, 60)
	alert.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
	alert.BorderSizePixel = 0
	alert.Parent = AlertContainer
	
	-- Corner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = alert
	
	-- Stroke color based on severity
	local strokeColor = severity == "High" and Color3.fromRGB(239, 68, 68) or
	                    severity == "Medium" and Color3.fromRGB(251, 191, 36) or
	                    Color3.fromRGB(99, 102, 241)
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = strokeColor
	stroke.Thickness = 2
	stroke.Parent = alert
	
	-- Severity indicator
	local indicator = Instance.new("Frame")
	indicator.Name = "Indicator"
	indicator.Size = UDim2.new(0, 4, 1, 0)
	indicator.BackgroundColor3 = strokeColor
	indicator.BorderSizePixel = 0
	indicator.Parent = alert
	
	local indicatorCorner = Instance.new("UICorner")
	indicatorCorner.CornerRadius = UDim.new(0, 8)
	indicatorCorner.Parent = indicator
	
	-- Message
	local msgLabel = Instance.new("TextLabel")
	msgLabel.Name = "Message"
	msgLabel.Size = UDim2.new(1, -15, 1, 0)
	msgLabel.Position = UDim2.new(0, 12, 0, 0)
	msgLabel.BackgroundTransparency = 1
	msgLabel.Text = message
	msgLabel.TextColor3 = Color3.fromRGB(229, 231, 235)
	msgLabel.TextSize = 12
	msgLabel.Font = Enum.Font.Gotham
	msgLabel.TextWrapped = true
	msgLabel.TextXAlignment = Enum.TextXAlignment.Left
	msgLabel.TextYAlignment = Enum.TextYAlignment.Center
	msgLabel.Parent = alert
	
	-- Animate in
	alert.Position = UDim2.new(1, 300, 1, 0)
	local tweenIn = TweenService:Create(alert, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
		Position = UDim2.new(1, 0, 1, 0)
	})
	tweenIn:Play()
	
	-- Add to active alerts
	table.insert(ActiveAlerts, alert)
	
	-- Auto-remove after duration
	task.delay(GUIConfig.AlertDuration, function()
		if alert and alert.Parent then
			local tweenOut = TweenService:Create(alert, TweenInfo.new(0.3), {
				Position = UDim2.new(1, 300, 1, 0)
			})
			tweenOut:Play()
			tweenOut.Completed:Connect(function()
				alert:Destroy()
				local index = table.find(ActiveAlerts, alert)
				if index then
					table.remove(ActiveAlerts, index)
				end
			end)
		end
	end)
end

-- ================================
-- REMOTE EVENT HANDLERS
-- ================================

local function OnGUIEvent(action, data)
	if action == "LoadingStatus" then
		UpdateLoadingStatus(data.module, data.status)
	elseif action == "DetectionAlert" then
		CreateDetectionAlert(data.message, data.severity or "Low")
	elseif action == "DisableGUI" then
		if ScreenGui then
			ScreenGui:Destroy()
			ScreenGui = nil
		end
	end
end

-- ================================
-- INITIALIZATION
-- ================================

local function Initialize()
	-- Check if enabled
	if not GUIConfig.Enabled then
		return
	end
	
	-- Wait for PlayerGui
	PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
	
	-- Create GUI
	CreateScreenGui()
	
	-- Connect to remote
	GUIRemote.OnClientEvent:Connect(OnGUIEvent)
	
	-- Notify server that GUI is ready
	GUIRemote:FireServer("GUIReady")
	
	print("[USM-GUI] Client GUI initialized")
end

-- Run initialization
Initialize()

-- ================================
-- EXPORTED API (for developer use)
-- ================================

local USM_GUI = {
	-- Disable GUI
	Disable = function()
		GUIConfig.Enabled = false
		if ScreenGui then
			ScreenGui:Destroy()
			ScreenGui = nil
		end
	end,
	
	-- Enable GUI
	Enable = function()
		GUIConfig.Enabled = true
		Initialize()
	end,
	
	-- Show manual alert
	ShowAlert = function(message, severity)
		CreateDetectionAlert(message, severity or "Low")
	end,
	
	-- Update loading status
	UpdateStatus = function(module, status)
		UpdateLoadingStatus(module, status)
	end,
	
	-- Configuration
	SetConfig = function(key, value)
		GUIConfig[key] = value
	end,
	
	GetConfig = function(key)
		return GUIConfig[key]
	end,
}

return USM_GUI
