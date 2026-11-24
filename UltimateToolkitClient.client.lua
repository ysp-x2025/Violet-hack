--!strict
--[[
    ROBLOX ULTIMATE ALL-IN-ONE TOOLKIT — CLIENT CONTROL CENTER
    File: UltimateToolkitClient.client.lua
    Location: StarterPlayer/StarterPlayerScripts/UltimateToolkitClient (LocalScript)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

local CONFIG = {
	TOOLKIT_NAME = "ULTIMATE TOOLKIT",
	VERSION = "v4.0 ULTIMATE",
	ASSETS = {
		MAIN_LOGO_ASSET_ID = "rbxassetid://INSERT_IMAGE_1_LOGO_ID_HERE",
		FLOATING_ICON_ASSET_ID = "rbxassetid://INSERT_IMAGE_2_FLOATING_ICON_ID_HERE",
	},
	TOGGLE_KEY = Enum.KeyCode.RightShift,
	FREECAM_KEY = Enum.KeyCode.P,
}

local CleanupManager = {}
CleanupManager.Connections = {} :: { RBXScriptConnection }
CleanupManager.Instances = {} :: { Instance }
CleanupManager.Callbacks = {} :: { () -> () }

function CleanupManager:TrackConnection(conn: RBXScriptConnection): RBXScriptConnection
	table.insert(self.Connections, conn)
	return conn
end

function CleanupManager:TrackInstance(inst: Instance): Instance
	table.insert(self.Instances, inst)
	return inst
end

function CleanupManager:OnShutdown(cb: () -> ())
	table.insert(self.Callbacks, cb)
end

function CleanupManager:CleanupAll()
	for _, cb in ipairs(self.Callbacks) do
		pcall(cb)
	end
	for _, conn in ipairs(self.Connections) do
		if conn.Connected then
			conn:Disconnect()
		end
	end
	table.clear(self.Connections)
	for _, inst in ipairs(self.Instances) do
		if inst and inst.Parent then
			inst:Destroy()
		end
	end
	table.clear(self.Instances)
end

local ThemeManager = {
	CurrentPreset = "CyberViolet",
	RGBMode = false,
	Transparency = 0.08,
	UIScale = 1.0,
	Font = Enum.Font.GothamMedium,
	BoldFont = Enum.Font.GothamBold,
	Colors = {
		Background = Color3.fromRGB(14, 10, 26),
		Sidebar = Color3.fromRGB(20, 14, 38),
		Card = Color3.fromRGB(28, 20, 52),
		CardHover = Color3.fromRGB(38, 28, 68),
		Accent = Color3.fromRGB(168, 85, 247),
		AccentBright = Color3.fromRGB(216, 180, 254),
		PinkGlow = Color3.fromRGB(244, 114, 182),
		TextPrimary = Color3.fromRGB(245, 243, 255),
		TextMuted = Color3.fromRGB(167, 155, 200),
		Stroke = Color3.fromRGB(115, 58, 185),
		Success = Color3.fromRGB(52, 211, 153),
		Warning = Color3.fromRGB(251, 191, 36),
		Danger = Color3.fromRGB(248, 113, 113),
	},
	BoundElements = {} :: { { Instance: GuiObject, Property: string, ColorKey: string } },
}

local THEME_PRESETS = {
	CyberViolet = {
		Background = Color3.fromRGB(14, 10, 26),
		Sidebar = Color3.fromRGB(20, 14, 38),
		Card = Color3.fromRGB(28, 20, 52),
		Accent = Color3.fromRGB(168, 85, 247),
		Stroke = Color3.fromRGB(115, 58, 185),
	},
	ObsidianOrchid = {
		Background = Color3.fromRGB(10, 8, 16),
		Sidebar = Color3.fromRGB(16, 12, 26),
		Card = Color3.fromRGB(24, 18, 38),
		Accent = Color3.fromRGB(217, 70, 239),
		Stroke = Color3.fromRGB(140, 45, 160),
	},
	AbyssalNebula = {
		Background = Color3.fromRGB(11, 14, 30),
		Sidebar = Color3.fromRGB(16, 20, 44),
		Card = Color3.fromRGB(22, 28, 58),
		Accent = Color3.fromRGB(129, 140, 248),
		Stroke = Color3.fromRGB(79, 70, 229),
	},
}

function ThemeManager:Bind(inst: GuiObject, property: string, colorKey: string)
	table.insert(self.BoundElements, { Instance = inst, Property = property, ColorKey = colorKey })
	local color = self.Colors[colorKey]
	if color then
		(inst :: any)[property] = color
	end
end

function ThemeManager:ApplyPreset(presetName: string)
	local preset = THEME_PRESETS[presetName]
	if not preset then return end
	self.CurrentPreset = presetName
	for k, v in pairs(preset) do
		self.Colors[k] = v
	end
	for _, item in ipairs(self.BoundElements) do
		if item.Instance and item.Instance.Parent and self.Colors[item.ColorKey] then
			(item.Instance :: any)[item.Property] = self.Colors[item.ColorKey]
		end
	end
end

function ThemeManager:SetAccent(color: Color3)
	self.Colors.Accent = color
	self.Colors.Stroke = color:Lerp(Color3.new(0, 0, 0), 0.35)
	for _, item in ipairs(self.BoundElements) do
		if item.Instance and item.Instance.Parent and (item.ColorKey == "Accent" or item.ColorKey == "Stroke") then
			(item.Instance :: any)[item.Property] = self.Colors[item.ColorKey]
		end
	end
end

local ExistingGui = PlayerGui:FindFirstChild("UltimateToolkitScreenGui")
if ExistingGui then
	ExistingGui:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "UltimateToolkitScreenGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 100
ScreenGui.Parent = PlayerGui
CleanupManager:TrackInstance(ScreenGui)

local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local InitialScale = IsMobile and 0.88 or 1.0
ThemeManager.UIScale = InitialScale

local UIScaleObj = Instance.new("UIScale")
UIScaleObj.Scale = InitialScale
UIScaleObj.Parent = ScreenGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainWindow"
MainFrame.Size = IsMobile and UDim2.fromScale(0.92, 0.86) or UDim2.fromOffset(780, 500)
MainFrame.Position = UDim2.fromScale(0.5, 0.5)
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.BackgroundTransparency = ThemeManager.Transparency
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui
ThemeManager:Bind(MainFrame, "BackgroundColor3", "Background")

Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 14)

local MainStroke = Instance.new("UIStroke")
MainStroke.Thickness = 1.6
MainStroke.Transparency = 0.2
MainStroke.Parent = MainFrame
ThemeManager:Bind(MainStroke, "Color", "Accent")

local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 56)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame
ThemeManager:Bind(TopBar, "BackgroundColor3", "Sidebar")

local TopStroke = Instance.new("Frame")
TopStroke.Size = UDim2.new(1, 0, 0, 1)
TopStroke.Position = UDim2.new(0, 0, 1, -1)
TopStroke.BorderSizePixel = 0
TopStroke.Parent = TopBar
ThemeManager:Bind(TopStroke, "BackgroundColor3", "Stroke")

local LogoContainer = Instance.new("Frame")
LogoContainer.Name = "LogoContainer"
LogoContainer.Size = UDim2.fromOffset(44, 44)
LogoContainer.Position = UDim2.new(0, 12, 0.5, 0)
LogoContainer.AnchorPoint = Vector2.new(0, 0.5)
LogoContainer.BackgroundColor3 = Color3.fromRGB(36, 22, 64)
LogoContainer.BackgroundTransparency = 0.45
LogoContainer.Parent = TopBar
Instance.new("UICorner", LogoContainer).CornerRadius = UDim.new(0, 10)

local LogoGlow = Instance.new("UIStroke")
LogoGlow.Color = ThemeManager.Colors.PinkGlow
LogoGlow.Thickness = 1.3
LogoGlow.Transparency = 0.35
LogoGlow.Parent = LogoContainer

local MainLogoImage = Instance.new("ImageLabel")
MainLogoImage.Name = "MainFlowerLogo"
MainLogoImage.Size = UDim2.fromScale(0.86, 0.86)
MainLogoImage.Position = UDim2.fromScale(0.5, 0.5)
MainLogoImage.AnchorPoint = Vector2.new(0.5, 0.5)
MainLogoImage.BackgroundTransparency = 1
MainLogoImage.Image = CONFIG.ASSETS.MAIN_LOGO_ASSET_ID
MainLogoImage.ScaleType = Enum.ScaleType.Fit
MainLogoImage.Parent = LogoContainer

local AspectRatioLogo = Instance.new("UIAspectRatioConstraint")
AspectRatioLogo.AspectRatio = 1
AspectRatioLogo.Parent = MainLogoImage

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(0, 260, 0, 24)
TitleLabel.Position = UDim2.new(0, 66, 0, 8)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Font = ThemeManager.BoldFont
TitleLabel.TextSize = 16
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Text = CONFIG.TOOLKIT_NAME
TitleLabel.Parent = TopBar
ThemeManager:Bind(TitleLabel, "TextColor3", "TextPrimary")

local SubtitleLabel = Instance.new("TextLabel")
SubtitleLabel.Size = UDim2.new(0, 280, 0, 18)
SubtitleLabel.Position = UDim2.new(0, 66, 0, 30)
SubtitleLabel.BackgroundTransparency = 1
SubtitleLabel.Font = ThemeManager.Font
SubtitleLabel.TextSize = 11
SubtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
SubtitleLabel.Text = CONFIG.VERSION .. " • CYBER VIOLET CONTROL CENTER"
SubtitleLabel.Parent = TopBar
ThemeManager:Bind(SubtitleLabel, "TextColor3", "AccentBright")

local SearchBox = Instance.new("TextBox")
SearchBox.Name = "GlobalSearch"
SearchBox.Size = UDim2.new(0, IsMobile and 120 or 190, 0, 32)
SearchBox.Position = UDim2.new(1, -135, 0.5, 0)
SearchBox.AnchorPoint = Vector2.new(1, 0.5)
SearchBox.Font = ThemeManager.Font
SearchBox.TextSize = 12
SearchBox.PlaceholderText = "Search features..."
SearchBox.Text = ""
SearchBox.ClearTextOnFocus = false
SearchBox.Parent = TopBar
ThemeManager:Bind(SearchBox, "BackgroundColor3", "Card")
ThemeManager:Bind(SearchBox, "TextColor3", "TextPrimary")
SearchBox.PlaceholderColor3 = ThemeManager.Colors.TextMuted
Instance.new("UICorner", SearchBox).CornerRadius = UDim.new(0, 8)
local SearchPad = Instance.new("UIPadding")
SearchPad.PaddingLeft = UDim.new(0, 10)
SearchPad.Parent = SearchBox

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Name = "MinimizeButton"
MinimizeBtn.Size = UDim2.fromOffset(34, 34)
MinimizeBtn.Position = UDim2.new(1, -86, 0.5, 0)
MinimizeBtn.AnchorPoint = Vector2.new(0, 0.5)
MinimizeBtn.Font = ThemeManager.BoldFont
MinimizeBtn.TextSize = 16
MinimizeBtn.Text = "—"
MinimizeBtn.Parent = TopBar
ThemeManager:Bind(MinimizeBtn, "BackgroundColor3", "Card")
ThemeManager:Bind(MinimizeBtn, "TextColor3", "TextPrimary")
Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 8)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Name = "CloseButton"
CloseBtn.Size = UDim2.fromOffset(34, 34)
CloseBtn.Position = UDim2.new(1, -44, 0.5, 0)
CloseBtn.AnchorPoint = Vector2.new(0, 0.5)
CloseBtn.BackgroundColor3 = Color3.fromRGB(185, 28, 68)
CloseBtn.Font = ThemeManager.BoldFont
CloseBtn.TextSize = 15
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.new(1, 1, 1)
CloseBtn.Parent = TopBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 8)

do
	local dragging = false
	local dragStart: Vector3
	local startPos: UDim2

	CleanupManager:TrackConnection(TopBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = MainFrame.Position
		end
	end))

	CleanupManager:TrackConnection(UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			local vp = Camera.ViewportSize
			local newX = math.clamp(startPos.X.Offset + delta.X, -vp.X * 0.45, vp.X * 0.45)
			local newY = math.clamp(startPos.Y.Offset + delta.Y, -vp.Y * 0.45, vp.Y * 0.45)
			MainFrame.Position = UDim2.new(startPos.X.Scale, newX, startPos.Y.Scale, newY)
		end
	end))

	CleanupManager:TrackConnection(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))
end

local FloatingManager = {
	Size = 58,
	Transparency = 0,
	DefaultPos = UDim2.new(0, 24, 0.5, -29),
	IsOpen = true,
	IsMinimized = false,
}

local FloatingBtn = Instance.new("ImageButton")
FloatingBtn.Name = "FloatingFlowerReopenButton"
FloatingBtn.Size = UDim2.fromOffset(FloatingManager.Size, FloatingManager.Size)
FloatingBtn.Position = FloatingManager.DefaultPos
FloatingBtn.BackgroundColor3 = Color3.fromRGB(22, 14, 42)
FloatingBtn.BackgroundTransparency = 0.05
FloatingBtn.Image = CONFIG.ASSETS.FLOATING_ICON_ASSET_ID
FloatingBtn.ScaleType = Enum.ScaleType.Fit
FloatingBtn.ZIndex = 250
FloatingBtn.AutoButtonColor = false
FloatingBtn.Parent = ScreenGui

Instance.new("UICorner", FloatingBtn).CornerRadius = UDim.new(1, 0)
local FloatAspect = Instance.new("UIAspectRatioConstraint")
FloatAspect.AspectRatio = 1
FloatAspect.Parent = FloatingBtn

local FloatGlow = Instance.new("UIStroke")
FloatGlow.Thickness = 2.2
FloatGlow.Color = ThemeManager.Colors.Accent
FloatGlow.Transparency = 0.15
FloatGlow.Parent = FloatingBtn

function FloatingManager:SetMainVisible(visible: boolean)
	self.IsOpen = visible
	if visible then
		MainFrame.Visible = true
		MainFrame.Size = IsMobile and UDim2.fromScale(0.85, 0.8) or UDim2.fromOffset(720, 460)
		TweenService:Create(MainFrame, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = IsMobile and UDim2.fromScale(0.92, 0.86) or UDim2.fromOffset(780, 500),
		}):Play()
	else
		local tween = TweenService:Create(MainFrame, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.fromOffset(40, 40),
		})
		tween:Play()
		tween.Completed:Once(function()
			if not self.IsOpen then
				MainFrame.Visible = false
			end
		end)
	end
end

function FloatingManager:ResetPosition()
	FloatingBtn.Position = self.DefaultPos
end

function FloatingManager:UpdateAppearance(size: number?, transparency: number?)
	if size then
		self.Size = math.clamp(size, 42, 96)
		FloatingBtn.Size = UDim2.fromOffset(self.Size, self.Size)
	end
	if transparency then
		self.Transparency = math.clamp(transparency, 0, 0.85)
		FloatingBtn.ImageTransparency = self.Transparency
		FloatingBtn.BackgroundTransparency = math.clamp(self.Transparency + 0.05, 0, 0.9)
	end
end

do
	local dragging = false
	local movedDistance = 0
	local dragStart: Vector3
	local startPos: UDim2

	CleanupManager:TrackConnection(FloatingBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			movedDistance = 0
			dragStart = input.Position
			startPos = FloatingBtn.Position
			TweenService:Create(FloatingBtn, TweenInfo.new(0.1), {
				Size = UDim2.fromOffset(FloatingManager.Size * 0.92, FloatingManager.Size * 0.92),
			}):Play()
		end
	end))

	CleanupManager:TrackConnection(UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			movedDistance = delta.Magnitude
			local vp = Camera.ViewportSize
			local absStartX = startPos.X.Scale * vp.X + startPos.X.Offset
			local absStartY = startPos.Y.Scale * vp.Y + startPos.Y.Offset
			local clampedX = math.clamp(absStartX + delta.X, 8, vp.X - FloatingManager.Size - 8)
			local clampedY = math.clamp(absStartY + delta.Y, 36, vp.Y - FloatingManager.Size - 8)
			FloatingBtn.Position = UDim2.fromOffset(clampedX, clampedY)
		end
	end))

	CleanupManager:TrackConnection(UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			TweenService:Create(FloatingBtn, TweenInfo.new(0.12), {
				Size = UDim2.fromOffset(FloatingManager.Size, FloatingManager.Size),
			}):Play()
			if movedDistance < 10 then
				FloatingManager:SetMainVisible(not FloatingManager.IsOpen)
			end
		end
	end))
end

CleanupManager:TrackConnection(CloseBtn.MouseButton1Click:Connect(function()
	FloatingManager:SetMainVisible(false)
end))

CleanupManager:TrackConnection(MinimizeBtn.MouseButton1Click:Connect(function()
	FloatingManager.IsMinimized = not FloatingManager.IsMinimized
	if FloatingManager.IsMinimized then
		TweenService:Create(MainFrame, TweenInfo.new(0.18), {
			Size = UDim2.fromOffset(IsMobile and 340 or 440, 56),
		}):Play()
	else
		TweenService:Create(MainFrame, TweenInfo.new(0.18), {
			Size = IsMobile and UDim2.fromScale(0.92, 0.86) or UDim2.fromOffset(780, 500),
		}):Play()
	end
end))

local BodyFrame = Instance.new("Frame")
BodyFrame.Name = "BodyFrame"
BodyFrame.Size = UDim2.new(1, 0, 1, -56)
BodyFrame.Position = UDim2.fromOffset(0, 56)
BodyFrame.BackgroundTransparency = 1
BodyFrame.Parent = MainFrame

local Sidebar = Instance.new("ScrollingFrame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, IsMobile and 130 or 168, 1, 0)
Sidebar.BorderSizePixel = 0
Sidebar.ScrollBarThickness = 3
Sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
Sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
Sidebar.Parent = BodyFrame
ThemeManager:Bind(Sidebar, "BackgroundColor3", "Sidebar")

local SidebarLayout = Instance.new("UIListLayout")
SidebarLayout.Padding = UDim.new(0, 4)
SidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
SidebarLayout.Parent = Sidebar

local SidebarPad = Instance.new("UIPadding")
SidebarPad.PaddingTop = UDim.new(0, 8)
SidebarPad.PaddingBottom = UDim.new(0, 8)
SidebarPad.Parent = Sidebar

local ContentHolder = Instance.new("Frame")
ContentHolder.Name = "ContentHolder"
ContentHolder.Size = UDim2.new(1, -(IsMobile and 130 or 168), 1, 0)
ContentHolder.Position = UDim2.fromOffset(IsMobile and 130 or 168, 0)
ContentHolder.BackgroundTransparency = 1
ContentHolder.Parent = BodyFrame

local NotificationManager = {
	History = {} :: { { Type: string, Title: string, Text: string, Time: string } },
	Duration = 3.5,
}

local NotifContainer = Instance.new("Frame")
NotifContainer.Name = "NotificationContainer"
NotifContainer.Size = UDim2.new(0, 300, 1, -24)
NotifContainer.Position = UDim2.new(1, -16, 1, -12)
NotifContainer.AnchorPoint = Vector2.new(1, 1)
NotifContainer.BackgroundTransparency = 1
NotifContainer.ZIndex = 300
NotifContainer.Parent = ScreenGui

local NotifLayout = Instance.new("UIListLayout")
NotifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
NotifLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
NotifLayout.Padding = UDim.new(0, 8)
NotifLayout.Parent = NotifContainer

function NotificationManager:Push(notifType: "Success" | "Error" | "Warning" | "Info", title: string, message: string)
	table.insert(self.History, 1, {
		Type = notifType,
		Title = title,
		Text = message,
		Time = os.date("%H:%M:%S"),
	})
	if #self.History > 50 then
		table.remove(self.History)
	end

	local accentColor = ThemeManager.Colors.Accent
	if notifType == "Success" then accentColor = ThemeManager.Colors.Success
	elseif notifType == "Error" then accentColor = ThemeManager.Colors.Danger
	elseif notifType == "Warning" then accentColor = ThemeManager.Colors.Warning end

	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 58)
	card.BackgroundColor3 = ThemeManager.Colors.Card
	card.BackgroundTransparency = 0.05
	card.Parent = NotifContainer
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

	local stroke = Instance.new("UIStroke")
	stroke.Color = accentColor
	stroke.Thickness = 1.4
	stroke.Parent = card

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, -16, 0, 20)
	titleLbl.Position = UDim2.fromOffset(10, 6)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Font = ThemeManager.BoldFont
	titleLbl.TextSize = 13
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.TextColor3 = accentColor
	titleLbl.Text = string.format("[%s] %s", string.upper(notifType), title)
	titleLbl.Parent = card

	local bodyLbl = Instance.new("TextLabel")
	bodyLbl.Size = UDim2.new(1, -16, 0, 26)
	bodyLbl.Position = UDim2.fromOffset(10, 26)
	bodyLbl.BackgroundTransparency = 1
	bodyLbl.Font = ThemeManager.Font
	bodyLbl.TextSize = 11
	bodyLbl.TextWrapped = true
	bodyLbl.TextXAlignment = Enum.TextXAlignment.Left
	bodyLbl.TextColor3 = ThemeManager.Colors.TextPrimary
	bodyLbl.Text = message
	bodyLbl.Parent = card

	task.delay(self.Duration, function()
		if card and card.Parent then
			local fade = TweenService:Create(card, TweenInfo.new(0.25), { BackgroundTransparency = 1 })
			fade:Play()
			fade.Completed:Once(function()
				card:Destroy()
			end)
		end
	end)
end

local Tabs: { [string]: { Button: TextButton, Page: ScrollingFrame } } = {}
local ActiveTabName = ""
local SearchableControls: { { Frame: GuiObject, Keywords: string, TabName: string } } = {}

local function selectTab(tabName: string)
	ActiveTabName = tabName
	for name, tabData in pairs(Tabs) do
		local isSelected = (name == tabName)
		tabData.Page.Visible = isSelected
		tabData.Button.BackgroundColor3 = isSelected and ThemeManager.Colors.Accent or ThemeManager.Colors.Card
		tabData.Button.TextColor3 = isSelected and Color3.new(1, 1, 1) or ThemeManager.Colors.TextMuted
	end
end

local function createTab(tabName: string): ScrollingFrame
	local btn = Instance.new("TextButton")
	btn.Name = tabName .. "_TabBtn"
	btn.Size = UDim2.new(1, -12, 0, 34)
	btn.Font = ThemeManager.BoldFont
	btn.TextSize = 11
	btn.Text = tabName
	btn.AutoButtonColor = false
	btn.Parent = Sidebar
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

	local page = Instance.new("ScrollingFrame")
	page.Name = tabName .. "_Page"
	page.Size = UDim2.fromScale(1, 1)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 4
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.CanvasSize = UDim2.new(0, 0, 0, 0)
	page.Visible = false
	page.Parent = ContentHolder

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = page

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 14)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = page

	CleanupManager:TrackConnection(btn.MouseButton1Click:Connect(function()
		selectTab(tabName)
	end))

	Tabs[tabName] = { Button = btn, Page = page }
	if ActiveTabName == "" then
		selectTab(tabName)
	end
	return page
end

local function registerSearchable(frame: GuiObject, label: string, tabName: string)
	table.insert(SearchableControls, {
		Frame = frame,
		Keywords = string.lower(label .. " " .. tabName),
		TabName = tabName,
	})
end

local function addSectionHeader(page: ScrollingFrame, title: string)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 24)
	lbl.BackgroundTransparency = 1
	lbl.Font = ThemeManager.BoldFont
	lbl.TextSize = 13
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Text = "◆ " .. string.upper(title)
	lbl.Parent = page
	ThemeManager:Bind(lbl, "TextColor3", "AccentBright")
	return lbl
end

local function addToggle(page: ScrollingFrame, tabName: string, labelText: string, defaultState: boolean, callback: (boolean) -> ())
	local state = defaultState
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 38)
	row.Parent = page
	ThemeManager:Bind(row, "BackgroundColor3", "Card")
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
	registerSearchable(row, labelText, tabName)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -70, 1, 0)
	lbl.Position = UDim2.fromOffset(12, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = ThemeManager.Font
	lbl.TextSize = 12
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Text = labelText
	lbl.Parent = row
	ThemeManager:Bind(lbl, "TextColor3", "TextPrimary")

	local pill = Instance.new("TextButton")
	pill.Size = UDim2.fromOffset(46, 22)
	pill.Position = UDim2.new(1, -12, 0.5, 0)
	pill.AnchorPoint = Vector2.new(1, 0.5)
	pill.Text = ""
	pill.AutoButtonColor = false
	pill.Parent = row
	Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(16, 16)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.Parent = pill
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local function render(val: boolean, fire: boolean)
		state = val
		pill.BackgroundColor3 = state and ThemeManager.Colors.Accent or Color3.fromRGB(55, 45, 85)
		knob.Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
		if fire then
			callback(state)
		end
	end

	render(defaultState, false)
	CleanupManager:TrackConnection(pill.MouseButton1Click:Connect(function()
		render(not state, true)
	end))

	return {
		Set = function(_, val: boolean) render(val, true) end,
		Get = function() return state end,
	}
end

local function addSlider(page: ScrollingFrame, tabName: string, labelText: string, minVal: number, maxVal: number, defaultVal: number, decimals: number, callback: (number) -> ())
	local currentVal = math.clamp(defaultVal, minVal, maxVal)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 50)
	row.Parent = page
	ThemeManager:Bind(row, "BackgroundColor3", "Card")
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
	registerSearchable(row, labelText, tabName)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -80, 0, 22)
	lbl.Position = UDim2.fromOffset(12, 4)
	lbl.BackgroundTransparency = 1
	lbl.Font = ThemeManager.Font
	lbl.TextSize = 12
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Text = labelText
	lbl.Parent = row
	ThemeManager:Bind(lbl, "TextColor3", "TextPrimary")

	local valLbl = Instance.new("TextLabel")
	valLbl.Size = UDim2.new(0, 70, 0, 22)
	valLbl.Position = UDim2.new(1, -12, 0, 4)
	valLbl.AnchorPoint = Vector2.new(1, 0)
	valLbl.BackgroundTransparency = 1
	valLbl.Font = ThemeManager.BoldFont
	valLbl.TextSize = 12
	valLbl.TextXAlignment = Enum.TextXAlignment.Right
	valLbl.Parent = row
	ThemeManager:Bind(valLbl, "TextColor3", "AccentBright")

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -24, 0, 8)
	track.Position = UDim2.new(0, 12, 0, 32)
	track.BackgroundColor3 = Color3.fromRGB(45, 34, 76)
	track.Parent = row
	Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale((currentVal - minVal) / math.max(maxVal - minVal, 0.0001), 1)
	fill.Parent = track
	ThemeManager:Bind(fill, "BackgroundColor3", "Accent")
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

	local fmt = "%." .. tostring(decimals) .. "f"
	valLbl.Text = string.format(fmt, currentVal)

	local sliding = false
	local function updateFromInput(posX: number)
		local alpha = math.clamp((posX - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		local raw = minVal + (maxVal - minVal) * alpha
		local mult = 10 ^ decimals
		currentVal = math.floor(raw * mult + 0.5) / mult
		fill.Size = UDim2.fromScale(alpha, 1)
		valLbl.Text = string.format(fmt, currentVal)
		callback(currentVal)
	end

	CleanupManager:TrackConnection(track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			sliding = true
			updateFromInput(input.Position.X)
		end
	end))

	CleanupManager:TrackConnection(UserInputService.InputChanged:Connect(function(input)
		if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			updateFromInput(input.Position.X)
		end
	end))

	CleanupManager:TrackConnection(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			sliding = false
		end
	end))

	return {
		Set = function(_, v: number)
			currentVal = math.clamp(v, minVal, maxVal)
			local alpha = (currentVal - minVal) / math.max(maxVal - minVal, 0.0001)
			fill.Size = UDim2.fromScale(alpha, 1)
			valLbl.Text = string.format(fmt, currentVal)
			callback(currentVal)
		end,
		Get = function() return currentVal end,
	}
end

local function addButton(page: ScrollingFrame, tabName: string, labelText: string, callback: () -> ())
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 36)
	btn.Font = ThemeManager.BoldFont
	btn.TextSize = 12
	btn.Text = labelText
	btn.Parent = page
	ThemeManager:Bind(btn, "BackgroundColor3", "Card")
	ThemeManager:Bind(btn, "TextColor3", "TextPrimary")
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
	registerSearchable(btn, labelText, tabName)

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Transparency = 0.4
	stroke.Parent = btn
	ThemeManager:Bind(stroke, "Color", "Stroke")

	CleanupManager:TrackConnection(btn.MouseButton1Click:Connect(callback))
	return btn
end

local function addDropdown(page: ScrollingFrame, tabName: string, labelText: string, options: { string }, defaultIndex: number, callback: (string) -> ())
	local idx = math.clamp(defaultIndex, 1, #options)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 38)
	row.Parent = page
	ThemeManager:Bind(row, "BackgroundColor3", "Card")
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
	registerSearchable(row, labelText, tabName)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0.55, 0, 1, 0)
	lbl.Position = UDim2.fromOffset(12, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = ThemeManager.Font
	lbl.TextSize = 12
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Text = labelText
	lbl.Parent = row
	ThemeManager:Bind(lbl, "TextColor3", "TextPrimary")

	local cycleBtn = Instance.new("TextButton")
	cycleBtn.Size = UDim2.new(0.4, -12, 0, 26)
	cycleBtn.Position = UDim2.new(1, -12, 0.5, 0)
	cycleBtn.AnchorPoint = Vector2.new(1, 0.5)
	cycleBtn.Font = ThemeManager.BoldFont
	cycleBtn.TextSize = 11
	cycleBtn.Text = options[idx] .. " ▾"
	cycleBtn.Parent = row
	ThemeManager:Bind(cycleBtn, "BackgroundColor3", "Sidebar")
	ThemeManager:Bind(cycleBtn, "TextColor3", "AccentBright")
	Instance.new("UICorner", cycleBtn).CornerRadius = UDim.new(0, 6)

	CleanupManager:TrackConnection(cycleBtn.MouseButton1Click:Connect(function()
		idx = (idx % #options) + 1
		cycleBtn.Text = options[idx] .. " ▾"
		callback(options[idx])
	end))

	return {
		Set = function(_, val: string)
			for i, opt in ipairs(options) do
				if opt == val then
					idx = i
					cycleBtn.Text = opt .. " ▾"
					callback(opt)
					break
				end
			end
		end,
	}
end

local function addTextInput(page: ScrollingFrame, tabName: string, placeholder: string, buttonLabel: string, callback: (string) -> ())
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 38)
	row.Parent = page
	ThemeManager:Bind(row, "BackgroundColor3", "Card")
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
	registerSearchable(row, placeholder .. " " .. buttonLabel, tabName)

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(0.68, -12, 0, 26)
	box.Position = UDim2.new(0, 10, 0.5, 0)
	box.AnchorPoint = Vector2.new(0, 0.5)
	box.Font = ThemeManager.Font
	box.TextSize = 12
	box.PlaceholderText = placeholder
	box.Text = ""
	box.ClearTextOnFocus = false
	box.Parent = row
	ThemeManager:Bind(box, "BackgroundColor3", "Sidebar")
	ThemeManager:Bind(box, "TextColor3", "TextPrimary")
	box.PlaceholderColor3 = ThemeManager.Colors.TextMuted
	Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)

	local actionBtn = Instance.new("TextButton")
	actionBtn.Size = UDim2.new(0.3, -8, 0, 26)
	actionBtn.Position = UDim2.new(1, -10, 0.5, 0)
	actionBtn.AnchorPoint = Vector2.new(1, 0.5)
	actionBtn.Font = ThemeManager.BoldFont
	actionBtn.TextSize = 11
	actionBtn.Text = buttonLabel
	actionBtn.Parent = row
	ThemeManager:Bind(actionBtn, "BackgroundColor3", "Accent")
	actionBtn.TextColor3 = Color3.new(1, 1, 1)
	Instance.new("UICorner", actionBtn).CornerRadius = UDim.new(0, 6)

	CleanupManager:TrackConnection(actionBtn.MouseButton1Click:Connect(function()
		callback(box.Text)
	end))
	return box
end

CleanupManager:TrackConnection(SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
	local query = string.lower(SearchBox.Text)
	for _, item in ipairs(SearchableControls) do
		if query == "" then
			item.Frame.Visible = true
		else
			item.Frame.Visible = string.find(item.Keywords, query, 1, true) ~= nil
		end
	end
end))

local TabHome = createTab("HOME")
local TabESP = createTab("ESP")
local TabMovement = createTab("MOVEMENT")
local TabFreecam = createTab("FREECAM")
local TabCombat = createTab("COMBAT TRAINING")
local TabPlayers = createTab("PLAYERS")
local TabAdmin = createTab("ADMIN")
local TabVisuals = createTab("VISUALS")
local TabCamera = createTab("CAMERA")
local TabReplay = createTab("REPLAY")
local TabWaypoints = createTab("WAYPOINTS")
local TabUtilities = createTab("UTILITIES")
local TabDeveloper = createTab("DEVELOPER")
local TabSettings = createTab("SETTINGS")
local TabAbout = createTab("ABOUT")

local ESPManager = {
	Enabled = false,
	ShowPlayers = true,
	ShowNPCs = false,
	ShowItems = false,
	ShowNames = true,
	ShowHealth = true,
	ShowHealthBar = true,
	ShowDistance = true,
	ShowTeam = true,
	Box3D = false,
	Tracer = false,
	HighlightMode = true,
	VisibilityCheck = false,
	MaxRange = 1000,
	Opacity = 0.85,
	Thickness = 1.5,
	TextSize = 13,
	Font = Enum.Font.GothamBold,
	ShowBackground = true,
	FriendlyColor = Color3.fromRGB(52, 211, 153),
	EnemyColor = Color3.fromRGB(244, 63, 94),
	NPCColor = Color3.fromRGB(251, 191, 36),
	ItemColor = Color3.fromRGB(168, 85, 247),
	Entries = {} :: { [Instance]: { Billboard: BillboardGui?, Highlight: Highlight?, Box3DAdorn: BoxHandleAdornment?, TracerLine: Frame? } },
}

local ESPOverlay = Instance.new("Folder")
ESPOverlay.Name = "ToolkitESPOverlay"
ESPOverlay.Parent = ScreenGui
CleanupManager:TrackInstance(ESPOverlay)

function ESPManager:ClearEntry(target: Instance)
	local entry = self.Entries[target]
	if not entry then return end
	if entry.Billboard then entry.Billboard:Destroy() end
	if entry.Highlight then entry.Highlight:Destroy() end
	if entry.Box3DAdorn then entry.Box3DAdorn:Destroy() end
	if entry.TracerLine then entry.TracerLine:Destroy() end
	self.Entries[target] = nil
end

function ESPManager:ClearAll()
	for target in pairs(self.Entries) do
		self:ClearEntry(target)
	end
end

function ESPManager:Reset()
	self.Enabled = false
	self.ShowPlayers = true
	self.ShowNPCs = false
	self.ShowItems = false
	self.MaxRange = 1000
	self.Opacity = 0.85
	self:ClearAll()
	NotificationManager:Push("Info", "ESP Reset", "All ESP settings and overlays cleared.")
end

local function isTargetVisible(origin: Vector3, targetPart: BasePart, model: Instance): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { model }
	if LocalPlayer.Character then table.insert(ignore, LocalPlayer.Character) end
	params.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(origin, targetPart.Position - origin, params)
	return result == nil
end

function ESPManager:Update()
	if not self.Enabled then
		if next(self.Entries) ~= nil then
			self:ClearAll()
		end
		return
	end

	local camPos = Camera.CFrame.Position
	local validTargets: { [Instance]: { Color: Color3, Label: string, HealthPct: number?, Adornee: BasePart } } = {}

	if self.ShowPlayers then
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer and plr.Character then
				local root = plr.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local hum = plr.Character:FindFirstChildOfClass("Humanoid")
				if root and hum and hum.Health > 0 then
					local dist = (root.Position - camPos).Magnitude
					if dist <= self.MaxRange then
						local isFriendly = (plr.Team ~= nil and plr.Team == LocalPlayer.Team)
						local col = isFriendly and self.FriendlyColor or self.EnemyColor
						local parts = {}
						if self.ShowNames then table.insert(parts, plr.DisplayName) end
						if self.ShowTeam and plr.Team then table.insert(parts, "[" .. plr.Team.Name .. "]") end
						if self.ShowHealth then table.insert(parts, string.format("%d/%d HP", math.floor(hum.Health), math.floor(hum.MaxHealth))) end
						if self.ShowDistance then table.insert(parts, string.format("%dm", math.floor(dist))) end
						validTargets[plr.Character] = {
							Color = col,
							Label = table.concat(parts, " • "),
							HealthPct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1),
							Adornee = root,
						}
					end
				end
			end
		end
	end

	if self.ShowNPCs then
		for _, inst in ipairs(workspace:GetDescendants()) do
			if inst:IsA("Model") and not Players:GetPlayerFromCharacter(inst) then
				local hum = inst:FindFirstChildOfClass("Humanoid")
				local root = inst:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hum and root and hum.Health > 0 then
					local dist = (root.Position - camPos).Magnitude
					if dist <= self.MaxRange then
						validTargets[inst] = {
							Color = self.NPCColor,
							Label = string.format("[NPC] %s • %d HP • %dm", inst.Name, math.floor(hum.Health), math.floor(dist)),
							HealthPct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1),
							Adornee = root,
						}
					end
				end
			end
		end
	end

	if self.ShowItems then
		for _, inst in ipairs(workspace:GetDescendants()) do
			if inst:IsA("Tool") or inst:IsA("ProximityPrompt") then
				local part = inst:IsA("Tool") and inst:FindFirstChild("Handle") :: BasePart? or inst.Parent :: BasePart?
				if part and part:IsA("BasePart") then
					local dist = (part.Position - camPos).Magnitude
					if dist <= self.MaxRange then
						validTargets[inst] = {
							Color = self.ItemColor,
							Label = string.format("[ITEM] %s • %dm", inst.Name, math.floor(dist)),
							HealthPct = nil,
							Adornee = part,
						}
					end
				end
			end
		end
	end

	for target in pairs(self.Entries) do
		if not validTargets[target] then
			self:ClearEntry(target)
		end
	end

	for target, data in pairs(validTargets) do
		local visible = true
		if self.VisibilityCheck then
			visible = isTargetVisible(camPos, data.Adornee, target)
		end

		local entry = self.Entries[target]
		if not entry then
			entry = {}
			self.Entries[target] = entry
		end

		if self.HighlightMode and target:IsA("Model") then
			if not entry.Highlight then
				local hl = Instance.new("Highlight")
				hl.Adornee = target
				hl.Parent = target
				entry.Highlight = hl
			end
			entry.Highlight.Enabled = visible
			entry.Highlight.FillColor = data.Color
			entry.Highlight.OutlineColor = data.Color
			entry.Highlight.FillTransparency = 1 - (self.Opacity * 0.45)
			entry.Highlight.OutlineTransparency = 1 - self.Opacity
		elseif entry.Highlight then
			entry.Highlight:Destroy()
			entry.Highlight = nil
		end

		if self.Box3D then
			if not entry.Box3DAdorn then
				local box = Instance.new("BoxHandleAdornment")
				box.AlwaysOnTop = true
				box.ZIndex = 5
				box.Size = Vector3.new(4, 5.5, 4)
				box.Parent = ESPOverlay
				entry.Box3DAdorn = box
			end
			entry.Box3DAdorn.Adornee = data.Adornee
			entry.Box3DAdorn.Visible = visible
			entry.Box3DAdorn.Color3 = data.Color
			entry.Box3DAdorn.Transparency = 1 - (self.Opacity * 0.35)
		elseif entry.Box3DAdorn then
			entry.Box3DAdorn:Destroy()
			entry.Box3DAdorn = nil
		end

		if not entry.Billboard then
			local bb = Instance.new("BillboardGui")
			bb.AlwaysOnTop = true
			bb.Size = UDim2.fromOffset(220, 44)
			bb.StudsOffset = Vector3.new(0, 3.4, 0)
			bb.Parent = ESPOverlay

			local lbl = Instance.new("TextLabel")
			lbl.Name = "InfoLabel"
			lbl.Size = UDim2.new(1, 0, 0, 22)
			lbl.BorderSizePixel = 0
			lbl.Parent = bb
			Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 4)

			local barBg = Instance.new("Frame")
			barBg.Name = "HealthBarBg"
			barBg.Size = UDim2.new(0.7, 0, 0, 5)
			barBg.Position = UDim2.new(0.15, 0, 0, 25)
			barBg.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
			barBg.BorderSizePixel = 0
			barBg.Parent = bb

			local barFill = Instance.new("Frame")
			barFill.Name = "Fill"
			barFill.Size = UDim2.fromScale(1, 1)
			barFill.BorderSizePixel = 0
			barFill.Parent = barBg

			entry.Billboard = bb
		end

		local bb = entry.Billboard :: BillboardGui
		bb.Adornee = data.Adornee
		bb.Enabled = visible
		local lbl = bb:FindFirstChild("InfoLabel") :: TextLabel
		lbl.Text = data.Label
		lbl.Font = self.Font
		lbl.TextSize = self.TextSize
		lbl.TextColor3 = data.Color
		lbl.BackgroundColor3 = Color3.fromRGB(12, 10, 22)
		lbl.BackgroundTransparency = self.ShowBackground and 0.35 or 1

		local barBg = bb:FindFirstChild("HealthBarBg") :: Frame
		barBg.Visible = self.ShowHealthBar and (data.HealthPct ~= nil)
		if data.HealthPct then
			local fill = barBg:FindFirstChild("Fill") :: Frame
			fill.Size = UDim2.fromScale(data.HealthPct, 1)
			fill.BackgroundColor3 = Color3.fromHSV(data.HealthPct * 0.33, 0.85, 0.95)
		end

		if self.Tracer then
			local screenPos, onScreen = Camera:WorldToViewportPoint(data.Adornee.Position)
			if onScreen and visible then
				if not entry.TracerLine then
					local line = Instance.new("Frame")
					line.AnchorPoint = Vector2.new(0.5, 0.5)
					line.BorderSizePixel = 0
					line.Parent = ESPOverlay
					entry.TracerLine = line
				end
				local origin2D = Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y)
				local target2D = Vector2.new(screenPos.X, screenPos.Y)
				local diff = target2D - origin2D
				local line = entry.TracerLine :: Frame
				line.Visible = true
				line.BackgroundColor3 = data.Color
				line.BackgroundTransparency = 1 - self.Opacity
				line.Size = UDim2.fromOffset(diff.Magnitude, self.Thickness)
				line.Position = UDim2.fromOffset((origin2D.X + target2D.X) * 0.5, (origin2D.Y + target2D.Y) * 0.5)
				line.Rotation = math.deg(math.atan2(diff.Y, diff.X))
			elseif entry.TracerLine then
				entry.TracerLine.Visible = false
			end
		elseif entry.TracerLine then
			entry.TracerLine:Destroy()
			entry.TracerLine = nil
		end
	end
end

addSectionHeader(TabESP, "Master ESP Controls")
local espMasterToggle = addToggle(TabESP, "ESP", "Enable ESP System", false, function(v)
	ESPManager.Enabled = v
	if not v then ESPManager:ClearAll() end
end)
addToggle(TabESP, "ESP", "Player ESP", true, function(v) ESPManager.ShowPlayers = v end)
addToggle(TabESP, "ESP", "NPC ESP", false, function(v) ESPManager.ShowNPCs = v end)
addToggle(TabESP, "ESP", "Object / Item ESP", false, function(v) ESPManager.ShowItems = v end)
addToggle(TabESP, "ESP", "Highlight Chams ESP", true, function(v) ESPManager.HighlightMode = v end)
addToggle(TabESP, "ESP", "3D Bounding Box ESP", false, function(v) ESPManager.Box3D = v end)
addToggle(TabESP, "ESP", "Tracer Lines ESP", false, function(v) ESPManager.Tracer = v end)
addToggle(TabESP, "ESP", "Raycast Visibility Check", false, function(v) ESPManager.VisibilityCheck = v end)

addSectionHeader(TabESP, "Display & Styling")
addToggle(TabESP, "ESP", "Show Names", true, function(v) ESPManager.ShowNames = v end)
addToggle(TabESP, "ESP", "Show Health Text", true, function(v) ESPManager.ShowHealth = v end)
addToggle(TabESP, "ESP", "Show Health Bar", true, function(v) ESPManager.ShowHealthBar = v end)
addToggle(TabESP, "ESP", "Show Distance", true, function(v) ESPManager.ShowDistance = v end)
addToggle(TabESP, "ESP", "Show Team Tag", true, function(v) ESPManager.ShowTeam = v end)
addToggle(TabESP, "ESP", "Label Dark Background", true, function(v) ESPManager.ShowBackground = v end)
addSlider(TabESP, "ESP", "ESP Max Range (Studs)", 100, 5000, 1000, 0, function(v) ESPManager.MaxRange = v end)
addSlider(TabESP, "ESP", "ESP Opacity", 0.1, 1.0, 0.85, 2, function(v) ESPManager.Opacity = v end)
addSlider(TabESP, "ESP", "ESP Text Size", 10, 22, 13, 0, function(v) ESPManager.TextSize = v end)
addDropdown(TabESP, "ESP", "Color Preset", { "Default (Green/Rose)", "Cyber Violet", "High Contrast" }, 1, function(opt)
	if opt == "Cyber Violet" then
		ESPManager.FriendlyColor = Color3.fromRGB(168, 85, 247)
		ESPManager.EnemyColor = Color3.fromRGB(244, 114, 182)
	elseif opt == "High Contrast" then
		ESPManager.FriendlyColor = Color3.fromRGB(0, 255, 255)
		ESPManager.EnemyColor = Color3.fromRGB(255, 255, 0)
	else
		ESPManager.FriendlyColor = Color3.fromRGB(52, 211, 153)
		ESPManager.EnemyColor = Color3.fromRGB(244, 63, 94)
	end
end)
addButton(TabESP, "ESP", "Reset ESP Configuration", function()
	espMasterToggle:Set(false)
	ESPManager:Reset()
end)

local MovementManager = {
	WalkSpeed = 16,
	JumpPower = 50,
	SprintSpeed = 32,
	IsSprinting = false,
	FlyEnabled = false,
	FlySpeed = 60,
	NoclipEnabled = false,
	InfiniteJump = false,
	MultiJumpMax = 1,
	JumpCount = 0,
	DashPower = 85,
	ClickTeleport = false,
	DefaultGravity = workspace.Gravity,
	FlyBV = nil :: BodyVelocity?,
	FlyBG = nil :: BodyGyro?,
	MobileAscend = false,
	MobileDescend = false,
}

local function getHumanoidAndRoot(): (Humanoid?, BasePart?)
	local char = LocalPlayer.Character
	if not char then return nil, nil end
	return char:FindFirstChildOfClass("Humanoid"), char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function MovementManager:SetFly(enabled: boolean)
	self.FlyEnabled = enabled
	local hum, root = getHumanoidAndRoot()
	if self.FlyBV then self.FlyBV:Destroy() self.FlyBV = nil end
	if self.FlyBG then self.FlyBG:Destroy() self.FlyBG = nil end

	if enabled and hum and root then
		hum.PlatformStand = true
		local bv = Instance.new("BodyVelocity")
		bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
		bv.Velocity = Vector3.zero
		bv.Parent = root
		self.FlyBV = bv

		local bg = Instance.new("BodyGyro")
		bg.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
		bg.P = 15000
		bg.CFrame = root.CFrame
		bg.Parent = root
		self.FlyBG = bg
	elseif hum then
		hum.PlatformStand = false
	end
end

function MovementManager:PerformDash()
	local hum, root = getHumanoidAndRoot()
	if not hum or not root then return end
	local moveDir = hum.MoveDirection.Magnitude > 0.05 and hum.MoveDirection.Unit or Camera.CFrame.LookVector
	root.AssemblyLinearVelocity = Vector3.new(moveDir.X * self.DashPower, math.max(root.AssemblyLinearVelocity.Y, 15), moveDir.Z * self.DashPower)
end

function MovementManager:ResetAll()
	self:SetFly(false)
	self.NoclipEnabled = false
	self.InfiniteJump = false
	self.MultiJumpMax = 1
	self.ClickTeleport = false
	self.WalkSpeed = 16
	self.JumpPower = 50
	workspace.Gravity = self.DefaultGravity
	local hum = getHumanoidAndRoot()
	if hum then
		hum.WalkSpeed = 16
		hum.JumpPower = 50
	end
	NotificationManager:Push("Info", "Movement Reset", "Character movement and gravity restored.")
end

CleanupManager:TrackConnection(UserInputService.JumpRequest:Connect(function()
	local hum = getHumanoidAndRoot()
	if not hum then return end
	if MovementManager.InfiniteJump then
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
	elseif MovementManager.MultiJumpMax > 1 then
		local state = hum:GetState()
		if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
			if MovementManager.JumpCount < MovementManager.MultiJumpMax then
				MovementManager.JumpCount += 1
				hum:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end
	end
end))

CleanupManager:TrackConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not MovementManager.ClickTeleport then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		local _, root = getHumanoidAndRoot()
		if not root then return end
		local ray = Camera:ScreenPointToRay(input.Position.X, input.Position.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		if LocalPlayer.Character then params.FilterDescendantsInstances = { LocalPlayer.Character } end
		local res = workspace:Raycast(ray.Origin, ray.Direction * 1500, params)
		if res then
			root.CFrame = CFrame.new(res.Position + Vector3.new(0, 3.5, 0))
		end
	end
end))

local MobileActionPad = Instance.new("Frame")
MobileActionPad.Name = "MobileMovementPad"
MobileActionPad.Size = UDim2.fromOffset(170, 52)
MobileActionPad.Position = UDim2.new(1, -18, 1, -140)
MobileActionPad.AnchorPoint = Vector2.new(1, 1)
MobileActionPad.BackgroundTransparency = 1
MobileActionPad.Visible = IsMobile
MobileActionPad.Parent = ScreenGui

local function makeMobileCircleBtn(text: string, posX: number): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(48, 48)
	b.Position = UDim2.fromOffset(posX, 0)
	b.BackgroundColor3 = ThemeManager.Colors.Sidebar
	b.BackgroundTransparency = 0.2
	b.Font = ThemeManager.BoldFont
	b.TextSize = 12
	b.TextColor3 = ThemeManager.Colors.AccentBright
	b.Text = text
	b.Parent = MobileActionPad
	Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
	local st = Instance.new("UIStroke")
	st.Color = ThemeManager.Colors.Accent
	st.Thickness = 1.4
	st.Parent = b
	return b
end

local MobileDashBtn = makeMobileCircleBtn("DASH", 0)
local MobileUpBtn = makeMobileCircleBtn("UP", 58)
local MobileDownBtn = makeMobileCircleBtn("DN", 116)

CleanupManager:TrackConnection(MobileDashBtn.MouseButton1Click:Connect(function() MovementManager:PerformDash() end))
CleanupManager:TrackConnection(MobileUpBtn.InputBegan:Connect(function() MovementManager.MobileAscend = true end))
CleanupManager:TrackConnection(MobileUpBtn.InputEnded:Connect(function() MovementManager.MobileAscend = false end))
CleanupManager:TrackConnection(MobileDownBtn.InputBegan:Connect(function() MovementManager.MobileDescend = true end))
CleanupManager:TrackConnection(MobileDownBtn.InputEnded:Connect(function() MovementManager.MobileDescend = false end))

addSectionHeader(TabMovement, "Speed & Jump Controllers")
addSlider(TabMovement, "MOVEMENT", "WalkSpeed", 4, 250, 16, 0, function(v)
	MovementManager.WalkSpeed = v
	local hum = getHumanoidAndRoot()
	if hum then hum.WalkSpeed = v end
end)
addSlider(TabMovement, "MOVEMENT", "JumpPower", 10, 300, 50, 0, function(v)
	MovementManager.JumpPower = v
	local hum = getHumanoidAndRoot()
	if hum then
		hum.UseJumpPower = true
		hum.JumpPower = v
	end
end)
addSlider(TabMovement, "MOVEMENT", "World Gravity", 0, 400, math.floor(workspace.Gravity), 0, function(v) workspace.Gravity = v end)
addToggle(TabMovement, "MOVEMENT", "Sprint Mode (Hold LeftShift / Toggle)", false, function(v)
	MovementManager.IsSprinting = v
	local hum = getHumanoidAndRoot()
	if hum then hum.WalkSpeed = v and MovementManager.SprintSpeed or MovementManager.WalkSpeed end
end)
addSlider(TabMovement, "MOVEMENT", "Sprint Speed", 20, 200, 32, 0, function(v) MovementManager.SprintSpeed = v end)

addSectionHeader(TabMovement, "Aerial & Physics Abilities")
local flyToggle = addToggle(TabMovement, "MOVEMENT", "Fly Mode (WASD + Space/Ctrl or Mobile UP/DN)", false, function(v)
	MovementManager:SetFly(v)
end)
addSlider(TabMovement, "MOVEMENT", "Fly Speed", 10, 300, 60, 0, function(v) MovementManager.FlySpeed = v end)
addToggle(TabMovement, "MOVEMENT", "Noclip (Private Map Testing)", false, function(v) MovementManager.NoclipEnabled = v end)
addToggle(TabMovement, "MOVEMENT", "Infinite Air Jump", false, function(v) MovementManager.InfiniteJump = v end)
addDropdown(TabMovement, "MOVEMENT", "Multi-Jump Mode", { "Single Jump", "Double Jump", "Triple Jump" }, 1, function(opt)
	MovementManager.MultiJumpMax = (opt == "Triple Jump" and 3) or (opt == "Double Jump" and 2) or 1
end)
addSlider(TabMovement, "MOVEMENT", "Dash Impulse Power", 30, 250, 85, 0, function(v) MovementManager.DashPower = v end)
addButton(TabMovement, "MOVEMENT", "Trigger Dash Impulse", function() MovementManager:PerformDash() end)
addToggle(TabMovement, "MOVEMENT", "Click / Tap Teleport", false, function(v) MovementManager.ClickTeleport = v end)
addToggle(TabMovement, "MOVEMENT", "Show Mobile Touch Action Buttons", IsMobile, function(v) MobileActionPad.Visible = v end)
addButton(TabMovement, "MOVEMENT", "Reset All Movement Settings", function()
	flyToggle:Set(false)
	MovementManager:ResetAll()
end)

local FreecamManager = {
	Enabled = false,
	Position = Vector3.zero,
	Velocity = Vector3.zero,
	Pitch = 0,
	Yaw = 0,
	Speed = 45,
	Acceleration = 10,
	Sensitivity = 0.28,
	FOV = 70,
	CollisionEnabled = false,
	HideGuiDuringFreecam = false,
	SavedCFrame = nil :: CFrame?,
	OriginalCameraType = Enum.CameraType.Custom,
	OriginalCameraSubject = nil :: Instance?,
	OriginalFOV = 70,
	TouchMoveVector = Vector2.zero,
	TouchElev = 0,
	CoordLabel = nil :: TextLabel?,
}

local FreecamMobileHUD = Instance.new("Frame")
FreecamMobileHUD.Name = "FreecamMobileHUD"
FreecamMobileHUD.Size = UDim2.fromScale(1, 1)
FreecamMobileHUD.BackgroundTransparency = 1
FreecamMobileHUD.Visible = false
FreecamMobileHUD.ZIndex = 90
FreecamMobileHUD.Parent = ScreenGui

local FcStickBase = Instance.new("Frame")
FcStickBase.Size = UDim2.fromOffset(110, 110)
FcStickBase.Position = UDim2.new(0, 28, 1, -138)
FcStickBase.BackgroundColor3 = ThemeManager.Colors.Sidebar
FcStickBase.BackgroundTransparency = 0.35
FcStickBase.Parent = FreecamMobileHUD
Instance.new("UICorner", FcStickBase).CornerRadius = UDim.new(1, 0)
Instance.new("UIStroke", FcStickBase).Color = ThemeManager.Colors.Accent

local FcStickKnob = Instance.new("Frame")
FcStickKnob.Size = UDim2.fromOffset(42, 42)
FcStickKnob.Position = UDim2.fromScale(0.5, 0.5)
FcStickKnob.AnchorPoint = Vector2.new(0.5, 0.5)
FcStickKnob.BackgroundColor3 = ThemeManager.Colors.Accent
FcStickKnob.Parent = FcStickBase
Instance.new("UICorner", FcStickKnob).CornerRadius = UDim.new(1, 0)

local FcUpBtn = Instance.new("TextButton")
FcUpBtn.Size = UDim2.fromOffset(52, 52)
FcUpBtn.Position = UDim2.new(1, -80, 1, -155)
FcUpBtn.BackgroundColor3 = ThemeManager.Colors.Sidebar
FcUpBtn.Font = ThemeManager.BoldFont
FcUpBtn.TextSize = 12
FcUpBtn.TextColor3 = Color3.new(1, 1, 1)
FcUpBtn.Text = "UP"
FcUpBtn.Parent = FreecamMobileHUD
Instance.new("UICorner", FcUpBtn).CornerRadius = UDim.new(1, 0)

local FcDownBtn = Instance.new("TextButton")
FcDownBtn.Size = UDim2.fromOffset(52, 52)
FcDownBtn.Position = UDim2.new(1, -80, 1, -92)
FcDownBtn.BackgroundColor3 = ThemeManager.Colors.Sidebar
FcDownBtn.Font = ThemeManager.BoldFont
FcDownBtn.TextSize = 12
FcDownBtn.TextColor3 = Color3.new(1, 1, 1)
FcDownBtn.Text = "DOWN"
FcDownBtn.Parent = FreecamMobileHUD
Instance.new("UICorner", FcDownBtn).CornerRadius = UDim.new(1, 0)

CleanupManager:TrackConnection(FcUpBtn.InputBegan:Connect(function() FreecamManager.TouchElev = 1 end))
CleanupManager:TrackConnection(FcUpBtn.InputEnded:Connect(function() FreecamManager.TouchElev = 0 end))
CleanupManager:TrackConnection(FcDownBtn.InputBegan:Connect(function() FreecamManager.TouchElev = -1 end))
CleanupManager:TrackConnection(FcDownBtn.InputEnded:Connect(function() FreecamManager.TouchElev = 0 end))

do
	local stickTouch: InputObject? = nil
	local lookTouch: InputObject? = nil
	local lastLookPos: Vector3? = nil

	CleanupManager:TrackConnection(FcStickBase.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			stickTouch = input
		end
	end))

	CleanupManager:TrackConnection(UserInputService.InputBegan:Connect(function(input, gp)
		if not FreecamManager.Enabled or gp then return end
		if input.UserInputType == Enum.UserInputType.Touch and input ~= stickTouch and not lookTouch then
			lookTouch = input
			lastLookPos = input.Position
		end
	end))

	CleanupManager:TrackConnection(UserInputService.InputChanged:Connect(function(input)
		if not FreecamManager.Enabled then return end
		if input == stickTouch then
			local center = FcStickBase.AbsolutePosition + FcStickBase.AbsoluteSize * 0.5
			local delta = Vector2.new(input.Position.X - center.X, input.Position.Y - center.Y)
			local radius = FcStickBase.AbsoluteSize.X * 0.45
			local clamped = delta.Magnitude > radius and delta.Unit * radius or delta
			FcStickKnob.Position = UDim2.new(0.5, clamped.X, 0.5, clamped.Y)
			FreecamManager.TouchMoveVector = Vector2.new(clamped.X / radius, -clamped.Y / radius)
		elseif input == lookTouch and lastLookPos then
			local delta = input.Position - lastLookPos
			lastLookPos = input.Position
			FreecamManager.Yaw -= delta.X * FreecamManager.Sensitivity * 0.012
			FreecamManager.Pitch = math.clamp(FreecamManager.Pitch - delta.Y * FreecamManager.Sensitivity * 0.012, -1.52, 1.52)
		elseif input.UserInputType == Enum.UserInputType.MouseMovement and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
			FreecamManager.Yaw -= input.Delta.X * FreecamManager.Sensitivity * 0.01
			FreecamManager.Pitch = math.clamp(FreecamManager.Pitch - input.Delta.Y * FreecamManager.Sensitivity * 0.01, -1.52, 1.52)
		end
	end))

	CleanupManager:TrackConnection(UserInputService.InputEnded:Connect(function(input)
		if input == stickTouch then
			stickTouch = nil
			FcStickKnob.Position = UDim2.fromScale(0.5, 0.5)
			FreecamManager.TouchMoveVector = Vector2.zero
		elseif input == lookTouch then
			lookTouch = nil
			lastLookPos = nil
		end
	end))
end

function FreecamManager:SetEnabled(enable: boolean)
	if self.Enabled == enable then return end
	self.Enabled = enable

	if enable then
		self.OriginalCameraType = Camera.CameraType
		self.OriginalCameraSubject = Camera.CameraSubject
		self.OriginalFOV = Camera.FieldOfView
		self.Position = Camera.CFrame.Position
		local rx, ry, _ = Camera.CFrame:ToEulerAnglesYXZ()
		self.Pitch = rx
		self.Yaw = ry
		self.Velocity = Vector3.zero

		local hum = getHumanoidAndRoot()
		if hum then
			hum.WalkSpeed = 0
			hum.JumpPower = 0
		end

		Camera.CameraType = Enum.CameraType.Scriptable
		FreecamMobileHUD.Visible = IsMobile
		if self.HideGuiDuringFreecam then
			FloatingManager:SetMainVisible(false)
		end
		NotificationManager:Push("Info", "Freecam Active", "Right-Click drag + WASD or Mobile Touch HUD.")
	else
		Camera.CameraType = self.OriginalCameraType
		if self.OriginalCameraSubject then
			Camera.CameraSubject = self.OriginalCameraSubject
		end
		Camera.FieldOfView = self.OriginalFOV
		FreecamMobileHUD.Visible = false

		local hum = getHumanoidAndRoot()
		if hum then
			hum.WalkSpeed = MovementManager.WalkSpeed
			hum.JumpPower = MovementManager.JumpPower
		end
		NotificationManager:Push("Info", "Freecam Restored", "Original player camera restored.")
	end
end

function FreecamManager:Step(dt: number)
	if not self.Enabled then return end
	Camera.CameraType = Enum.CameraType.Scriptable

	local rotCFrame = CFrame.fromEulerAnglesYXZ(self.Pitch, self.Yaw, 0)
	local moveInput = Vector3.new(self.TouchMoveVector.X, self.TouchElev, -self.TouchMoveVector.Y)

	if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveInput += Vector3.new(0, 0, -1) end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveInput += Vector3.new(0, 0, 1) end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveInput += Vector3.new(-1, 0, 0) end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveInput += Vector3.new(1, 0, 0) end
	if UserInputService:IsKeyDown(Enum.KeyCode.E) or UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveInput += Vector3.new(0, 1, 0) end
	if UserInputService:IsKeyDown(Enum.KeyCode.Q) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveInput += Vector3.new(0, -1, 0) end

	local speedMult = 1
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then speedMult = 2.6 end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) then speedMult = 0.35 end

	local targetVel = Vector3.zero
	if moveInput.Magnitude > 0.01 then
		targetVel = rotCFrame:VectorToWorldSpace(moveInput.Unit) * (self.Speed * speedMult)
	end

	self.Velocity = self.Velocity:Lerp(targetVel, math.clamp(dt * self.Acceleration, 0, 1))
	local nextPos = self.Position + self.Velocity * dt

	if self.CollisionEnabled and self.Velocity.Magnitude > 0.05 then
		local res = workspace:Raycast(self.Position, nextPos - self.Position)
		if res then
			nextPos = res.Position + res.Normal * 1.2
			self.Velocity = Vector3.zero
		end
	end

	self.Position = nextPos
	Camera.CFrame = CFrame.new(self.Position) * rotCFrame
	Camera.FieldOfView = self.FOV

	if self.CoordLabel then
		self.CoordLabel.Text = string.format("Freecam XYZ: %.1f, %.1f, %.1f", self.Position.X, self.Position.Y, self.Position.Z)
	end
end

CleanupManager:OnShutdown(function()
	if FreecamManager.Enabled then
		FreecamManager:SetEnabled(false)
	end
end)

addSectionHeader(TabFreecam, "Independent Freecam Controls")
local freecamToggle = addToggle(TabFreecam, "FREECAM", "Enable Freecam Mode (Shortcut: P)", false, function(v)
	FreecamManager:SetEnabled(v)
end)
addSlider(TabFreecam, "FREECAM", "Freecam Speed", 5, 300, 45, 0, function(v) FreecamManager.Speed = v end)
addSlider(TabFreecam, "FREECAM", "Smooth Acceleration", 1, 30, 10, 0, function(v) FreecamManager.Acceleration = v end)
addSlider(TabFreecam, "FREECAM", "Camera Look Sensitivity", 0.05, 1.5, 0.28, 2, function(v) FreecamManager.Sensitivity = v end)
addSlider(TabFreecam, "FREECAM", "Freecam FOV", 20, 120, 70, 0, function(v) FreecamManager.FOV = v end)
addToggle(TabFreecam, "FREECAM", "Camera Collision Prevention", false, function(v) FreecamManager.CollisionEnabled = v end)
addToggle(TabFreecam, "FREECAM", "Hide Main GUI During Freecam", false, function(v) FreecamManager.HideGuiDuringFreecam = v end)

local fcCoordRow = Instance.new("TextLabel")
fcCoordRow.Size = UDim2.new(1, 0, 0, 30)
fcCoordRow.Font = ThemeManager.BoldFont
fcCoordRow.TextSize = 12
fcCoordRow.Text = "Freecam XYZ: 0.0, 0.0, 0.0"
fcCoordRow.Parent = TabFreecam
ThemeManager:Bind(fcCoordRow, "BackgroundColor3", "Card")
ThemeManager:Bind(fcCoordRow, "TextColor3", "AccentBright")
Instance.new("UICorner", fcCoordRow).CornerRadius = UDim.new(0, 8)
FreecamManager.CoordLabel = fcCoordRow

addButton(TabFreecam, "FREECAM", "Save Current Camera Position", function()
	FreecamManager.SavedCFrame = Camera.CFrame
	NotificationManager:Push("Success", "Camera Saved", "Current camera CFrame bookmarked.")
end)
addButton(TabFreecam, "FREECAM", "Load Saved Camera Position", function()
	if not FreecamManager.SavedCFrame then
		NotificationManager:Push("Warning", "No Bookmark", "Save a camera position first.")
		return
	end
	if not FreecamManager.Enabled then freecamToggle:Set(true) end
	FreecamManager.Position = FreecamManager.SavedCFrame.Position
	local rx, ry, _ = FreecamManager.SavedCFrame:ToEulerAnglesYXZ()
	FreecamManager.Pitch = rx
	FreecamManager.Yaw = ry
end)
addButton(TabFreecam, "FREECAM", "Reset Freecam to Character", function()
	local _, root = getHumanoidAndRoot()
	if root then
		FreecamManager.Position = root.Position + Vector3.new(0, 6, 10)
	end
end)

local CombatTraining = {
	FOVCircleVisible = false,
	FOVRadius = 110,
	Difficulty = "Medium",
	Dummies = {} :: { Model },
	Hits = 0,
	Shots = 0,
	ReactionStart = 0,
	WaitingReaction = false,
	ScoreLabel = nil :: TextLabel?,
}

local FOVCircle = Instance.new("Frame")
FOVCircle.Name = "TrainingAimFOV"
FOVCircle.Size = UDim2.fromOffset(220, 220)
FOVCircle.Position = UDim2.fromScale(0.5, 0.5)
FOVCircle.AnchorPoint = Vector2.new(0.5, 0.5)
FOVCircle.BackgroundTransparency = 1
FOVCircle.Visible = false
FOVCircle.ZIndex = 50
FOVCircle.Parent = ScreenGui
Instance.new("UICorner", FOVCircle).CornerRadius = UDim.new(1, 0)
local FOVStroke = Instance.new("UIStroke")
FOVStroke.Color = ThemeManager.Colors.Accent
FOVStroke.Thickness = 1.5
FOVStroke.Parent = FOVCircle

function CombatTraining:ClearDummies()
	for _, d in ipairs(self.Dummies) do
		if d and d.Parent then d:Destroy() end
	end
	table.clear(self.Dummies)
end

function CombatTraining:SpawnDummies(count: number)
	self:ClearDummies()
	local _, root = getHumanoidAndRoot()
	local origin = root and root.Position or Vector3.new(0, 10, 0)

	for i = 1, count do
		local dummy = Instance.new("Model")
		dummy.Name = "PracticeDummy_" .. tostring(i)

		local torso = Instance.new("Part")
		torso.Name = "HumanoidRootPart"
		torso.Size = Vector3.new(2.2, 3, 1.2)
		torso.Color = ThemeManager.Colors.Accent
		torso.Material = Enum.Material.Neon
		torso.Anchored = true
		torso.CanCollide = true
		local angle = (i / count) * math.pi * 2
		torso.Position = origin + Vector3.new(math.cos(angle) * 24, 2, math.sin(angle) * 24)
		torso.Parent = dummy

		local head = Instance.new("Part")
		head.Name = "Head"
		head.Shape = Enum.PartType.Ball
		head.Size = Vector3.new(1.5, 1.5, 1.5)
		head.Color = ThemeManager.Colors.PinkGlow
		head.Material = Enum.Material.SmoothPlastic
		head.Anchored = true
		head.Position = torso.Position + Vector3.new(0, 2.3, 0)
		head.Parent = dummy

		local hum = Instance.new("Humanoid")
		hum.MaxHealth = 100
		hum.Health = 100
		hum.Parent = dummy

		local click = Instance.new("ClickDetector")
		click.MaxActivationDistance = 250
		click.Parent = dummy
		CleanupManager:TrackConnection(click.MouseClick:Connect(function()
			self.Hits += 1
			self.Shots += 1
			local spread = self.Difficulty == "Hard" and 36 or (self.Difficulty == "Medium" and 24 or 14)
			local newPos = origin + Vector3.new(math.random(-spread, spread), math.random(1, 6), math.random(-spread, spread))
			torso.Position = newPos
			head.Position = newPos + Vector3.new(0, 2.3, 0)
			if self.ScoreLabel then
				local acc = self.Shots > 0 and (self.Hits / self.Shots) * 100 or 100
				self.ScoreLabel.Text = string.format("Hits: %d | Shots: %d | Accuracy: %.1f%%", self.Hits, self.Shots, acc)
			end
		end))

		dummy.Parent = workspace
		table.insert(self.Dummies, dummy)
	end
	NotificationManager:Push("Success", "Practice Range", string.format("Spawned %d client practice dummies.", count))
end

CleanupManager:OnShutdown(function()
	CombatTraining:ClearDummies()
end)

addSectionHeader(TabCombat, "Authorized Practice Range")
addDropdown(TabCombat, "COMBAT TRAINING", "Training Difficulty", { "Easy", "Medium", "Hard" }, 2, function(opt)
	CombatTraining.Difficulty = opt
end)
addButton(TabCombat, "COMBAT TRAINING", "Spawn 5 Practice Dummies", function() CombatTraining:SpawnDummies(5) end)
addButton(TabCombat, "COMBAT TRAINING", "Clear Practice Dummies", function() CombatTraining:ClearDummies() end)
addToggle(TabCombat, "COMBAT TRAINING", "Show Aim Training FOV Circle", false, function(v)
	CombatTraining.FOVCircleVisible = v
	FOVCircle.Visible = v
end)
addSlider(TabCombat, "COMBAT TRAINING", "Aim FOV Circle Radius", 30, 300, 110, 0, function(v)
	CombatTraining.FOVRadius = v
	FOVCircle.Size = UDim2.fromOffset(v * 2, v * 2)
end)

local combatStatsLbl = Instance.new("TextLabel")
combatStatsLbl.Size = UDim2.new(1, 0, 0, 32)
combatStatsLbl.Font = ThemeManager.BoldFont
combatStatsLbl.TextSize = 12
combatStatsLbl.Text = "Hits: 0 | Shots: 0 | Accuracy: 100.0%"
combatStatsLbl.Parent = TabCombat
ThemeManager:Bind(combatStatsLbl, "BackgroundColor3", "Card")
ThemeManager:Bind(combatStatsLbl, "TextColor3", "AccentBright")
Instance.new("UICorner", combatStatsLbl).CornerRadius = UDim.new(0, 8)
CombatTraining.ScoreLabel = combatStatsLbl

addButton(TabCombat, "COMBAT TRAINING", "Run Reaction Time Drill", function()
	NotificationManager:Push("Warning", "Reaction Drill", "Wait 2 seconds, then click 'Record Reaction'!")
	CombatTraining.WaitingReaction = true
	task.delay(2, function()
		if CombatTraining.WaitingReaction then
			CombatTraining.ReactionStart = os.clock()
			NotificationManager:Push("Success", "CLICK NOW!", "Tap Record Reaction button immediately!")
		end
	end)
end)
addButton(TabCombat, "COMBAT TRAINING", "Record Reaction Click", function()
	if CombatTraining.ReactionStart > 0 then
		local ms = math.floor((os.clock() - CombatTraining.ReactionStart) * 1000)
		CombatTraining.ReactionStart = 0
		CombatTraining.WaitingReaction = false
		NotificationManager:Push("Success", "Reaction Result", string.format("Reaction Time: %d ms", ms))
	end
end)

local PlayerInfoManager = {
	SelectedPlayer = nil :: Player?,
	DetailsLabel = nil :: TextLabel?,
	ListContainer = nil :: Frame?,
}

addSectionHeader(TabPlayers, "Live Server Roster & Inspection")
local playerDetails = Instance.new("TextLabel")
playerDetails.Size = UDim2.new(1, 0, 0, 74)
playerDetails.Font = ThemeManager.Font
playerDetails.TextSize = 12
playerDetails.TextWrapped = true
playerDetails.TextXAlignment = Enum.TextXAlignment.Left
playerDetails.Text = "Select a player below to inspect Health, Position, Distance, Speed, and Team."
playerDetails.Parent = TabPlayers
ThemeManager:Bind(playerDetails, "BackgroundColor3", "Card")
ThemeManager:Bind(playerDetails, "TextColor3", "TextPrimary")
Instance.new("UICorner", playerDetails).CornerRadius = UDim.new(0, 8)
Instance.new("UIPadding", playerDetails).PaddingLeft = UDim.new(0, 10)
PlayerInfoManager.DetailsLabel = playerDetails

local rosterFrame = Instance.new("Frame")
rosterFrame.Size = UDim2.new(1, 0, 0, 0)
rosterFrame.AutomaticSize = Enum.AutomaticSize.Y
rosterFrame.BackgroundTransparency = 1
rosterFrame.Parent = TabPlayers
Instance.new("UIListLayout", rosterFrame).Padding = UDim.new(0, 6)
PlayerInfoManager.ListContainer = rosterFrame

function PlayerInfoManager:RefreshRoster()
	for _, child in ipairs(rosterFrame:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, 0, 0, 34)
		btn.Font = ThemeManager.BoldFont
		btn.TextSize = 12
		btn.Text = string.format("%s (@%s) • ID: %d", plr.DisplayName, plr.Name, plr.UserId)
		btn.Parent = rosterFrame
		ThemeManager:Bind(btn, "BackgroundColor3", "Card")
		ThemeManager:Bind(btn, "TextColor3", "TextPrimary")
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

		CleanupManager:TrackConnection(btn.MouseButton1Click:Connect(function()
			self.SelectedPlayer = plr
		end))
	end
end

addButton(TabPlayers, "PLAYERS", "Refresh Player List", function()
	PlayerInfoManager:RefreshRoster()
end)
PlayerInfoManager:RefreshRoster()

local RemoteFolder = ReplicatedStorage:WaitForChild("UltimateToolkitRemotes", 5)
local AdminActionRemote = RemoteFolder and RemoteFolder:FindFirstChild("AdminAction") :: RemoteEvent?
local AdminSyncRemote = RemoteFolder and RemoteFolder:FindFirstChild("AdminSync") :: RemoteEvent?
local AnnouncementRemote = RemoteFolder and RemoteFolder:FindFirstChild("ServerAnnouncement") :: RemoteEvent?
local DiagnosticsRemote = RemoteFolder and RemoteFolder:FindFirstChild("GetDiagnostics") :: RemoteFunction?
local SettingsRemote = RemoteFolder and RemoteFolder:FindFirstChild("ManageSettings") :: RemoteFunction?

local AdminInterface = {
	PermissionLevel = 0,
	SelectedTargetId = LocalPlayer.UserId,
	StatusLabel = nil :: TextLabel?,
	LogsLabel = nil :: TextLabel?,
}

local function sendAdminCommand(action: string, payload: { [string]: any }?)
	if not AdminActionRemote then
		NotificationManager:Push("Error", "Server Offline", "ToolkitServer script not found in ServerScriptService.")
		return
	end
	AdminActionRemote:FireServer(action, payload or {})
end

if AdminSyncRemote then
	CleanupManager:TrackConnection(AdminSyncRemote.OnClientEvent:Connect(function(eventType: string, arg1: any, arg2: any)
		if eventType == "AuthStatus" then
			AdminInterface.PermissionLevel = arg1
			if AdminInterface.StatusLabel then
				AdminInterface.StatusLabel.Text = string.format("Server Auth Rank: Level %d (Verified)", arg1)
			end
		elseif eventType == "Feedback" then
			NotificationManager:Push(arg1 and "Success" or "Error", "Admin Server", tostring(arg2))
		elseif eventType == "LogsUpdated" and typeof(arg1) == "table" and AdminInterface.LogsLabel then
			local lines = {}
			for i = 1, math.min(#arg1, 6) do
				local e = arg1[i]
				table.insert(lines, string.format("[%s] %s -> %s (%s)", e.Action, e.Admin, e.Target, e.Details))
			end
			AdminInterface.LogsLabel.Text = #lines > 0 and table.concat(lines, "
") or "No admin logs recorded yet."
		end
	end))
end

if AnnouncementRemote then
	CleanupManager:TrackConnection(AnnouncementRemote.OnClientEvent:Connect(function(sender: string, msg: string)
		NotificationManager:Push("Warning", "ANNOUNCEMENT • " .. tostring(sender), tostring(msg))
	end))
end

addSectionHeader(TabAdmin, "Server-Authoritative Admin Control")
local adminAuthLbl = Instance.new("TextLabel")
adminAuthLbl.Size = UDim2.new(1, 0, 0, 32)
adminAuthLbl.Font = ThemeManager.BoldFont
adminAuthLbl.TextSize = 12
adminAuthLbl.Text = "Server Auth Rank: Checking server allowlist..."
adminAuthLbl.Parent = TabAdmin
ThemeManager:Bind(adminAuthLbl, "BackgroundColor3", "Card")
ThemeManager:Bind(adminAuthLbl, "TextColor3", "AccentBright")
Instance.new("UICorner", adminAuthLbl).CornerRadius = UDim.new(0, 8)
AdminInterface.StatusLabel = adminAuthLbl

addTextInput(TabAdmin, "ADMIN", "Target Username or UserId...", "Select Target", function(txt)
	local num = tonumber(txt)
	if num then
		AdminInterface.SelectedTargetId = num
		NotificationManager:Push("Info", "Admin Target", "Selected UserId: " .. tostring(num))
		return
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		if string.find(string.lower(plr.Name), string.lower(txt), 1, true) then
			AdminInterface.SelectedTargetId = plr.UserId
			NotificationManager:Push("Info", "Admin Target", "Selected " .. plr.Name)
			return
		end
	end
	NotificationManager:Push("Warning", "Not Found", "No matching player in server.")
end)

addButton(TabAdmin, "ADMIN", "Heal Target Player", function() sendAdminCommand("Heal", { TargetId = AdminInterface.SelectedTargetId }) end)
addButton(TabAdmin, "ADMIN", "Respawn Target Player", function() sendAdminCommand("Respawn", { TargetId = AdminInterface.SelectedTargetId }) end)
addButton(TabAdmin, "ADMIN", "Freeze Target Player", function() sendAdminCommand("Freeze", { TargetId = AdminInterface.SelectedTargetId }) end)
addButton(TabAdmin, "ADMIN", "Unfreeze Target Player", function() sendAdminCommand("Unfreeze", { TargetId = AdminInterface.SelectedTargetId }) end)
addButton(TabAdmin, "ADMIN", "Teleport To Target", function() sendAdminCommand("TeleportTo", { TargetId = AdminInterface.SelectedTargetId }) end)
addButton(TabAdmin, "ADMIN", "Bring Target To Me", function() sendAdminCommand("Bring", { TargetId = AdminInterface.SelectedTargetId }) end)
addButton(TabAdmin, "ADMIN", "Kick Target Player", function()
	sendAdminCommand("Kick", { TargetId = AdminInterface.SelectedTargetId, Reason = "Removed via Admin Panel." })
end)

addSectionHeader(TabAdmin, "Environment & Broadcasts")
addTextInput(TabAdmin, "ADMIN", "Server announcement message...", "Broadcast", function(msg)
	sendAdminCommand("Announce", { Message = msg })
end)
addSlider(TabAdmin, "ADMIN", "Server ClockTime (Hours)", 0, 24, 14, 1, function(v)
	sendAdminCommand("SetClockTime", { ClockTime = v })
end)
addDropdown(TabAdmin, "ADMIN", "Server Weather Preset", { "Clear", "Foggy", "Midnight" }, 1, function(opt)
	sendAdminCommand("SetWeather", { Preset = opt })
end)
addTextInput(TabAdmin, "ADMIN", "Test Tool Name...", "Give Tool", function(toolName)
	sendAdminCommand("GiveTestTool", { TargetId = AdminInterface.SelectedTargetId, ToolName = toolName })
end)

addSectionHeader(TabAdmin, "Server Audit Log")
local logsBox = Instance.new("TextLabel")
logsBox.Size = UDim2.new(1, 0, 0, 96)
logsBox.Font = ThemeManager.Font
logsBox.TextSize = 11
logsBox.TextWrapped = true
logsBox.TextXAlignment = Enum.TextXAlignment.Left
logsBox.TextYAlignment = Enum.TextYAlignment.Top
logsBox.Text = "Click 'Sync Admin Logs' to fetch server audit history."
logsBox.Parent = TabAdmin
ThemeManager:Bind(logsBox, "BackgroundColor3", "Card")
ThemeManager:Bind(logsBox, "TextColor3", "TextMuted")
Instance.new("UICorner", logsBox).CornerRadius = UDim.new(0, 8)
Instance.new("UIPadding", logsBox).PaddingLeft = UDim.new(0, 8)
Instance.new("UIPadding", logsBox).PaddingTop = UDim.new(0, 6)
AdminInterface.LogsLabel = logsBox

addButton(TabAdmin, "ADMIN", "Sync Admin Logs & Permissions", function()
	sendAdminCommand("RequestSync", {})
end)

local VisualManager = {
	Fullbright = false,
	OrigBrightness = Lighting.Brightness,
	OrigClockTime = Lighting.ClockTime,
	OrigFogEnd = Lighting.FogEnd,
	OrigAmbient = Lighting.Ambient,
	CrosshairEnabled = false,
	PerfHUDEnabled = false,
}

local CrosshairFrame = Instance.new("Frame")
CrosshairFrame.Size = UDim2.fromOffset(18, 18)
CrosshairFrame.Position = UDim2.fromScale(0.5, 0.5)
CrosshairFrame.AnchorPoint = Vector2.new(0.5, 0.5)
CrosshairFrame.BackgroundTransparency = 1
CrosshairFrame.Visible = false
CrosshairFrame.Parent = ScreenGui

local ChH = Instance.new("Frame", CrosshairFrame)
ChH.Size = UDim2.fromOffset(16, 2)
ChH.Position = UDim2.fromScale(0.5, 0.5)
ChH.AnchorPoint = Vector2.new(0.5, 0.5)
ChH.BackgroundColor3 = ThemeManager.Colors.Accent

local ChV = Instance.new("Frame", CrosshairFrame)
ChV.Size = UDim2.fromOffset(2, 16)
ChV.Position = UDim2.fromScale(0.5, 0.5)
ChV.AnchorPoint = Vector2.new(0.5, 0.5)
ChV.BackgroundColor3 = ThemeManager.Colors.Accent

local PerfHUD = Instance.new("TextLabel")
PerfHUD.Size = UDim2.fromOffset(230, 28)
PerfHUD.Position = UDim2.new(0.5, 0, 0, 8)
PerfHUD.AnchorPoint = Vector2.new(0.5, 0)
PerfHUD.BackgroundColor3 = ThemeManager.Colors.Sidebar
PerfHUD.BackgroundTransparency = 0.2
PerfHUD.Font = ThemeManager.BoldFont
PerfHUD.TextSize = 11
PerfHUD.TextColor3 = ThemeManager.Colors.AccentBright
PerfHUD.Text = "FPS: 60 | Ping: 0ms | Mem: 0MB"
PerfHUD.Visible = false
PerfHUD.Parent = ScreenGui
Instance.new("UICorner", PerfHUD).CornerRadius = UDim.new(0, 8)

addSectionHeader(TabVisuals, "Lighting & Post-Processing")
addToggle(TabVisuals, "VISUALS", "Fullbright (Local Lighting Override)", false, function(v)
	VisualManager.Fullbright = v
	if v then
		Lighting.Brightness = 3
		Lighting.ClockTime = 14
		Lighting.FogEnd = 100000
		Lighting.GlobalShadows = false
		Lighting.Ambient = Color3.fromRGB(200, 200, 200)
	else
		Lighting.Brightness = VisualManager.OrigBrightness
		Lighting.ClockTime = VisualManager.OrigClockTime
		Lighting.FogEnd = VisualManager.OrigFogEnd
		Lighting.GlobalShadows = true
		Lighting.Ambient = VisualManager.OrigAmbient
	end
end)
addSlider(TabVisuals, "VISUALS", "Camera Field of View (FOV)", 30, 120, 70, 0, function(v)
	Camera.FieldOfView = v
end)
addSlider(TabVisuals, "VISUALS", "Local Brightness", 0, 6, 2, 1, function(v)
	Lighting.Brightness = v
end)
addToggle(TabVisuals, "VISUALS", "Custom Neon Crosshair", false, function(v)
	VisualManager.CrosshairEnabled = v
	CrosshairFrame.Visible = v
end)
addToggle(TabVisuals, "VISUALS", "Top Performance Monitor (FPS / Ping / Mem)", false, function(v)
	VisualManager.PerfHUDEnabled = v
	PerfHUD.Visible = v
end)
addButton(TabVisuals, "VISUALS", "Reset Visuals & Lighting", function()
	Lighting.Brightness = VisualManager.OrigBrightness
	Lighting.ClockTime = VisualManager.OrigClockTime
	Lighting.FogEnd = VisualManager.OrigFogEnd
	Lighting.Ambient = VisualManager.OrigAmbient
	Camera.FieldOfView = 70
	CrosshairFrame.Visible = false
end)

local CameraDirector = {
	Mode = "Default",
	OrbitAngle = 0,
	OrbitDistance = 16,
	OrbitHeight = 6,
	Keyframes = {} :: { CFrame },
	PlayingPath = false,
}

function CameraDirector:SetMode(mode: string)
	self.Mode = mode
	if mode == "Default" then
		Camera.CameraType = Enum.CameraType.Custom
		local hum = getHumanoidAndRoot()
		if hum then Camera.CameraSubject = hum end
	elseif mode == "FirstPerson" then
		Camera.CameraType = Enum.CameraType.Custom
		LocalPlayer.CameraMaxZoomDistance = 0.5
		LocalPlayer.CameraMinZoomDistance = 0.5
	else
		LocalPlayer.CameraMaxZoomDistance = 128
		LocalPlayer.CameraMinZoomDistance = 0.5
		Camera.CameraType = Enum.CameraType.Scriptable
	end
end

addSectionHeader(TabCamera, "Cinematic Camera Director")
addDropdown(TabCamera, "CAMERA", "Camera Angle Mode", { "Default", "Orbit", "TopDown", "SideView", "FirstPerson" }, 1, function(opt)
	CameraDirector:SetMode(opt)
end)
addSlider(TabCamera, "CAMERA", "Director Distance / Height", 5, 60, 16, 0, function(v)
	CameraDirector.OrbitDistance = v
	CameraDirector.OrbitHeight = v * 0.5
end)
addButton(TabCamera, "CAMERA", "Record Path Keyframe", function()
	table.insert(CameraDirector.Keyframes, Camera.CFrame)
	NotificationManager:Push("Success", "Camera Keyframe", "Total keyframes: " .. tostring(#CameraDirector.Keyframes))
end)
addButton(TabCamera, "CAMERA", "Play Recorded Camera Path", function()
	if #CameraDirector.Keyframes < 2 then
		NotificationManager:Push("Warning", "Need Keyframes", "Record at least 2 camera keyframes.")
		return
	end
	CameraDirector.PlayingPath = true
	Camera.CameraType = Enum.CameraType.Scriptable
	task.spawn(function()
		for i = 1, #CameraDirector.Keyframes - 1 do
			if not CameraDirector.PlayingPath then break end
			local startCF = CameraDirector.Keyframes[i]
			local endCF = CameraDirector.Keyframes[i + 1]
			local elapsed = 0
			while elapsed < 1.5 and CameraDirector.PlayingPath do
				elapsed += RunService.RenderStepped:Wait()
				Camera.CFrame = startCF:Lerp(endCF, math.clamp(elapsed / 1.5, 0, 1))
			end
		end
		CameraDirector.PlayingPath = false
		CameraDirector:SetMode("Default")
	end)
end)
addButton(TabCamera, "CAMERA", "Clear Path & Reset Camera", function()
	CameraDirector.PlayingPath = false
	table.clear(CameraDirector.Keyframes)
	CameraDirector:SetMode("Default")
end)

local ReplayManager = {
	IsRecording = false,
	IsPlaying = false,
	Paused = false,
	Speed = 1.0,
	Frames = {} :: { { Time: number, CF: CFrame } },
	StatusLabel = nil :: TextLabel?,
}

addSectionHeader(TabReplay, "Session Movement Recorder")
local replayStatus = Instance.new("TextLabel")
replayStatus.Size = UDim2.new(1, 0, 0, 32)
replayStatus.Font = ThemeManager.BoldFont
replayStatus.TextSize = 12
replayStatus.Text = "Replay Buffer: 0 frames (Client Local Capture)"
replayStatus.Parent = TabReplay
ThemeManager:Bind(replayStatus, "BackgroundColor3", "Card")
ThemeManager:Bind(replayStatus, "TextColor3", "AccentBright")
Instance.new("UICorner", replayStatus).CornerRadius = UDim.new(0, 8)
ReplayManager.StatusLabel = replayStatus

addButton(TabReplay, "REPLAY", "Start Recording Session", function()
	table.clear(ReplayManager.Frames)
	ReplayManager.IsRecording = true
	ReplayManager.IsPlaying = false
	NotificationManager:Push("Success", "Recording Started", "Capturing local character timeline.")
end)
addButton(TabReplay, "REPLAY", "Stop Recording", function()
	ReplayManager.IsRecording = false
	NotificationManager:Push("Info", "Recording Stopped", string.format("Captured %d frames.", #ReplayManager.Frames))
end)
addButton(TabReplay, "REPLAY", "Play Recorded Replay", function()
	if #ReplayManager.Frames < 2 then
		NotificationManager:Push("Warning", "Empty Replay", "Record a session first.")
		return
	end
	ReplayManager.IsRecording = false
	ReplayManager.IsPlaying = true
	ReplayManager.Paused = false
	task.spawn(function()
		local idx = 1
		while ReplayManager.IsPlaying and idx <= #ReplayManager.Frames do
			if not ReplayManager.Paused then
				local _, root = getHumanoidAndRoot()
				if root then
					root.CFrame = ReplayManager.Frames[idx].CF
				end
				idx += math.max(1, math.floor(ReplayManager.Speed))
			end
			RunService.Heartbeat:Wait()
		end
		ReplayManager.IsPlaying = false
		NotificationManager:Push("Info", "Replay Complete", "Playback finished.")
	end)
end)
addToggle(TabReplay, "REPLAY", "Pause Replay", false, function(v) ReplayManager.Paused = v end)
addSlider(TabReplay, "REPLAY", "Playback Speed Multiplier", 1, 5, 1, 0, function(v) ReplayManager.Speed = v end)
addButton(TabReplay, "REPLAY", "Delete Replay Buffer", function()
	ReplayManager.IsPlaying = false
	ReplayManager.IsRecording = false
	table.clear(ReplayManager.Frames)
	replayStatus.Text = "Replay Buffer: 0 frames"
end)

local WaypointManager = {
	Waypoints = {} :: { { Name: string, Category: string, CF: CFrame } },
	ListFrame = nil :: Frame?,
}

addSectionHeader(TabWaypoints, "Authorized Location Waypoints")
local wpList = Instance.new("Frame")
wpList.Size = UDim2.new(1, 0, 0, 0)
wpList.AutomaticSize = Enum.AutomaticSize.Y
wpList.BackgroundTransparency = 1
wpList.Parent = TabWaypoints
Instance.new("UIListLayout", wpList).Padding = UDim.new(0, 6)
WaypointManager.ListFrame = wpList

function WaypointManager:RefreshUI()
	for _, c in ipairs(wpList:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	for i, wp in ipairs(self.Waypoints) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 36)
		row.Parent = wpList
		ThemeManager:Bind(row, "BackgroundColor3", "Card")
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.62, 0, 1, 0)
		lbl.Position = UDim2.fromOffset(10, 0)
		lbl.BackgroundTransparency = 1
		lbl.Font = ThemeManager.Font
		lbl.TextSize = 11
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Text = string.format("%s (%.0f, %.0f, %.0f)", wp.Name, wp.CF.X, wp.CF.Y, wp.CF.Z)
		lbl.Parent = row
		ThemeManager:Bind(lbl, "TextColor3", "TextPrimary")

		local tpBtn = Instance.new("TextButton")
		tpBtn.Size = UDim2.fromOffset(48, 24)
		tpBtn.Position = UDim2.new(1, -62, 0.5, 0)
		tpBtn.AnchorPoint = Vector2.new(1, 0.5)
		tpBtn.Font = ThemeManager.BoldFont
		tpBtn.TextSize = 11
		tpBtn.Text = "TP"
		tpBtn.Parent = row
		ThemeManager:Bind(tpBtn, "BackgroundColor3", "Accent")
		tpBtn.TextColor3 = Color3.new(1, 1, 1)
		Instance.new("UICorner", tpBtn).CornerRadius = UDim.new(0, 6)
		CleanupManager:TrackConnection(tpBtn.MouseButton1Click:Connect(function()
			local _, root = getHumanoidAndRoot()
			if root then root.CFrame = wp.CF end
		end))

		local delBtn = Instance.new("TextButton")
		delBtn.Size = UDim2.fromOffset(46, 24)
		delBtn.Position = UDim2.new(1, -10, 0.5, 0)
		delBtn.AnchorPoint = Vector2.new(1, 0.5)
		delBtn.BackgroundColor3 = ThemeManager.Colors.Danger
		delBtn.Font = ThemeManager.BoldFont
		delBtn.TextSize = 11
		delBtn.Text = "DEL"
		delBtn.TextColor3 = Color3.new(1, 1, 1)
		delBtn.Parent = row
		Instance.new("UICorner", delBtn).CornerRadius = UDim.new(0, 6)
		CleanupManager:TrackConnection(delBtn.MouseButton1Click:Connect(function()
			table.remove(self.Waypoints, i)
			self:RefreshUI()
		end))
	end
end

addTextInput(TabWaypoints, "WAYPOINTS", "New Waypoint Name...", "Save Here", function(name)
	local _, root = getHumanoidAndRoot()
	if not root then return end
	local clean = #name > 0 and name or ("Waypoint #" .. tostring(#WaypointManager.Waypoints + 1))
	table.insert(WaypointManager.Waypoints, { Name = clean, Category = "Custom", CF = root.CFrame })
	WaypointManager:RefreshUI()
	NotificationManager:Push("Success", "Waypoint Saved", clean)
end)

local UtilityManager = {
	AntiAFK = false,
	AutoHeal = false,
	CoordDisplay = nil :: TextLabel?,
}

CleanupManager:TrackConnection(LocalPlayer.Idled:Connect(function()
	if UtilityManager.AntiAFK then
		local VirtualUser = game:GetService("VirtualUser")
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end
end))

addSectionHeader(TabUtilities, "Testing Utilities & Coordinates")
local liveCoordLbl = Instance.new("TextLabel")
liveCoordLbl.Size = UDim2.new(1, 0, 0, 32)
liveCoordLbl.Font = ThemeManager.BoldFont
liveCoordLbl.TextSize = 12
liveCoordLbl.Text = "Character XYZ: 0.0, 0.0, 0.0"
liveCoordLbl.Parent = TabUtilities
ThemeManager:Bind(liveCoordLbl, "BackgroundColor3", "Card")
ThemeManager:Bind(liveCoordLbl, "TextColor3", "AccentBright")
Instance.new("UICorner", liveCoordLbl).CornerRadius = UDim.new(0, 8)
UtilityManager.CoordDisplay = liveCoordLbl

addToggle(TabUtilities, "UTILITIES", "Anti-AFK (Authorized Idle Testing)", false, function(v) UtilityManager.AntiAFK = v end)
addToggle(TabUtilities, "UTILITIES", "Auto-Heal Character (Local Test)", false, function(v) UtilityManager.AutoHeal = v end)
addButton(TabUtilities, "UTILITIES", "Reset Local Character", function()
	local hum = getHumanoidAndRoot()
	if hum then hum.Health = 0 end
end)
addTextInput(TabUtilities, "UTILITIES", "Search Workspace Object/NPC...", "Locate", function(query)
	if #query == 0 then return end
	for _, inst in ipairs(workspace:GetDescendants()) do
		if string.find(string.lower(inst.Name), string.lower(query), 1, true) then
			local pos = inst:IsA("BasePart") and inst.Position or (inst:IsA("Model") and inst:GetPivot().Position)
			if pos then
				NotificationManager:Push("Info", "Located " .. inst.Name, string.format("XYZ: %.1f, %.1f, %.1f", pos.X, pos.Y, pos.Z))
				return
			end
		end
	end
	NotificationManager:Push("Warning", "Not Found", "No matching object in Workspace.")
end)

local DevTools = {
	CollisionDebug = false,
	DiagLabel = nil :: TextLabel?,
}

addSectionHeader(TabDeveloper, "Runtime & Server Diagnostics")
local devDiagLbl = Instance.new("TextLabel")
devDiagLbl.Size = UDim2.new(1, 0, 0, 86)
devDiagLbl.Font = ThemeManager.Font
devDiagLbl.TextSize = 11
devDiagLbl.TextWrapped = true
devDiagLbl.TextXAlignment = Enum.TextXAlignment.Left
devDiagLbl.Text = "Press 'Fetch Server Diagnostics' to query live server memory, instance count, and uptime."
devDiagLbl.Parent = TabDeveloper
ThemeManager:Bind(devDiagLbl, "BackgroundColor3", "Card")
ThemeManager:Bind(devDiagLbl, "TextColor3", "TextPrimary")
Instance.new("UICorner", devDiagLbl).CornerRadius = UDim.new(0, 8)
Instance.new("UIPadding", devDiagLbl).PaddingLeft = UDim.new(0, 10)
DevTools.DiagLabel = devDiagLbl

addButton(TabDeveloper, "DEVELOPER", "Fetch Server Diagnostics", function()
	if not DiagnosticsRemote then
		NotificationManager:Push("Error", "Unavailable", "Diagnostics RemoteFunction missing.")
		return
	end
	local data = DiagnosticsRemote:InvokeServer()
	if data and data.Authorized then
		devDiagLbl.Text = string.format(
			"Players: %d/%d | Workspace Instances: %d
Server Memory: %.1f MB | Uptime: %ds",
			data.PlayerCount, data.MaxPlayers, data.InstanceCount, data.ServerMemoryMB, data.UptimeSeconds
		)
	else
		NotificationManager:Push("Error", "Denied", "Server rejected diagnostics request.")
	end
end)

addButton(TabDeveloper, "DEVELOPER", "Scan ReplicatedStorage Remotes", function()
	local count = 0
	for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
		if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
			count += 1
		end
	end
	NotificationManager:Push("Info", "Remote Scan", string.format("Found %d Remotes in ReplicatedStorage.", count))
end)

addToggle(TabDeveloper, "DEVELOPER", "Show Collision Part Outlines", false, function(v)
	DevTools.CollisionDebug = v
	for _, part in ipairs(workspace:GetDescendants()) do
		if part:IsA("BasePart") then
			local box = part:FindFirstChild("ToolkitColDebug")
			if v and part.CanCollide and not box then
				local sel = Instance.new("SelectionBox")
				sel.Name = "ToolkitColDebug"
				sel.Adornee = part
				sel.Color3 = ThemeManager.Colors.Accent
				sel.LineThickness = 0.03
				sel.Parent = part
			elseif not v and box then
				box:Destroy()
			end
		end
	end
end)

local SettingsManager = {}

function SettingsManager:Serialize(): string
	local payload = {
		ThemePreset = ThemeManager.CurrentPreset,
		RGBMode = ThemeManager.RGBMode,
		UIScale = ThemeManager.UIScale,
		FloatSize = FloatingManager.Size,
		FloatTransparency = FloatingManager.Transparency,
		WalkSpeed = MovementManager.WalkSpeed,
		JumpPower = MovementManager.JumpPower,
		FreecamSpeed = FreecamManager.Speed,
		ESPRange = ESPManager.MaxRange,
	}
	return HttpService:JSONEncode(payload)
end

function SettingsManager:Deserialize(jsonStr: string)
	local ok, data = pcall(function()
		return HttpService:JSONDecode(jsonStr)
	end)
	if not ok or typeof(data) ~= "table" then
		NotificationManager:Push("Error", "Import Failed", "Invalid JSON configuration string.")
		return
	end
	if data.ThemePreset then ThemeManager:ApplyPreset(data.ThemePreset) end
	if typeof(data.RGBMode) == "boolean" then ThemeManager.RGBMode = data.RGBMode end
	if typeof(data.UIScale) == "number" then
		ThemeManager.UIScale = data.UIScale
		UIScaleObj.Scale = data.UIScale
	end
	if typeof(data.FloatSize) == "number" or typeof(data.FloatTransparency) == "number" then
		FloatingManager:UpdateAppearance(data.FloatSize, data.FloatTransparency)
	end
	if typeof(data.WalkSpeed) == "number" then MovementManager.WalkSpeed = data.WalkSpeed end
	if typeof(data.JumpPower) == "number" then MovementManager.JumpPower = data.JumpPower end
	if typeof(data.FreecamSpeed) == "number" then FreecamManager.Speed = data.FreecamSpeed end
	if typeof(data.ESPRange) == "number" then ESPManager.MaxRange = data.ESPRange end
	NotificationManager:Push("Success", "Config Applied", "Settings loaded successfully.")
end

addSectionHeader(TabSettings, "Theme & UI Customization")
addDropdown(TabSettings, "SETTINGS", "Purple Theme Preset", { "CyberViolet", "ObsidianOrchid", "AbyssalNebula" }, 1, function(opt)
	ThemeManager:ApplyPreset(opt)
end)
addToggle(TabSettings, "SETTINGS", "RGB Neon Accent Cycle", false, function(v)
	ThemeManager.RGBMode = v
end)
addSlider(TabSettings, "SETTINGS", "GUI Scale (Mobile / Desktop)", 0.65, 1.35, InitialScale, 2, function(v)
	ThemeManager.UIScale = v
	UIScaleObj.Scale = v
end)

addSectionHeader(TabSettings, "Floating Flower Reopen Button")
addSlider(TabSettings, "SETTINGS", "Floating Icon Size (px)", 42, 96, 58, 0, function(v)
	FloatingManager:UpdateAppearance(v, nil)
end)
addSlider(TabSettings, "SETTINGS", "Floating Icon Transparency", 0, 0.85, 0, 2, function(v)
	FloatingManager:UpdateAppearance(nil, v)
end)
addButton(TabSettings, "SETTINGS", "Reset Floating Icon Position", function()
	FloatingManager:ResetPosition()
	NotificationManager:Push("Info", "Floating Button", "Position reset to left-center margin.")
end)

addSectionHeader(TabSettings, "Configuration Persistence (DataStore + JSON)")
addButton(TabSettings, "SETTINGS", "Save Settings to Server DataStore", function()
	if not SettingsRemote then return end
	local ok, msg = SettingsRemote:InvokeServer("Save", SettingsManager:Serialize())
	NotificationManager:Push(ok and "Success" or "Error", "DataStore Save", tostring(msg))
end)
addButton(TabSettings, "SETTINGS", "Load Settings from Server DataStore", function()
	if not SettingsRemote then return end
	local ok, res = SettingsRemote:InvokeServer("Load")
	if ok then
		SettingsManager:Deserialize(res)
	else
		NotificationManager:Push("Warning", "DataStore Load", tostring(res))
	end
end)
local configExportBox = addTextInput(TabSettings, "SETTINGS", "Paste JSON config string here...", "Import JSON", function(txt)
	SettingsManager:Deserialize(txt)
end)
addButton(TabSettings, "SETTINGS", "Export Current Config to Input Box", function()
	configExportBox.Text = SettingsManager:Serialize()
	NotificationManager:Push("Info", "Exported", "JSON configuration copied into text box.")
end)

addSectionHeader(TabHome, "Welcome to Ultimate Developer & Admin Toolkit")
local homeBanner = Instance.new("TextLabel")
homeBanner.Size = UDim2.new(1, 0, 0, 68)
homeBanner.Font = ThemeManager.Font
homeBanner.TextSize = 12
homeBanner.TextWrapped = true
homeBanner.TextXAlignment = Enum.TextXAlignment.Left
homeBanner.Text = string.format(
	"User: %s (@%s) | Platform: %s
Toggle GUI: RightShift (PC) or Tap the Floating Flower Button anytime.",
	LocalPlayer.DisplayName, LocalPlayer.Name, IsMobile and "Mobile Touch" or "Desktop PC"
)
homeBanner.Parent = TabHome
ThemeManager:Bind(homeBanner, "BackgroundColor3", "Card")
ThemeManager:Bind(homeBanner, "TextColor3", "TextPrimary")
Instance.new("UICorner", homeBanner).CornerRadius = UDim.new(0, 8)
Instance.new("UIPadding", homeBanner).PaddingLeft = UDim.new(0, 12)

addButton(TabHome, "HOME", "Quick Toggle: Independent Freecam (P)", function()
	freecamToggle:Set(not FreecamManager.Enabled)
end)
addButton(TabHome, "HOME", "Quick Toggle: Player ESP System", function()
	espMasterToggle:Set(not ESPManager.Enabled)
end)
addButton(TabHome, "HOME", "Quick Toggle: Flight Mode", function()
	flyToggle:Set(not MovementManager.FlyEnabled)
end)

addSectionHeader(TabAbout, "Architecture & Security Documentation")
local aboutText = Instance.new("TextLabel")
aboutText.Size = UDim2.new(1, 0, 0, 150)
aboutText.Font = ThemeManager.Font
aboutText.TextSize = 12
aboutText.TextWrapped = true
aboutText.TextXAlignment = Enum.TextXAlignment.Left
aboutText.TextYAlignment = Enum.TextYAlignment.Top
aboutText.Text = "Roblox Ultimate All-in-One Developer & Admin Toolkit (" .. CONFIG.VERSION .. ")

"
	.. "• Architecture: Unified Client LocalScript + Server-Authoritative Security Script.
"
	.. "• Security: Strict server-side UserId allowlists, rate limiting, argument validation, and audit logging.
"
	.. "• Persistence: Cross-session saving powered by server-side DataStoreService + portable JSON export.
"
	.. "• Branding: Custom Flower Header Logo & Persistent Circular Floating Reopen Icon."
aboutText.Parent = TabAbout
ThemeManager:Bind(aboutText, "BackgroundColor3", "Card")
ThemeManager:Bind(aboutText, "TextColor3", "TextPrimary")
Instance.new("UICorner", aboutText).CornerRadius = UDim.new(0, 8)
Instance.new("UIPadding", aboutText).PaddingLeft = UDim.new(0, 12)
Instance.new("UIPadding", aboutText).PaddingTop = UDim.new(0, 10)

CleanupManager:TrackConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == CONFIG.TOGGLE_KEY then
		FloatingManager:SetMainVisible(not FloatingManager.IsOpen)
	elseif input.KeyCode == CONFIG.FREECAM_KEY then
		freecamToggle:Set(not FreecamManager.Enabled)
	elseif input.KeyCode == Enum.KeyCode.LeftShift and not FreecamManager.Enabled then
		local hum = getHumanoidAndRoot()
		if hum then hum.WalkSpeed = MovementManager.SprintSpeed end
	end
end))

CleanupManager:TrackConnection(UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift and not FreecamManager.Enabled and not MovementManager.IsSprinting then
		local hum = getHumanoidAndRoot()
		if hum then hum.WalkSpeed = MovementManager.WalkSpeed end
	end
end))

local function onCharacterAdded(char: Model)
	local hum = char:WaitForChild("Humanoid", 5) :: Humanoid?
	if hum then
		hum.UseJumpPower = true
		hum.WalkSpeed = FreecamManager.Enabled and 0 or MovementManager.WalkSpeed
		hum.JumpPower = FreecamManager.Enabled and 0 or MovementManager.JumpPower
		CleanupManager:TrackConnection(hum.StateChanged:Connect(function(_, newState)
			if newState == Enum.HumanoidStateType.Landed then
				MovementManager.JumpCount = 0
			end
		end))
	end
	if MovementManager.FlyEnabled then
		task.defer(function()
			MovementManager:SetFly(true)
		end)
	end
end

if LocalPlayer.Character then
	onCharacterAdded(LocalPlayer.Character)
end
CleanupManager:TrackConnection(LocalPlayer.CharacterAdded:Connect(onCharacterAdded))

CleanupManager:TrackConnection(Players.PlayerAdded:Connect(function() PlayerInfoManager:RefreshRoster() end))
CleanupManager:TrackConnection(Players.PlayerRemoving:Connect(function(plr)
	if PlayerInfoManager.SelectedPlayer == plr then
		PlayerInfoManager.SelectedPlayer = nil
	end
	PlayerInfoManager:RefreshRoster()
end))

local lastHudUpdate = 0
local frameCounter = 0

CleanupManager:TrackConnection(RunService.RenderStepped:Connect(function(dt: number)
	frameCounter += 1

	if ThemeManager.RGBMode then
		local hue = (os.clock() * 0.15) % 1
		local rgbCol = Color3.fromHSV(hue, 0.75, 0.95)
		ThemeManager:SetAccent(rgbCol)
		FloatGlow.Color = rgbCol
	end

	if FreecamManager.Enabled then
		FreecamManager:Step(dt)
	elseif CameraDirector.Mode ~= "Default" and CameraDirector.Mode ~= "FirstPerson" and not CameraDirector.PlayingPath then
		local _, root = getHumanoidAndRoot()
		if root then
			if CameraDirector.Mode == "Orbit" then
				CameraDirector.OrbitAngle += dt * 0.8
				local offset = Vector3.new(math.cos(CameraDirector.OrbitAngle) * CameraDirector.OrbitDistance, CameraDirector.OrbitHeight, math.sin(CameraDirector.OrbitAngle) * CameraDirector.OrbitDistance)
				Camera.CFrame = CFrame.lookAt(root.Position + offset, root.Position)
			elseif CameraDirector.Mode == "TopDown" then
				Camera.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, CameraDirector.OrbitHeight * 2, 0.1), root.Position)
			elseif CameraDirector.Mode == "SideView" then
				Camera.CFrame = CFrame.lookAt(root.Position + Vector3.new(CameraDirector.OrbitDistance, 3, 0), root.Position)
			end
		end
	end

	local now = os.clock()
	if now - lastHudUpdate >= 0.1 then
		local elapsed = now - lastHudUpdate
		lastHudUpdate = now

		ESPManager:Update()

		local _, root = getHumanoidAndRoot()
		if root and UtilityManager.CoordDisplay then
			UtilityManager.CoordDisplay.Text = string.format("Character XYZ: %.1f, %.1f, %.1f", root.Position.X, root.Position.Y, root.Position.Z)
		end

		if VisualManager.PerfHUDEnabled then
			local fps = math.floor(frameCounter / math.max(elapsed, 0.001))
			local ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
			local mem = math.floor(Stats:GetTotalMemoryUsageMb())
			PerfHUD.Text = string.format("FPS: %d | Ping: %dms | Mem: %dMB", fps, ping, mem)
		end
		frameCounter = 0

		if PlayerInfoManager.SelectedPlayer and PlayerInfoManager.DetailsLabel then
			local p = PlayerInfoManager.SelectedPlayer
			local pHum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			local pRoot = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if pHum and pRoot then
				local dist = root and (pRoot.Position - root.Position).Magnitude or 0
				PlayerInfoManager.DetailsLabel.Text = string.format(
					"Name: %s (@%s) | Team: %s
Health: %.0f/%.0f | Speed: %.1f | Distance: %.1f studs
Position: %.1f, %.1f, %.1f",
					p.DisplayName, p.Name, p.Team and p.Team.Name or "None",
					pHum.Health, pHum.MaxHealth, pRoot.AssemblyLinearVelocity.Magnitude, dist,
					pRoot.Position.X, pRoot.Position.Y, pRoot.Position.Z
				)
			else
				PlayerInfoManager.DetailsLabel.Text = p.Name .. " is currently spawning or has no active character."
			end
		end
	end
end))

CleanupManager:TrackConnection(RunService.Heartbeat:Connect(function()
	local hum, root = getHumanoidAndRoot()

	if MovementManager.FlyEnabled and MovementManager.FlyBV and MovementManager.FlyBG and hum and root then
		local move = hum.MoveDirection
		local vert = 0
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) or MovementManager.MobileAscend then vert += 1 end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or MovementManager.MobileDescend then vert -= 1 end
		MovementManager.FlyBV.Velocity = (move * MovementManager.FlySpeed) + Vector3.new(0, vert * MovementManager.FlySpeed, 0)
		MovementManager.FlyBG.CFrame = Camera.CFrame
	end

	if MovementManager.NoclipEnabled and LocalPlayer.Character then
		for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
			end
		end
	end

	if UtilityManager.AutoHeal and hum and hum.Health > 0 and hum.Health < hum.MaxHealth then
		hum.Health = hum.MaxHealth
	end

	if ReplayManager.IsRecording and root then
		table.insert(ReplayManager.Frames, { Time = os.clock(), CF = root.CFrame })
		if ReplayManager.StatusLabel then
			ReplayManager.StatusLabel.Text = string.format("Replay Buffer: %d frames (Recording...)", #ReplayManager.Frames)
		end
	end
end))

task.defer(function()
	sendAdminCommand("RequestSync", {})
	NotificationManager:Push("Success", CONFIG.TOOLKIT_NAME, "Loaded successfully. Press RightShift or tap the Flower Icon.")
end)
