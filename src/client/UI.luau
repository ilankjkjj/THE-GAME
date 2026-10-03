local Players = game:GetService("Players")
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local UI = {}
local palette = {
	Paper = Color3.fromRGB(255, 253, 248), White = Color3.fromRGB(255, 255, 255),
	Ink = Color3.fromRGB(35, 49, 66), Muted = Color3.fromRGB(103, 119, 132),
	Line = Color3.fromRGB(221, 231, 232), Coral = Color3.fromRGB(241, 86, 81),
	CoralPale = Color3.fromRGB(255, 233, 226), CoralInk = Color3.fromRGB(180, 49, 43),
	CoralButton = Color3.fromRGB(218, 58, 54), Teal = Color3.fromRGB(0, 128, 120),
	TealPale = Color3.fromRGB(223, 247, 238), Gold = Color3.fromRGB(153, 96, 6),
	GoldPale = Color3.fromRGB(255, 241, 195), Lilac = Color3.fromRGB(111, 85, 190),
	LilacPale = Color3.fromRGB(239, 232, 255), Disabled = Color3.fromRGB(229, 235, 235),
}
local categoryIcons = { Skin = "●", Trail = "〰", Title = "Aa", Sound = "♪", Emote = "★", Pet = "◆", Multiplier = "×" }
local categoryLabels = { Skin = "Buttons", Trail = "Trails", Title = "Titles", Sound = "Sounds", Emote = "Emotes", Pet = "Pets", Multiplier = "Boosts" }
local function make(class, parent, props)
	local object = Instance.new(class)
	for key, value in pairs(props or {}) do object[key] = value end
	object.Parent = parent
	return object
end
local function round(object, radius)
	make("UICorner", object, { CornerRadius = UDim.new(0, radius or 16) })
	return object
end
local function card(parent, props, color)
	props.BackgroundColor3 = color or palette.White
	props.BorderSizePixel = 0
	local frame = round(make("Frame", parent, props))
	make("UIStroke", frame, { Color = palette.Line, Thickness = 1, Transparency = 0.15 })
	return frame
end
local function label(parent, value, size, position, dimensions, color, heavy)
	return make("TextLabel", parent, {
		BackgroundTransparency = 1, Text = value,
		FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", heavy and Enum.FontWeight.ExtraBold or Enum.FontWeight.Medium),
		TextSize = size, TextColor3 = color or palette.Ink, Position = position, Size = dimensions,
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
		ZIndex = parent:IsA("GuiObject") and parent.ZIndex + 1 or 2,
	})
end
local function button(parent, value, position, dimensions, color, ink)
	return round(make("TextButton", parent, {
		Text = value, Position = position, Size = dimensions, BackgroundColor3 = color or palette.Paper,
		TextColor3 = ink or palette.Ink, FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold),
		TextSize = 13, BorderSizePixel = 0, AutoButtonColor = true, Selectable = true,
		ZIndex = parent:IsA("GuiObject") and parent.ZIndex + 1 or 2,
	}), 12)
end
local function formatNumber(value)
	local result = tostring(math.floor(value or 0))
	while true do
		local replaced, count = result:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		result = replaced
		if count == 0 then return result end
	end
end
local function attr(name)
	local player = Players.LocalPlayer
	return player.GetAttribute and player:GetAttribute(name) or nil
end
local function timer(value)
	value = math.max(0, math.ceil(value))
	return string.format("%d:%02d", math.floor(value / 60), value % 60)
end
local function statusColor(status)
	if status == "Playing" then return palette.Teal, palette.TealPale end
	if status == "Queued" then return palette.Gold, palette.GoldPale end
	if status == "Eliminated" then return palette.Coral, palette.CoralPale end
	return palette.Muted, palette.Disabled
end
function UI.new(callbacks)
	local self = setmetatable({ Callbacks = callbacks, Category = "Skin", Entries = {}, Tab = "Shop", CategoryTabs = {}, CanPress = false }, { __index = UI })
	local gui = make("ScreenGui", Players.LocalPlayer:WaitForChild("PlayerGui"), {
		Name = "ButtonHUD", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 10,
	})
	self.Gui = gui
	self.Brand = make("Frame", gui, { Position = UDim2.fromOffset(20, 14), Size = UDim2.fromOffset(255, 54), BackgroundTransparency = 1 })
	local logo = card(self.Brand, { Size = UDim2.fromOffset(46, 46) }, palette.Coral)
	local logoText = label(logo, "!", 30, UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), palette.White, true)
	logoText.TextXAlignment = Enum.TextXAlignment.Center
	label(self.Brand, "DON'T PRESS", 18, UDim2.fromOffset(56, 0), UDim2.fromOffset(200, 23), palette.Ink, true)
	label(self.Brand, "THE BUTTON", 18, UDim2.fromOffset(56, 23), UDim2.fromOffset(200, 23), palette.Coral, true)
	self.Stats = card(gui, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 14), Size = UDim2.fromOffset(282, 62) }, palette.Paper)
	self.Coins = label(self.Stats, "0 COINS", 16, UDim2.fromOffset(14, 6), UDim2.fromOffset(116, 25), palette.Gold, true)
	self.Points = label(self.Stats, "0 POINTS", 16, UDim2.fromOffset(142, 6), UDim2.fromOffset(128, 25), palette.Teal, true)
	self.Presses = label(self.Stats, "0 wins  ·  0 presses", 11, UDim2.fromOffset(14, 34), UDim2.new(1, -28, 0, 18), palette.Muted)
	self.Round = card(gui, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(340, 62) }, palette.Paper)
	self.PhaseLabel = label(self.Round, "WELCOME TO THE LOBBY", 11, UDim2.fromOffset(14, 7), UDim2.new(1, -96, 0, 18), palette.Teal, true)
	self.RoundInfo = label(self.Round, "Join the next round", 14, UDim2.fromOffset(14, 29), UDim2.new(1, -96, 0, 23), palette.Ink, true)
	self.Timer = label(self.Round, "--:--", 24, UDim2.new(1, -83, 0, 10), UDim2.fromOffset(72, 39), palette.Ink, true)
	self.Timer.TextXAlignment = Enum.TextXAlignment.Right
	self.Event = card(gui, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 88), Size = UDim2.fromOffset(500, 66), BackgroundTransparency = 0.04 }, palette.Paper)
	self.EventMark = round(make("Frame", self.Event, { Position = UDim2.fromOffset(11, 11), Size = UDim2.fromOffset(5, 44), BackgroundColor3 = palette.Coral, BorderSizePixel = 0 }), 3)
	self.EventTitle = label(self.Event, "ONE BUTTON. EVERYONE FOR THEMSELVES.", 15, UDim2.fromOffset(28, 8), UDim2.new(1, -42, 0, 24), palette.Ink, true)
	self.EventDescription = label(self.Event, "Press for chaos. Stay alive to win.", 12, UDim2.fromOffset(28, 33), UDim2.new(1, -42, 0, 25), palette.Muted)
	self.Navigation = make("Frame", gui, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 18, 1, -20), Size = UDim2.fromOffset(288, 48), BackgroundTransparency = 1 })
	self.NavButtons = {}
	for index, specification in ipairs({ { "SHOP", "Shop", palette.TealPale, palette.Teal }, { "RANKS", "Leaderboard", palette.GoldPale, palette.Gold }, { "PLAYERS", "Roster", palette.LilacPale, palette.Lilac }, { "EMOTE", "Emote", palette.CoralPale, palette.CoralInk } }) do
		local nav = button(self.Navigation, specification[1], UDim2.fromOffset((index - 1) * 74, 0), UDim2.fromOffset(68, 44), specification[3], specification[4])
		nav.Activated:Connect(function()
			if specification[2] == "Emote" then if callbacks.Emote then callbacks.Emote() end
			elseif self.Panel.Visible and self.Tab == specification[2] then self:close()
			else self:open(specification[2]) end
		end)
		table.insert(self.NavButtons, nav)
	end
	self.Actions = make("Frame", gui, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -20), Size = UDim2.fromOffset(360, 58), BackgroundTransparency = 1 })
	self.Press = button(self.Actions, "PRESS FOR CHAOS", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), palette.CoralButton, palette.White)
	self.Press.TextSize = 20
	self.Press.Activated:Connect(function() if self.CanPress and not self.Panel.Visible then callbacks.Press() end end)
	self.Queue = button(self.Actions, "JOIN NEXT ROUND", UDim2.fromScale(0, 0), UDim2.new(0.65, -4, 1, 0), palette.Teal, palette.White)
	self.Queue.TextSize = 15
	self.Queue.Activated:Connect(function() if callbacks.Queue then callbacks.Queue() end end)
	self.Spectate = button(self.Actions, "WATCH", UDim2.new(0.65, 4, 0, 0), UDim2.new(0.35, -4, 1, 0), palette.LilacPale, palette.Lilac)
	self.Spectate.Visible = false
	self.Press.Visible = false
	self.Spectate.Activated:Connect(function() if callbacks.Spectate then callbacks.Spectate() end end)
	self.Hint = label(gui, "Press for chaos. Last survivor wins.", 12, UDim2.new(0.5, 0, 1, -85), UDim2.fromOffset(440, 23), palette.Ink, true)
	self.Hint.AnchorPoint = Vector2.new(0.5, 1)
	self.Hint.TextXAlignment = Enum.TextXAlignment.Center
	self.Hint.BackgroundColor3 = palette.Paper
	self.Hint.BackgroundTransparency = 0.08
	self.Hint.BorderSizePixel = 0
	round(self.Hint, 12)
	self.Health = card(gui, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -20), Size = UDim2.fromOffset(180, 48), Visible = false }, palette.Paper)
	self.HealthLabel = label(self.Health, "HEALTH 100", 11, UDim2.fromOffset(12, 5), UDim2.new(1, -24, 0, 18), palette.Teal, true)
	local healthTrack = round(make("Frame", self.Health, { Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -24, 0, 7), BackgroundColor3 = palette.Disabled, BorderSizePixel = 0 }), 4)
	self.HealthFill = round(make("Frame", healthTrack, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = palette.Teal, BorderSizePixel = 0 }), 4)
	self.Toast = card(gui, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -122), Size = UDim2.fromOffset(470, 46), Visible = false, ZIndex = 12 }, palette.Paper)
	self.ToastText = label(self.Toast, "", 13, UDim2.fromOffset(16, 6), UDim2.new(1, -32, 1, -12), palette.Ink, true)
	self.ToastText.TextXAlignment = Enum.TextXAlignment.Center
	self.Countdown = label(gui, "", 82, UDim2.fromScale(0.5, 0.45), UDim2.fromOffset(300, 110), palette.Coral, true)
	self.Countdown.AnchorPoint = Vector2.new(0.5, 0.5)
	self.Countdown.TextXAlignment = Enum.TextXAlignment.Center
	self.Countdown.TextStrokeColor3 = palette.White
	self.Countdown.TextStrokeTransparency = 0.25
	self.Countdown.Visible = false
	self.Countdown.ZIndex = 14
	self.Overlay = make("TextButton", gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(35, 66, 73), BackgroundTransparency = 0.45, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 20 })
	self.Overlay.Activated:Connect(function() self:close() end)
	self.Panel = card(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(710, 530), Visible = false, ZIndex = 21 }, palette.Paper)
	self.PanelTitle = label(self.Panel, "MAKE SOME TROUBLE", 25, UDim2.fromOffset(22, 16), UDim2.new(1, -86, 0, 33), palette.Ink, true)
	self.Close = button(self.Panel, "×", UDim2.new(1, -55, 0, 14), UDim2.fromOffset(37, 37), palette.CoralPale, palette.Coral)
	self.Close.TextSize = 24
	self.Close.Activated:Connect(function() self:close() end)
	self.PanelSubtitle = label(self.Panel, "Give your button a little personality.", 13, UDim2.fromOffset(22, 54), UDim2.new(1, -44, 0, 28), palette.Muted)
	self.Tabs = make("ScrollingFrame", self.Panel, { Position = UDim2.fromOffset(22, 94), Size = UDim2.new(1, -44, 0, 42), BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.fromOffset(755, 0), ScrollingDirection = Enum.ScrollingDirection.X, ScrollBarThickness = 2, ScrollBarImageColor3 = palette.Teal, ZIndex = 22 })
	for index, category in ipairs(Catalog.Categories) do
		local tab = button(self.Tabs, categoryLabels[category] or category, UDim2.fromOffset((index - 1) * 108, 0), UDim2.fromOffset(100, 36), palette.White, palette.Muted)
		tab.Activated:Connect(function() self.Category = category; self:renderShop() end)
		self.CategoryTabs[category] = tab
	end
	self.Balance = label(self.Panel, "YOUR POINTS: 0", 12, UDim2.fromOffset(22, 147), UDim2.new(1, -165, 0, 27), palette.Teal, true)
	self.Clear = button(self.Panel, "UNEQUIP", UDim2.new(1, -133, 0, 146), UDim2.fromOffset(111, 28), palette.Disabled, palette.Muted)
	self.Clear.TextSize = 10
	self.Clear.Activated:Connect(function() callbacks.Shop("Unequip", self.Category) end)
	self.List = make("ScrollingFrame", self.Panel, { Position = UDim2.fromOffset(22, 186), Size = UDim2.new(1, -44, 1, -206), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = palette.Teal, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 22 })
	make("UIListLayout", self.List, { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder })
	make("UIPadding", self.List, { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2), PaddingBottom = UDim.new(0, 4) })
	self:resize()
	return self
end
function UI:resize()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local size = camera.ViewportSize
	local phone = size.X < 640
	local short = size.Y < 520
	self.Phone, self.Short = phone, short
	self.Brand.Visible = size.X >= 1140 and not short
	local statsWidth = phone and math.min(360, size.X - 24) or (short and 250 or 282)
	self.Stats.Size = UDim2.fromOffset(statsWidth, phone and 40 or (short and 46 or 62))
	self.Stats.AnchorPoint = phone and Vector2.new(0.5, 0) or Vector2.new(1, 0)
	self.Stats.Position = phone and UDim2.new(0.5, 0, 0, 8) or UDim2.new(1, -14, 0, 12)
	self.Coins.Position = UDim2.fromOffset(12, 6)
	self.Coins.Size = UDim2.new(0.46, -12, 0, 26)
	self.Points.Position = UDim2.new(0.49, 0, 0, 6)
	self.Points.Size = UDim2.new(0.51, -12, 0, 26)
	self.Coins.TextSize, self.Points.TextSize = phone and 15 or 16, phone and 15 or 16
	self.Presses.Visible = not (phone or short)
	self.Round.Size = UDim2.fromOffset(phone and math.min(360, size.X - 24) or 340, phone and 50 or (short and 46 or 62))
	self.Round.AnchorPoint = phone and Vector2.new(0.5, 0) or ((size.X < 1140 or short) and Vector2.new(0, 0) or Vector2.new(0.5, 0))
	self.Round.Position = phone and UDim2.new(0.5, 0, 0, 57) or ((size.X < 1140 or short) and UDim2.fromOffset(14, 12) or UDim2.new(0.5, 0, 0, 14))
	self.PhaseLabel.Position = UDim2.fromOffset(14, short and 3 or 5)
	self.RoundInfo.Position = UDim2.fromOffset(14, short and 20 or (phone and 23 or 29))
	self.RoundInfo.TextSize = phone and 12 or (short and 12 or 14)
	self.Timer.Position = UDim2.new(1, -83, 0, short and 3 or 7)
	self.Timer.TextSize = phone and 23 or (short and 21 or 24)
	self.Event.Size = UDim2.fromOffset(math.min(short and 440 or 500, size.X - 24), short and 46 or 66)
	self.Event.Position = UDim2.new(0.5, 0, 0, phone and 117 or (short and 70 or 88))
	self.EventMark.Size = UDim2.fromOffset(5, short and 24 or 44)
	self.EventTitle.Position = UDim2.fromOffset(28, short and 5 or 8)
	self.EventTitle.Size = UDim2.new(1, -42, 0, short and 35 or 24)
	self.EventTitle.TextSize = phone and 13 or (short and 13 or 15)
	self.EventDescription.Visible = not short
	self.Navigation.AnchorPoint = phone and Vector2.new(0.5, 1) or Vector2.new(0, 1)
	self.Navigation.Position = phone and UDim2.new(0.5, 0, 1, -25) or UDim2.new(0, 12, 1, -16)
	local verticalNav = short and not phone and size.X < 780
	local navWidth = short and 240 or (phone and math.min(292, size.X - 36) or 288)
	self.Navigation.Size = verticalNav and UDim2.fromOffset(64, 170) or UDim2.fromOffset(navWidth, 44)
	if verticalNav then
		self.Navigation.AnchorPoint = Vector2.new(0, 0)
		self.Navigation.Position = UDim2.fromOffset(12, 126)
	end
	for index, nav in ipairs(self.NavButtons) do
		nav.Position = verticalNav and UDim2.new(0, 0, (index - 1) / 4, 0) or UDim2.new((index - 1) / 4, 0, 0, 0)
		nav.Size = verticalNav and UDim2.new(1, 0, 0.25, -6) or UDim2.new(0.25, -6, 1, 0)
		nav.TextSize = short and 10 or 11
	end
	self.Actions.Size = UDim2.fromOffset(short and 272 or math.min(360, size.X - 36), short and 48 or (phone and 52 or 58))
	self.Actions.Position = UDim2.new(0.5, 0, 1, phone and -100 or -16)
	self.Press.TextSize = phone and 17 or (short and 16 or 20)
	self.Queue.TextSize = phone and 13 or (short and 12 or 15)
	self.Spectate.TextSize = short and 11 or 12
	self.Hint.Size = UDim2.fromOffset(math.min(440, size.X - 32), 23)
	self.Hint.Position = UDim2.new(0.5, 0, 1, phone and -159 or (short and -69 or -81))
	self.Hint.TextSize = short and 10 or 11
	self.Health.AnchorPoint = phone and Vector2.new(0.5, 1) or Vector2.new(1, 1)
	self.Health.Position = phone and UDim2.new(0.5, 0, 1, -185) or UDim2.new(1, -12, 1, -16)
	self.Health.Size = UDim2.fromOffset(short and 138 or 180, short and 42 or 48)
	self.Toast.Position = UDim2.new(0.5, 0, 1, phone and -242 or (short and -102 or -118))
	self.Toast.Size = UDim2.fromOffset(math.min(470, size.X - 28), 46)
	self.Panel.Size = UDim2.fromOffset(math.min(710, size.X - 24), math.min(530, size.Y - 24))
	self.PanelTitle.TextSize = phone and 19 or (short and 20 or 25)
	if self.Panel.Visible then
		if self.Tab == "Shop" then self:renderShop()
		elseif self.Tab == "Roster" then self:renderRoster()
		else self:renderLeaders() end
	end
end
function UI:open(tab)
	self.Tab = tab
	self.Panel.Visible, self.Overlay.Visible = true, true
	self.Actions.Visible, self.Hint.Visible, self.Health.Visible = false, false, false
	if tab == "Shop" then self:renderShop()
	elseif tab == "Roster" then self:renderRoster()
	else self:renderLeaders() end
end
function UI:close()
	self.Panel.Visible, self.Overlay.Visible = false, false
	self.Actions.Visible, self.Hint.Visible = true, true
	self:tick(self.Nearby)
end
function UI:clearList()
	for _, child in ipairs(self.List:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
end
function UI:listLayout(shop)
	local compact = self.Short
	self.Tabs.Visible, self.Balance.Visible = shop, shop
	self.Clear.Visible = shop and self.Category ~= "Multiplier"
	if compact then
		self.PanelSubtitle.Visible = not shop
		self.Tabs.Position = UDim2.fromOffset(22, 59)
		self.Balance.Position = UDim2.fromOffset(22, 104)
		self.Clear.Position = UDim2.new(1, -133, 0, 103)
		self.List.Position = UDim2.fromOffset(22, shop and 141 or 92)
		self.List.Size = UDim2.new(1, -44, 1, shop and -158 or -112)
	else
		self.PanelSubtitle.Visible = true
		self.Tabs.Position = UDim2.fromOffset(22, 94)
		self.Balance.Position = UDim2.fromOffset(22, 147)
		self.Clear.Position = UDim2.new(1, -133, 0, 146)
		self.List.Position = UDim2.fromOffset(22, shop and 186 or 99)
		self.List.Size = UDim2.new(1, -44, 1, shop and -206 or -119)
	end
end
function UI:renderShop()
	self.PanelTitle.Text = "MAKE SOME TROUBLE"
	self.PanelSubtitle.Text = "Your style. Your chaos. Spend Button Points to make it yours."
	self:listLayout(true)
	self:clearList()
	local data = self.Data
	self.Balance.Text = "YOUR POINTS: " .. formatNumber(data and data.Points)
	for category, tab in pairs(self.CategoryTabs) do
		tab.BackgroundColor3 = category == self.Category and palette.Teal or palette.White
		tab.TextColor3 = category == self.Category and palette.White or palette.Muted
	end
	local narrow = self.Phone
	for index, item in ipairs(Catalog.Items) do
		if item.Category == self.Category then
			local row = card(self.List, { Size = UDim2.new(1, -6, 0, narrow and 142 or 104), LayoutOrder = index, ZIndex = 23 })
			local owned = data and data.Owned and data.Owned[item.Id]
			local equipped = data and data.Equipped and data.Equipped[item.Category] == item.Id
			local swatchColor = item.Color and Color3.fromRGB(unpack(item.Color)) or palette.LilacPale
			local swatch = round(make("Frame", row, { Position = UDim2.fromOffset(12, 14), Size = UDim2.fromOffset(54, 54), BackgroundColor3 = swatchColor, BorderSizePixel = 0, ZIndex = 24 }), 16)
			local icon = label(swatch, categoryIcons[item.Category] or "★", 25, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), palette.Ink, true)
			icon.TextXAlignment = Enum.TextXAlignment.Center
			label(row, item.Name, narrow and 14 or 16, UDim2.fromOffset(78, 11), UDim2.new(1, narrow and -90 or -206, 0, 30), palette.Ink, true)
			label(row, item.Description, 11, UDim2.fromOffset(78, 43), UDim2.new(1, narrow and -90 or -206, 0, narrow and 41 or 44), palette.Muted)
			local buyText = equipped and "EQUIPPED" or (owned and (item.Category == "Multiplier" and "OWNED" or "EQUIP") or (formatNumber(item.Price) .. " POINTS"))
			local affordable = owned or (data and (data.Points or 0) >= item.Price)
			local buy = button(row, buyText, narrow and UDim2.new(0, 12, 1, -45) or UDim2.new(1, -124, 0, 34), narrow and UDim2.new(1, -24, 0, 33) or UDim2.fromOffset(112, 38), equipped and palette.TealPale or (affordable and palette.Teal or palette.Disabled), equipped and palette.Teal or (affordable and palette.White or palette.Muted))
			buy.TextSize = 11
			buy.Activated:Connect(function() if self.Data then self.Callbacks.Shop("Buy", item.Id) end end)
		end
	end
end
function UI:profile(data, multiplier, _persistent)
	self.Data = data
	self.Coins.Text = formatNumber(data.Coins) .. " COINS"
	self.Points.Text = formatNumber(data.Points) .. " POINTS"
	self.Presses.Text = formatNumber(data.Wins) .. " wins  ·  " .. formatNumber(data.Presses) .. " presses  ·  " .. tostring(multiplier or 1) .. "× coins"
	if self.Panel.Visible and self.Tab == "Shop" then self:renderShop() end
end
function UI:state(state)
	local previous = self.State
	self.State = state
	local phase = state.Phase or "Waiting"
	self.PhaseLabel.Text = phase == "Round" and (state.SuddenDeath and "SUDDEN DEATH" or ("ROUND " .. tostring(state.RoundNumber or 1) .. "  ·  " .. tostring(state.EventCount or 0) .. " EVENTS")) or (phase == "Intermission" and "NEXT ROUND STARTS SOON" or (phase == "Results" and "ROUND COMPLETE" or "WELCOME TO THE LOBBY"))
	self.PhaseLabel.TextColor3 = phase == "Round" and palette.CoralInk or (phase == "Results" and palette.Gold or palette.Teal)
	self.RoundInfo.Text = phase == "Round" and (tostring(state.AliveCount or 0) .. " / " .. tostring(state.RoundPlayers or 0) .. " alive" .. (state.RoundMode == "Solo survival" and "  ·  SOLO" or "")) or (phase == "Results" and (state.Winner or "Round complete") or (tostring(state.QueuedCount or 0) .. " queued  ·  " .. tostring(state.LobbyCount or 0) .. " in lobby"))
	self.EventTitle.Text = state.EventName or "PRESS FOR CHAOS"
	self.EventDescription.Text = state.EventDescription or "The last survivor takes the crown."
	self.EventMark.BackgroundColor3 = phase == "Results" and palette.Gold or (phase == "Round" and palette.Coral or palette.Teal)
	self.Event.Visible = true
	if self.Panel.Visible and self.Tab == "Roster" then self:renderRoster() end
	if previous and state.EventId ~= previous.EventId and phase == "Round" and state.Presser and state.Presser ~= "" then
		self:toast(tostring(state.Presser) .. " pressed the button!", "event")
	end
	self:tick(self.Nearby)
end
function UI:spectating(name, atEnd)
	self.SpectatingName = name
	self.Spectate.Text = name and (atEnd and "STOP" or "NEXT >") or "WATCH"
end
function UI:tick(nearby)
	self.Nearby = nearby == true
	local state = self.State
	if not state then self.Press.Text = "LOADING..."; self.Press.Visible = false; return end
	local now = workspace:GetServerTimeNow()
	local inRound = attr("InRound") == true and (state.Phase or "Waiting") == "Round"
	local queued = attr("Queued") == true
	local phase = state.Phase or "Waiting"
	self.Hint.TextColor3 = palette.Ink
	local endsAt = phase == "Round" and state.RoundEndsAt or state.PhaseEndsAt
	self.Timer.Text = phase == "Round" and state.SuddenDeath and "OT" or (endsAt and endsAt > 0 and timer(endsAt - now) or "--:--")
	self.Press.Visible, self.Queue.Visible = inRound, not inRound
	self.Spectate.Visible = not inRound and phase == "Round" and (state.AliveCount or 0) > 0
	self.Queue.Size = self.Spectate.Visible and UDim2.new(0.65, -4, 1, 0) or UDim2.fromScale(1, 1)
	self.Queue.Text = queued and "QUEUED  ·  LEAVE" or "JOIN NEXT ROUND"
	self.Queue.BackgroundColor3 = queued and palette.GoldPale or palette.Teal
	self.Queue.TextColor3 = queued and palette.Gold or palette.White
	local remaining = math.max(0, (state.ReadyAt or 0) - now)
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local alive = humanoid and humanoid.Health > 0
	self.CanPress = inRound and not state.SuddenDeath and alive == true and self.Nearby and remaining <= 0
	self.Press.Active, self.Press.Selectable = self.CanPress, self.CanPress
	self.Press.AutoButtonColor = self.CanPress
	if state.SuddenDeath then self.Press.Text = "SURVIVE THE STORM"
	elseif remaining > 0 then self.Press.Text = "NEXT CHAOS IN " .. tostring(math.ceil(remaining)) .. "s"
	elseif not self.Nearby then self.Press.Text = "GET TO THE BUTTON"
	else self.Press.Text = "PRESS FOR CHAOS" end
	self.Press.BackgroundColor3 = self.CanPress and palette.CoralButton or palette.Disabled
	self.Press.TextColor3 = self.CanPress and palette.White or palette.Muted
	if inRound then
		local role = attr("Role")
		local threat = state.ThreatLevel
		local danger = state.SuddenDeath and "SUDDEN DEATH" or (threat and (type(threat) == "number" and ("CHAOS " .. tostring(threat) .. "/5") or tostring(threat)) or "STAY ALIVE")
		local eventHint = attr("EventHint")
		local eventTimer = attr("EventTimer")
		local instructions = eventHint and eventHint ~= "" and tostring(eventHint) or (self.Short and state.EventDescription or nil)
		self.Hint.Text = instructions and instructions ~= "" and instructions or (role and role ~= "" and (string.upper(tostring(role)) .. "  ·  " .. danger) or (danger .. "  ·  E / X / TAP TO PRESS"))
		if type(eventTimer) == "number" then
			self.Hint.Text = "BOMB " .. tostring(math.max(0, math.ceil(eventTimer - now))) .. "s  ·  " .. self.Hint.Text
		end
		self.Hint.TextColor3 = type(eventTimer) == "number" and palette.CoralInk or palette.Ink
	elseif self.SpectatingName then self.Hint.Text = "WATCHING " .. string.upper(self.SpectatingName) .. "  ·  WATCH TO SWITCH"
	elseif queued then self.Hint.Text = phase == "Round" and "You're in the next round. Watch the chaos while you wait." or "You're on the list. Get ready!"
	elseif attr("Status") == "Eliminated" then self.Hint.Text = "Out this round. Queue up for your comeback."
	else self.Hint.Text = "Join the next round. Last survivor wins." end
	self.Health.Visible = inRound and not self.Panel.Visible
	if humanoid then
		local fraction = math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1)
		self.HealthLabel.Text = "HEALTH " .. tostring(math.ceil(math.max(0, humanoid.Health)))
		self.HealthFill.Size = UDim2.fromScale(fraction, 1)
		local color = fraction < 0.3 and palette.CoralInk or (fraction < 0.6 and palette.Gold or palette.Teal)
		self.HealthFill.BackgroundColor3, self.HealthLabel.TextColor3 = color, color
	end
end
function UI:toast(message, kind)
	self.ToastToken = (self.ToastToken or 0) + 1
	local token = self.ToastToken
	self.Toast.Visible = true
	self.ToastText.Text = message
	self.ToastText.TextColor3 = kind == "good" and palette.Teal or (kind == "bad" and palette.CoralInk or palette.Ink)
	self.Toast.BackgroundColor3 = kind == "good" and palette.TealPale or (kind == "bad" and palette.CoralPale or palette.Paper)
	task.delay(4.5, function() if self.ToastToken == token then self.Toast.Visible = false end end)
end
function UI:leaders(entries, labelText)
	self.Entries = entries or {}
	self.LeaderboardLabel = labelText
	if self.Panel.Visible and self.Tab == "Leaderboard" then self:renderLeaders() end
end
function UI:renderLeaders()
	self.PanelTitle.Text = "HALL OF SURVIVORS"
	self.PanelSubtitle.Text = self.LeaderboardLabel or "Most survival wins. Outlast the chaos and climb the ranks."
	self:listLayout(false)
	self:clearList()
	if #self.Entries == 0 then
		local row = card(self.List, { Size = UDim2.new(1, -6, 0, 86), ZIndex = 23 }, palette.GoldPale)
		label(row, "Win a survival round. Start your legend.", 15, UDim2.fromOffset(18, 18), UDim2.new(1, -36, 0, 50), palette.Gold, true)
	end
	for rank, entry in ipairs(self.Entries) do
		local row = card(self.List, { Size = UDim2.new(1, -6, 0, 66), LayoutOrder = rank, ZIndex = 23 }, rank <= 3 and palette.GoldPale or palette.White)
		label(row, rank <= 3 and ("★ " .. rank) or ("#" .. rank), 18, UDim2.fromOffset(14, 15), UDim2.fromOffset(52, 35), rank <= 3 and palette.Gold or palette.Muted, true)
		label(row, entry.Name or "Player", self.Phone and 12 or 15, UDim2.fromOffset(72, 12), UDim2.new(1, -180, 0, 39), palette.Ink, true)
		local score = label(row, formatNumber(entry.Wins), 16, UDim2.new(1, -101, 0, 11), UDim2.fromOffset(85, 26), palette.Teal, true)
		score.TextXAlignment = Enum.TextXAlignment.Right
		local caption = label(row, "WINS", 9, UDim2.new(1, -101, 0, 36), UDim2.fromOffset(85, 15), palette.Muted)
		caption.TextXAlignment = Enum.TextXAlignment.Right
	end
end
function UI:renderRoster()
	self.PanelTitle.Text = "WHO'S STILL STANDING?"
	local state = self.State or {}
	self.PanelSubtitle.Text = tostring(state.AliveCount or 0) .. " survivors  ·  " .. tostring(state.LobbyCount or 0) .. " in lobby  ·  " .. tostring(state.QueuedCount or 0) .. " queued"
	self:listLayout(false)
	self:clearList()
	local survivors, lobby = {}, {}
	for _, entry in ipairs(state.Roster or {}) do table.insert(entry.Status == "Playing" and survivors or lobby, entry) end
	local order = 0
	for _, section in ipairs({ { "SURVIVORS", survivors, palette.TealPale, palette.Teal }, { "LOBBY & SPECTATORS", lobby, palette.LilacPale, palette.Lilac } }) do
		order += 1
		local header = card(self.List, { Size = UDim2.new(1, -6, 0, 34), LayoutOrder = order, ZIndex = 23 }, section[3])
		label(header, section[1] .. "  ·  " .. tostring(#section[2]), 11, UDim2.fromOffset(13, 4), UDim2.new(1, -26, 0, 26), section[4], true)
		if #section[2] == 0 then
			order += 1
			local empty = card(self.List, { Size = UDim2.new(1, -6, 0, 45), LayoutOrder = order, ZIndex = 23 })
			label(empty, section[1] == "SURVIVORS" and "The arena is waiting for its next contenders." or "Everyone's in the arena!", 11, UDim2.fromOffset(13, 4), UDim2.new(1, -26, 1, -8), palette.Muted)
		end
		for _, entry in ipairs(section[2]) do
			order += 1
			local row = card(self.List, { Size = UDim2.new(1, -6, 0, self.Phone and 81 or 72), LayoutOrder = order, ZIndex = 23 })
			local ink, tint = statusColor(entry.Status)
			local avatar = round(make("Frame", row, { Position = UDim2.fromOffset(12, 13), Size = UDim2.fromOffset(39, 39), BackgroundColor3 = tint, BorderSizePixel = 0, ZIndex = 24 }), 20)
			local initial = label(avatar, string.upper(string.sub(entry.Name or "?", 1, 1)), 19, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), ink, true)
			initial.TextXAlignment = Enum.TextXAlignment.Center
			local playerName = (entry.Name or "Player") .. (entry.UserId == Players.LocalPlayer.UserId and " (YOU)" or "")
			label(row, playerName, self.Phone and 12 or 14, UDim2.fromOffset(62, 10), UDim2.new(1, -160, 0, 27), palette.Ink, true)
			local role = entry.Role and entry.Role ~= "" and ("  ·  " .. tostring(entry.Role)) or ""
			label(row, tostring(entry.Status or "Lobby") .. role, 10, UDim2.fromOffset(62, 39), UDim2.new(1, -160, 0, 24), ink)
			local score = label(row, tostring(entry.Wins or 0) .. " WINS", 11, UDim2.new(1, -93, 0, 13), UDim2.fromOffset(78, 23), palette.Gold, true)
			score.TextXAlignment = Enum.TextXAlignment.Right
			local presses = label(row, formatNumber(entry.Presses) .. " presses", 9, UDim2.new(1, -99, 0, 39), UDim2.fromOffset(84, 23), palette.Muted)
			presses.TextXAlignment = Enum.TextXAlignment.Right
		end
	end
end
return UI
