local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local UI = {}
local colors = {
	Background = Color3.fromRGB(13, 18, 27), Card = Color3.fromRGB(24, 32, 46),
	Border = Color3.fromRGB(50, 65, 85), White = Color3.fromRGB(243, 247, 255),
	Muted = Color3.fromRGB(160, 177, 198), Mint = Color3.fromRGB(78, 255, 191),
	Red = Color3.fromRGB(255, 68, 83), Gold = Color3.fromRGB(255, 199, 65),
}
local function make(class, parent, props)
	local object = Instance.new(class)
	for key, value in pairs(props or {}) do object[key] = value end
	object.Parent = parent
	return object
end
local function rounded(object, radius)
	make("UICorner", object, { CornerRadius = UDim.new(0, radius or 12) })
	return object
end
local function card(parent, props)
	props.BackgroundColor3 = colors.Card
	props.BorderSizePixel = 0
	local frame = rounded(make("Frame", parent, props))
	make("UIStroke", frame, { Color = colors.Border, Thickness = 1, Transparency = 0.3 })
	return frame
end
local function text(parent, value, size, position, dimensions, color, font)
	local weight = font == Enum.Font.GothamBlack and Enum.FontWeight.Heavy or (font == Enum.Font.GothamBold and Enum.FontWeight.Bold or Enum.FontWeight.Medium)
	return make("TextLabel", parent, {
		BackgroundTransparency = 1, Text = value, FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", weight),
		TextSize = size, TextColor3 = color or colors.White, Position = position,
		Size = dimensions, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
	})
end
local function button(parent, value, position, dimensions, color)
	local object = rounded(make("TextButton", parent, {
		Text = value, Position = position, Size = dimensions, BackgroundColor3 = color or colors.Border,
		TextColor3 = colors.White, FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold), TextSize = 15,
		BorderSizePixel = 0, AutoButtonColor = true, Selectable = true,
	}))
	return object
end
local function formatNumber(value)
	local result = tostring(math.floor(value or 0))
	while true do
		local replaced, count = result:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		result = replaced
		if count == 0 then return result end
	end
end
function UI.new(callbacks)
	local self = setmetatable({ Callbacks = callbacks, Category = "Skin", ItemRows = {}, Entries = {}, Tab = "Shop" }, { __index = UI })
	local gui = make("ScreenGui", Players.LocalPlayer:WaitForChild("PlayerGui"), { Name = "ButtonHUD", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 10 })
	self.Gui = gui
	self.Brand = text(gui, "DON'T PRESS\nTHE BUTTON.", 24, UDim2.fromOffset(22, 16), UDim2.fromOffset(210, 62), colors.White, Enum.Font.GothamBlack)
	self.Tagline = text(gui, "CURIOSITY HAS CONSEQUENCES", 10, UDim2.fromOffset(23, 80), UDim2.fromOffset(240, 20), colors.Muted)
	self.Stats = card(gui, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 18), Size = UDim2.fromOffset(292, 80) })
	self.Coins = text(self.Stats, "0 COINS", 19, UDim2.fromOffset(16, 12), UDim2.fromOffset(125, 28), colors.Gold, Enum.Font.GothamBold)
	self.Points = text(self.Stats, "0 POINTS", 19, UDim2.fromOffset(145, 12), UDim2.fromOffset(136, 28), colors.Mint, Enum.Font.GothamBold)
	self.Presses = text(self.Stats, "0 presses • 1x coins", 12, UDim2.fromOffset(16, 46), UDim2.fromOffset(265, 21), colors.Muted)
	self.Special = card(gui, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 20), Size = UDim2.fromOffset(410, 85) })
	self.SpecialTitle = text(self.Special, "THE NEXT BIG THING", 10, UDim2.fromOffset(16, 10), UDim2.fromOffset(370, 16), colors.Muted)
	self.Counter = text(self.Special, "99 presses to something special", 19, UDim2.fromOffset(16, 28), UDim2.fromOffset(380, 27), colors.Mint, Enum.Font.GothamBold)
	local track = rounded(make("Frame", self.Special, { Position = UDim2.fromOffset(16, 65), Size = UDim2.new(1, -32, 0, 5), BackgroundColor3 = colors.Border, BorderSizePixel = 0 }), 3)
	self.Progress = rounded(make("Frame", track, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = colors.Mint, BorderSizePixel = 0 }), 3)
	self.Event = card(gui, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 120), Size = UDim2.fromOffset(600, 78) })
	self.EventTitle = text(self.Event, "THE BUTTON IS WAITING", 19, UDim2.fromOffset(16, 10), UDim2.new(1, -32, 0, 25), colors.White, Enum.Font.GothamBold)
	self.EventDescription = text(self.Event, "One press. Thirteen possible regrets.", 13, UDim2.fromOffset(16, 39), UDim2.new(1, -32, 0, 32), colors.Muted)
	self.Navigation = make("Frame", gui, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, -24), Size = UDim2.fromOffset(148, 144), BackgroundTransparency = 1 })
	local shop = button(self.Navigation, "SHOP", UDim2.fromOffset(0, 0), UDim2.fromOffset(148, 42), colors.Card)
	local leaders = button(self.Navigation, "TOP PRESSERS", UDim2.fromOffset(0, 51), UDim2.fromOffset(148, 42), colors.Card)
	local emote = button(self.Navigation, "EMOTE", UDim2.fromOffset(0, 102), UDim2.fromOffset(148, 42), colors.Card)
	shop.Activated:Connect(function() self:open("Shop") end)
	leaders.Activated:Connect(function() self:open("Leaderboard") end)
	emote.Activated:Connect(callbacks.Emote)
	self.Press = button(gui, "PRESS IT ANYWAY", UDim2.new(0.5, 0, 1, -28), UDim2.fromOffset(340, 64), colors.Red)
	self.Press.AnchorPoint = Vector2.new(0.5, 1)
	self.Press.TextSize = 20
	self.Press.Activated:Connect(function() if not self.Panel.Visible then callbacks.Press() end end)
	self.Hint = text(gui, "Walk to the button • E / X / tap", 12, UDim2.new(0.5, 0, 1, -20), UDim2.fromOffset(400, 20), colors.Muted)
	self.Hint.AnchorPoint = Vector2.new(0.5, 0)
	self.Toast = card(gui, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -115), Size = UDim2.fromOffset(540, 48), Visible = false })
	self.ToastText = text(self.Toast, "", 14, UDim2.fromOffset(14, 4), UDim2.new(1, -28, 1, -8), colors.White)
	self.Countdown = text(gui, "", 82, UDim2.fromScale(0.5, 0.51), UDim2.fromOffset(200, 100), colors.Gold, Enum.Font.GothamBlack)
	self.Countdown.AnchorPoint = Vector2.new(0.5, 0.5)
	self.Countdown.TextXAlignment = Enum.TextXAlignment.Center
	self.Countdown.Visible = false
	self.Overlay = make("TextButton", gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.3, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 20 })
	self.Overlay.Activated:Connect(function() self:close() end)
	self.Panel = card(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(760, 510), Visible = false, ZIndex = 21 })
	self.PanelTitle = text(self.Panel, "BUTTON SHOP", 24, UDim2.fromOffset(20, 14), UDim2.new(1, -85, 0, 36), colors.White, Enum.Font.GothamBlack)
	self.PanelTitle.ZIndex = 22
	local close = button(self.Panel, "X", UDim2.new(1, -56, 0, 16), UDim2.fromOffset(36, 36))
	close.ZIndex = 22
	close.Activated:Connect(function() self:close() end)
	self.PanelSubtitle = text(self.Panel, "Spend Button Points. Bought items equip automatically.", 13, UDim2.fromOffset(20, 56), UDim2.new(1, -40, 0, 36), colors.Muted)
	self.PanelSubtitle.ZIndex = 22
	self.Tabs = make("ScrollingFrame", self.Panel, { Position = UDim2.fromOffset(20, 103), Size = UDim2.new(1, -40, 0, 40), BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.fromOffset(780, 0), ScrollingDirection = Enum.ScrollingDirection.X, ScrollBarThickness = 2, ZIndex = 22 })
	for i, category in ipairs(Catalog.Categories) do
		local tab = button(self.Tabs, category == "Multiplier" and "Boosts" or category .. "s", UDim2.fromOffset((i - 1) * 110, 0), UDim2.fromOffset(102, 34))
		tab.ZIndex = 23
		tab.Activated:Connect(function() self.Category = category; self:renderShop() end)
	end
	self.Clear = button(self.Panel, "UNEQUIP", UDim2.new(1, -132, 0, 150), UDim2.fromOffset(112, 28))
	self.Clear.ZIndex = 22
	self.Clear.TextSize = 11
	self.Clear.Activated:Connect(function() callbacks.Shop("Unequip", self.Category) end)
	self.Balance = text(self.Panel, "Loading progress...", 13, UDim2.fromOffset(20, 149), UDim2.new(1, -160, 0, 28), colors.Mint)
	self.Balance.ZIndex = 22
	self.List = make("ScrollingFrame", self.Panel, { Position = UDim2.fromOffset(20, 190), Size = UDim2.new(1, -40, 1, -210), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = colors.Mint, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 22 })
	make("UIListLayout", self.List, { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder })
	self:resize()
	return self
end
function UI:resize()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local size = camera.ViewportSize
	local compact = size.X < 1000
	self.Brand.Visible = not compact
	self.Tagline.Visible = not compact
	self.Stats.Size = UDim2.fromOffset(compact and math.min(292, size.X - 24) or 292, compact and 62 or 80)
	self.Stats.AnchorPoint = compact and Vector2.new(0.5, 0) or Vector2.new(1, 0)
	self.Stats.Position = compact and UDim2.new(0.5, 0, 0, 8) or UDim2.new(1, -20, 0, 18)
	self.Coins.Position = UDim2.fromOffset(12, compact and 3 or 12)
	self.Points.Position = UDim2.fromOffset(145, compact and 3 or 12)
	self.Presses.Position = UDim2.fromOffset(12, compact and 32 or 46)
	self.Special.Size = UDim2.fromOffset(math.min(410, size.X - 24), 85)
	self.Special.Position = UDim2.new(0.5, 0, 0, compact and 80 or 20)
	self.Counter.Size = UDim2.new(1, -32, 0, 27)
	self.Counter.TextSize = size.X < 420 and 16 or 19
	self.Event.Size = UDim2.fromOffset(math.min(600, size.X - 24), 78)
	self.Event.Position = UDim2.new(0.5, 0, 0, compact and 175 or 120)
	self.EventTitle.TextSize = size.X < 600 and 15 or 19
	local short = size.Y < 580
	self.Event.Visible = not (short and compact)
	self.Special.Visible = not (short and compact)
	self.Navigation.Position = UDim2.new(0, 12, 0.5, -15)
	self.Navigation.AnchorPoint = Vector2.new(0, 0)
	self.Navigation.Size = UDim2.fromOffset(148, 144)
	local navScale = self.Navigation:FindFirstChildOfClass("UIScale") or make("UIScale", self.Navigation)
	navScale.Scale = compact and 0.8 or 1
	self.Press.Size = UDim2.fromOffset(math.min(340, size.X - 32), compact and 52 or 64)
	self.Press.Position = UDim2.new(0.5, 0, 1, compact and -95 or -28)
	self.Hint.Position = UDim2.new(0.5, 0, 1, compact and -87 or -20)
	self.Toast.Position = UDim2.new(0.5, 0, 1, compact and -166 or -115)
	self.Toast.Size = UDim2.fromOffset(math.min(540, size.X - 24), 54)
	self.Panel.Size = UDim2.fromOffset(math.min(760, size.X - 24), math.min(510, size.Y - 32))
	self.PanelTitle.TextSize = size.X < 500 and 18 or 24
end
function UI:open(tab)
	self.Tab = tab
	self.Panel.Visible = true
	self.Overlay.Visible = true
	self.Press.Visible = false
	if tab == "Shop" then self:renderShop() else self:renderLeaders() end
end
function UI:close()
	self.Panel.Visible = false
	self.Overlay.Visible = false
	self.Press.Visible = true
end
function UI:clearList()
	for _, child in ipairs(self.List:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
end
function UI:renderShop()
	self.PanelTitle.Text = "BUTTON SHOP"
	self.PanelSubtitle.Text = "Spend Button Points. Bought items equip automatically."
	self.Tabs.Visible = true
	self.Clear.Visible = self.Category ~= "Multiplier"
	self.Balance.Visible = true
	self.List.Position = UDim2.fromOffset(20, 190)
	self.List.Size = UDim2.new(1, -40, 1, -210)
	self:clearList()
	local data = self.Data
	self.Balance.Text = data and (formatNumber(data.Points) .. " BUTTON POINTS") or "Loading progress..."
	for index, item in ipairs(Catalog.Items) do
		if item.Category == self.Category then
			local row = card(self.List, { Size = UDim2.new(1, -6, 0, 106), LayoutOrder = index, ZIndex = 23 })
			local owned = data and data.Owned[item.Id]
			local equipped = data and data.Equipped[item.Category] == item.Id
			local heading = text(row, item.Name, 16, UDim2.fromOffset(14, 10), UDim2.new(1, -145, 0, 25), item.Color and Color3.fromRGB(unpack(item.Color)) or colors.White, Enum.Font.GothamBold)
			heading.ZIndex = 24
			local description = text(row, item.Description, 12, UDim2.fromOffset(14, 40), UDim2.new(1, -145, 0, 54), colors.Muted)
			description.ZIndex = 24
			local label = equipped and "EQUIPPED" or (owned and (item.Category == "Multiplier" and "OWNED" or "EQUIP") or (item.Price .. " POINTS"))
			local buy = button(row, label, UDim2.new(1, -126, 0, 33), UDim2.fromOffset(112, 40), equipped and colors.Border or Color3.fromRGB(28, 100, 81))
			buy.ZIndex = 24
			buy.TextSize = 12
			buy.Activated:Connect(function() if self.Data then self.Callbacks.Shop("Buy", item.Id) end end)
		end
	end
end
function UI:profile(data, multiplier, persistent)
	self.Data = data
	self.Coins.Text = formatNumber(data.Coins) .. " COINS"
	self.Points.Text = formatNumber(data.Points) .. " POINTS"
	self.Presses.Text = formatNumber(data.Presses) .. " presses • " .. multiplier .. "x coins" .. (persistent and "" or " • practice")
	if self.Panel.Visible and self.Tab == "Shop" then self:renderShop() end
end
function UI:state(state)
	self.State = state
	self.Counter.Text = state.Special and "SPECIAL EVENT IS LIVE!" or (state.Remaining .. " presses to something special")
	self.Counter.TextColor3 = state.Special and colors.Gold or colors.Mint
	TweenService:Create(self.Progress, TweenInfo.new(0.3), { Size = UDim2.fromScale(state.Special and 1 or (Config.SpecialEvery - state.Remaining) / Config.SpecialEvery, 1) }):Play()
	self.EventTitle.Text = state.EventName
	self.EventTitle.TextColor3 = state.Special and colors.Gold or colors.White
	self.EventDescription.Text = state.EventDescription
end
function UI:tick(nearby)
	local state = self.State
	if not state then self.Press.Text = "LOADING..."; return end
	local remaining = math.max(0, state.ReadyAt - workspace:GetServerTimeNow())
	if remaining > 0 then
		self.Press.Text = (state.Special and "SPECIAL EVENT • " or "NEXT PRESS IN ") .. math.ceil(remaining) .. "s"
		self.Press.BackgroundColor3 = colors.Border
	elseif not nearby then
		self.Press.Text = "WALK UP TO THE BUTTON"
		self.Press.BackgroundColor3 = colors.Border
	else
		self.Press.Text = state.Cost > 0 and ("PRESS • " .. state.Cost .. " COINS") or "PRESS IT ANYWAY"
		self.Press.BackgroundColor3 = colors.Red
	end
end
function UI:toast(message, kind)
	self.ToastToken = (self.ToastToken or 0) + 1
	local token = self.ToastToken
	self.Toast.Visible = true
	self.ToastText.Text = message
	self.ToastText.TextColor3 = kind == "special" and colors.Gold or (kind == "good" and colors.Mint or colors.White)
	task.delay(4.5, function() if self.ToastToken == token then self.Toast.Visible = false end end)
end
function UI:leaders(entries, label)
	self.Entries = entries
	self.LeaderboardLabel = label
	if self.Panel.Visible and self.Tab == "Leaderboard" then self:renderLeaders() end
end
function UI:renderLeaders()
	self.PanelTitle.Text = "MOST BUTTON PRESSES"
	self.PanelSubtitle.Text = self.LeaderboardLabel or "The global leaderboard refreshes every minute."
	self.Tabs.Visible = false
	self.Clear.Visible = false
	self.Balance.Visible = false
	self.List.Position = UDim2.fromOffset(20, 105)
	self.List.Size = UDim2.new(1, -40, 1, -125)
	self:clearList()
	if #self.Entries == 0 then
		local row = card(self.List, { Size = UDim2.new(1, -6, 0, 75), ZIndex = 23 })
		text(row, "Your first press starts the story.", 16, UDim2.fromOffset(16, 15), UDim2.new(1, -32, 0, 45), colors.Muted).ZIndex = 24
	end
	for rank, entry in ipairs(self.Entries) do
		local row = card(self.List, { Size = UDim2.new(1, -6, 0, 65), LayoutOrder = rank, ZIndex = 23 })
		text(row, string.format("#%02d", rank), 19, UDim2.fromOffset(14, 16), UDim2.fromOffset(54, 30), rank <= 3 and colors.Gold or colors.Muted, Enum.Font.GothamBold).ZIndex = 24
		text(row, entry.Name, 15, UDim2.fromOffset(74, 15), UDim2.new(1, -188, 0, 35), colors.White).ZIndex = 24
		local score = text(row, formatNumber(entry.Presses), 16, UDim2.new(1, -112, 0, 16), UDim2.fromOffset(96, 30), colors.Mint, Enum.Font.GothamBold)
		score.TextXAlignment = Enum.TextXAlignment.Right
		score.ZIndex = 24
	end
end
return UI
