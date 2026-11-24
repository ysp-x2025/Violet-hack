--!strict
--[[
    ROBLOX ULTIMATE ALL-IN-ONE TOOLKIT — SERVER AUTHORITY & PERSISTENCE
    File: ToolkitServer.server.lua
    Location: ServerScriptService/ToolkitServer (Script)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Lighting = game:GetService("Lighting")

local ADMIN_USER_IDS: { [number]: number } = {
	[game.CreatorId] = 3,
}

local RATE_LIMIT_WINDOW = 5
local MAX_REQUESTS_PER_WINDOW = 15
local DATASTORE_NAME = "UltimateToolkit_Settings_v1"

local SettingsStore = nil
pcall(function()
	SettingsStore = DataStoreService:GetDataStore(DATASTORE_NAME)
end)

local RemoteFolder = ReplicatedStorage:FindFirstChild("UltimateToolkitRemotes")
if not RemoteFolder then
	RemoteFolder = Instance.new("Folder")
	RemoteFolder.Name = "UltimateToolkitRemotes"
	RemoteFolder.Parent = ReplicatedStorage
end

local function getOrCreateRemote(name: string, className: string): Instance
	local existing = RemoteFolder:FindFirstChild(name)
	if existing and existing:IsA(className) then
		return existing
	end
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = RemoteFolder
	return remote
end

local AdminActionRemote = getOrCreateRemote("AdminAction", "RemoteEvent") :: RemoteEvent
local AdminSyncRemote = getOrCreateRemote("AdminSync", "RemoteEvent") :: RemoteEvent
local DiagnosticsRemote = getOrCreateRemote("GetDiagnostics", "RemoteFunction") :: RemoteFunction
local SettingsRemote = getOrCreateRemote("ManageSettings", "RemoteFunction") :: RemoteFunction
local AnnouncementRemote = getOrCreateRemote("ServerAnnouncement", "RemoteEvent") :: RemoteEvent

local ActionLogs: { { Timestamp: string, Admin: string, Action: string, Target: string, Details: string } } = {}
local RateLimitTracker: { [number]: { Count: number, ResetTime: number } } = {}
local FrozenPlayers: { [number]: { WalkSpeed: number, JumpPower: number } } = {}

local function getPermissionLevel(player: Player): number
	if game:GetService("RunService"):IsStudio() then
		return 3
	end
	return ADMIN_USER_IDS[player.UserId] or 0
end

local function checkRateLimit(player: Player): boolean
	local now = os.clock()
	local record = RateLimitTracker[player.UserId]
	if not record or now > record.ResetTime then
		RateLimitTracker[player.UserId] = { Count = 1, ResetTime = now + RATE_LIMIT_WINDOW }
		return true
	end
	if record.Count >= MAX_REQUESTS_PER_WINDOW then
		return false
	end
	record.Count += 1
	return true
end

local function logAdminAction(admin: Player, action: string, targetName: string, details: string)
	local entry = {
		Timestamp = os.date("!%Y-%m-%d %H:%M:%S UTC"),
		Admin = string.format("%s (%d)", admin.Name, admin.UserId),
		Action = action,
		Target = targetName,
		Details = details,
	}
	table.insert(ActionLogs, 1, entry)
	if #ActionLogs > 100 then
		table.remove(ActionLogs)
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		if getPermissionLevel(plr) >= 1 then
			AdminSyncRemote:FireClient(plr, "LogsUpdated", ActionLogs)
		end
	end
end

local function findPlayerByUserId(userId: unknown): Player?
	if typeof(userId) ~= "number" then
		return nil
	end
	return Players:GetPlayerByUserId(userId)
end

local CommandHandlers: { [string]: { MinLevel: number, Execute: (admin: Player, payload: any) -> (boolean, string) } } = {
	Kick = {
		MinLevel = 1,
		Execute = function(admin, payload)
			local target = findPlayerByUserId(payload.TargetId)
			if not target then return false, "Target player not found." end
			if getPermissionLevel(target) >= getPermissionLevel(admin) and target ~= admin then
				return false, "Cannot kick a peer or higher-ranked admin."
			end
			local reason = typeof(payload.Reason) == "string" and string.sub(payload.Reason, 1, 120) or "Removed by administrator."
			logAdminAction(admin, "Kick", target.Name, reason)
			target:Kick("[Toolkit Admin] " .. reason)
			return true, "Kicked " .. target.Name
		end,
	},
	Respawn = {
		MinLevel = 1,
		Execute = function(admin, payload)
			local target = findPlayerByUserId(payload.TargetId)
			if not target then return false, "Target player not found." end
			target:LoadCharacter()
			logAdminAction(admin, "Respawn", target.Name, "Forced character reload")
			return true, "Respawned " .. target.Name
		end,
	},
	Heal = {
		MinLevel = 1,
		Execute = function(admin, payload)
			local target = findPlayerByUserId(payload.TargetId)
			local humanoid = target and target.Character and target.Character:FindFirstChildOfClass("Humanoid")
			if not humanoid then return false, "Target humanoid unavailable." end
			humanoid.Health = humanoid.MaxHealth
			logAdminAction(admin, "Heal", target.Name, "Restored full health")
			return true, "Healed " .. target.Name
		end,
	},
	Freeze = {
		MinLevel = 1,
		Execute = function(admin, payload)
			local target = findPlayerByUserId(payload.TargetId)
			local humanoid = target and target.Character and target.Character:FindFirstChildOfClass("Humanoid")
			local root = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not humanoid or not root then return false, "Target character unavailable." end
			if not FrozenPlayers[target.UserId] then
				FrozenPlayers[target.UserId] = { WalkSpeed = humanoid.WalkSpeed, JumpPower = humanoid.JumpPower }
			end
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
			root.Anchored = true
			logAdminAction(admin, "Freeze", target.Name, "Froze movement")
			return true, "Froze " .. target.Name
		end,
	},
	Unfreeze = {
		MinLevel = 1,
		Execute = function(admin, payload)
			local target = findPlayerByUserId(payload.TargetId)
			local humanoid = target and target.Character and target.Character:FindFirstChildOfClass("Humanoid")
			local root = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not humanoid or not root then return false, "Target character unavailable." end
			local saved = FrozenPlayers[target.UserId]
			humanoid.WalkSpeed = saved and saved.WalkSpeed or 16
			humanoid.JumpPower = saved and saved.JumpPower or 50
			root.Anchored = false
			FrozenPlayers[target.UserId] = nil
			logAdminAction(admin, "Unfreeze", target.Name, "Restored movement")
			return true, "Unfroze " .. target.Name
		end,
	},
	TeleportTo = {
		MinLevel = 1,
		Execute = function(admin, payload)
			local target = findPlayerByUserId(payload.TargetId)
			local adminRoot = admin.Character and admin.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local targetRoot = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not adminRoot or not targetRoot then return false, "Character root missing." end
			adminRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 3)
			logAdminAction(admin, "TeleportTo", target.Name, "Admin teleported to target")
			return true, "Teleported to " .. target.Name
		end,
	},
	Bring = {
		MinLevel = 1,
		Execute = function(admin, payload)
			local target = findPlayerByUserId(payload.TargetId)
			local adminRoot = admin.Character and admin.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local targetRoot = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not adminRoot or not targetRoot then return false, "Character root missing." end
			targetRoot.CFrame = adminRoot.CFrame * CFrame.new(0, 0, -3)
			logAdminAction(admin, "Bring", target.Name, "Brought target to admin")
			return true, "Brought " .. target.Name
		end,
	},
	Announce = {
		MinLevel = 1,
		Execute = function(admin, payload)
			if typeof(payload.Message) ~= "string" or #payload.Message == 0 then
				return false, "Invalid message."
			end
			local cleanMsg = string.sub(payload.Message, 1, 200)
			AnnouncementRemote:FireAllClients(admin.Name, cleanMsg)
			logAdminAction(admin, "Announce", "All Players", cleanMsg)
			return true, "Announcement broadcast."
		end,
	},
	SetClockTime = {
		MinLevel = 2,
		Execute = function(admin, payload)
			if typeof(payload.ClockTime) ~= "number" then return false, "Invalid ClockTime." end
			local clamped = math.clamp(payload.ClockTime, 0, 24)
			Lighting.ClockTime = clamped
			logAdminAction(admin, "SetClockTime", "Lighting", tostring(clamped))
			return true, string.format("ClockTime set to %.1f", clamped)
		end,
	},
	SetWeather = {
		MinLevel = 2,
		Execute = function(admin, payload)
			local preset = payload.Preset
			if typeof(preset) ~= "string" then return false, "Invalid weather preset." end
			if preset == "Clear" then
				Lighting.FogEnd = 100000
				Lighting.Brightness = 2
			elseif preset == "Foggy" then
				Lighting.FogStart = 20
				Lighting.FogEnd = 250
				Lighting.Brightness = 1
			elseif preset == "Midnight" then
				Lighting.ClockTime = 0
				Lighting.FogEnd = 800
				Lighting.Brightness = 0.5
			else
				return false, "Unknown weather preset."
			end
			logAdminAction(admin, "SetWeather", "Environment", preset)
			return true, "Weather updated: " .. preset
		end,
	},
	GiveTestTool = {
		MinLevel = 2,
		Execute = function(admin, payload)
			local target = findPlayerByUserId(payload.TargetId)
			local backpack = target and target:FindFirstChildOfClass("Backpack")
			if not target or not backpack then return false, "Target backpack unavailable." end
			local toolName = typeof(payload.ToolName) == "string" and string.sub(payload.ToolName, 1, 40) or "DebugTool"
			local tool = Instance.new("Tool")
			tool.Name = toolName
			tool.RequiresHandle = false
			tool.ToolTip = "Authorized Test Item"
			tool.Parent = backpack
			logAdminAction(admin, "GiveTestTool", target.Name, toolName)
			return true, string.format("Gave %s to %s", toolName, target.Name)
		end,
	},
	RequestSync = {
		MinLevel = 1,
		Execute = function(admin, _)
			local adminList = {}
			for uid, lvl in pairs(ADMIN_USER_IDS) do
				table.insert(adminList, { UserId = uid, Level = lvl })
			end
			AdminSyncRemote:FireClient(admin, "FullSync", {
				PermissionLevel = getPermissionLevel(admin),
				Logs = ActionLogs,
				Admins = adminList,
			})
			return true, "Synced"
		end,
	},
}

AdminActionRemote.OnServerEvent:Connect(function(player: Player, actionName: unknown, payload: unknown)
	local level = getPermissionLevel(player)
	if level <= 0 then
		warn(string.format("[ToolkitSecurity] Unauthorized admin attempt by %s (%d)", player.Name, player.UserId))
		return
	end
	if not checkRateLimit(player) then
		AdminSyncRemote:FireClient(player, "Feedback", false, "Rate limit exceeded. Wait a few seconds.")
		return
	end
	if typeof(actionName) ~= "string" then
		return
	end
	local handler = CommandHandlers[actionName]
	if not handler then
		AdminSyncRemote:FireClient(player, "Feedback", false, "Unknown command.")
		return
	end
	if level < handler.MinLevel then
		AdminSyncRemote:FireClient(player, "Feedback", false, "Insufficient permission rank.")
		return
	end
	local safePayload = typeof(payload) == "table" and payload or {}
	local success, msg = handler.Execute(player, safePayload)
	if actionName ~= "RequestSync" then
		AdminSyncRemote:FireClient(player, "Feedback", success, msg)
	end
end)

DiagnosticsRemote.OnServerInvoke = function(player: Player)
	if getPermissionLevel(player) <= 0 then
		return { Authorized = false }
	end
	local Stats = game:GetService("Stats")
	return {
		Authorized = true,
		PlayerCount = #Players:GetPlayers(),
		MaxPlayers = Players.MaxPlayers,
		InstanceCount = #workspace:GetDescendants(),
		ServerMemoryMB = math.floor(Stats:GetTotalMemoryUsageMb() * 10) / 10,
		HeartbeatRate = math.floor(1 / math.max(game:GetService("RunService").Heartbeat:Wait(), 0.001)),
		UptimeSeconds = math.floor(workspace.DistributedGameTime),
	}
end

SettingsRemote.OnServerInvoke = function(player: Player, operation: unknown, serializedData: unknown)
	if not SettingsStore then
		return false, "DataStore unavailable (Enable Studio Access to API Services)."
	end
	local key = "User_" .. tostring(player.UserId)
	if operation == "Save" then
		if typeof(serializedData) ~= "string" or #serializedData > 32000 then
			return false, "Invalid or oversized configuration payload."
		end
		local ok, err = pcall(function()
			SettingsStore:SetAsync(key, serializedData)
		end)
		return ok, ok and "Saved to DataStore." or tostring(err)
	elseif operation == "Load" then
		local ok, result = pcall(function()
			return SettingsStore:GetAsync(key)
		end)
		if ok and typeof(result) == "string" then
			return true, result
		end
		return false, "No saved DataStore profile found."
	end
	return false, "Invalid operation."
end

Players.PlayerAdded:Connect(function(player)
	task.defer(function()
		local lvl = getPermissionLevel(player)
		if lvl > 0 then
			AdminSyncRemote:FireClient(player, "AuthStatus", lvl)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	RateLimitTracker[player.UserId] = nil
	FrozenPlayers[player.UserId] = nil
end)
