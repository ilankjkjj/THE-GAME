local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local UI = {}
local palette = {
	Paper = Color3.fromRGB(255, 252, 246), White = Color3.fromRGB(255, 255, 255),
	Ink = Color3.fromRGB(37, 48, 69), Muted = Color3.fromRGB(100, 114, 135),
	Line = Color3.fromRGB(216, 228, 237), Coral = Color3.fromRGB(247, 107, 94),
	CoralPale = Color3.fromRGB(255, 232, 223), CoralInk = Color3.fromRGB(167, 54, 43),
	CoralButton = Color3.fromRGB(209, 62, 57), Teal = Color3.fromRGB(0, 126, 111),
	TealPale = Color3.fromRGB(221, 248, 236), Gold = Color3.fromRGB(143, 91, 8),
	GoldPale = Color3.fromRGB(255, 238, 182), Lilac = Color3.fromRGB(88, 97, 182),
	LilacPale = Color3.fromRGB(233, 236, 255), Disabled = Color3.fromRGB(229, 235, 241),
}
local supplyIcons = { medkit = "+", soda = ">>", spring = "↑", shield = "◇" }
local function make(class, parent, props)
	local object = Instance.new(class)
	for key, value in pairs(props or {}) do object[key] = value end
	object.Parent = parent
	return object
end
local function round(object, radius)
	make("UICorner", object, { CornerRadius = UDim.new(0, radius or 12) })
	return object
end
local function card(parent, props, color)
	props.BackgroundColor3 = color or palette.White
	props.BorderSizePixel = 0
	local frame = round(make("Frame", parent, props))
	make("UIStroke", frame, { Color = palette.Line, Thickness = 1.2, Transparency = 0.1 })
	return frame
end
local function label(parent, value, size, position, dimensions, color, heavy)
	return make("TextLabel", parent, {
		BackgroundTransparency = 1, Text = value,
		FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", heavy and Enum.FontWeight.Bold or Enum.FontWeight.Medium),
		TextSize = size, TextColor3 = color or palette.Ink, Position = position, Size = dimensions,
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
		ZIndex = parent:IsA("GuiObject") and parent.ZIndex + 1 or 2,
	})
end
local function button(parent, value, position, dimensions, color, ink)
	local object = round(make("TextButton", parent, {
		Text = value, Position = position, Size = dimensions, BackgroundColor3 = color or palette.Paper,
		TextColor3 = ink or palette.Ink, FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
		TextSize = 13, BorderSizePixel = 0, AutoButtonColor = true, Selectable = true,
		ZIndex = parent:IsA("GuiObject") and parent.ZIndex + 1 or 2,
	}), 10)
	make("UIStroke", object, { Color = palette.Line, Thickness = 1.2, Transparency = 0.15, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
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
local function compactNumber(value)
	value = math.max(0, value or 0)
	if value >= 1000000 then return string.format("%.1fm", value / 1000000) end
	if value >= 10000 then return string.format("%.1fk", value / 1000) end
	return formatNumber(value)
end
local function sameText(a, b)
	if type(a) ~= "string" or type(b) ~= "string" then return false end
	local function normalized(value) return string.lower(value):gsub("%s+", " "):match("^%s*(.-)%s*$") end
	return normalized(a) == normalized(b)
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
local function initialOf(name)
	name = name ~= "" and name or "?"
	local nextCharacter = utf8.offset(name, 2)
	return string.upper(string.sub(name, 1, nextCharacter and nextCharacter - 1 or #name))
end
local function eventColor(category, intensity)
	category = string.lower(tostring(category or ""))
	if category == "role" or category == "chase" then return palette.Lilac, palette.LilacPale end
	if category == "relief" or (tonumber(intensity) or 2) <= 1 then return palette.Teal, palette.TealPale end
	return palette.CoralInk, palette.CoralPale
end
function UI.new(callbacks)
	local self = setmetatable({ Callbacks = callbacks, Entries = {}, Tab = "Shop", CanPress = false }, { __index = UI })
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local previous = playerGui:FindFirstChild("ButtonHUD")
	if previous then previous:Destroy() end
	local gui = make("ScreenGui", playerGui, {
		Name = "ButtonHUD", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 10,
	})
	self.Gui = gui
	self.Stats = card(gui, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 78), Size = UDim2.fromOffset(180, 31) }, palette.Paper)
	self.Tokens = label(self.Stats, "0 Tokens", 14, UDim2.fromOffset(10, 3), UDim2.new(1, -20, 0, 24), palette.Gold, true)
	self.Round = card(gui, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 12), Size = UDim2.fromOffset(180, 60) }, palette.Paper)
	self.PhaseLabel = label(self.Round, "LOBBY", 9, UDim2.fromOffset(10, 6), UDim2.new(1, -76, 0, 16), palette.Teal, true)
	self.RoundInfo = label(self.Round, "Join the next round", 11, UDim2.fromOffset(10, 26), UDim2.new(1, -20, 0, 25), palette.Ink, true)
	self.Timer = label(self.Round, "--:--", 21, UDim2.new(1, -69, 0, 3), UDim2.fromOffset(59, 25), palette.Ink, true)
	self.Timer.TextXAlignment = Enum.TextXAlignment.Right
	self.Event = card(gui, { Position = UDim2.fromOffset(14, 12), Size = UDim2.fromOffset(340, 96), BackgroundTransparency = 0.04 }, palette.Paper)
	self.EventMark = round(make("Frame", self.Event, { Position = UDim2.fromOffset(9, 10), Size = UDim2.new(0, 4, 1, -20), BackgroundColor3 = palette.Coral, BorderSizePixel = 0 }), 3)
	self.EventTitle = label(self.Event, "DON'T PRESS THE BUTTON", 13, UDim2.fromOffset(21, 8), UDim2.new(1, -32, 0, 21), palette.Ink, true)
	self.EventDescription = label(self.Event, "Join the queue. Outlast the chaos.", 11, UDim2.fromOffset(21, 32), UDim2.new(1, -34, 0, 40), palette.Muted)
	self.EventDescription.TextYAlignment = Enum.TextYAlignment.Top
	self.Hint = label(self.Event, "", 10, UDim2.fromOffset(21, 75), UDim2.new(1, -34, 0, 16), palette.Teal, true)
	self.Hint.Visible = false
	self.Stack = make("Frame", gui, { Position = UDim2.fromOffset(14, 114), Size = UDim2.fromOffset(200, 84), BackgroundTransparency = 1, Visible = false })
	self.ActiveCards = {}
	for index = 1, 3 do
		local row = card(self.Stack, { Position = UDim2.fromOffset(0, (index - 1) * 28), Size = UDim2.new(1, 0, 0, 24), Visible = false })
		local name = label(row, "", 11, UDim2.fromOffset(9, 2), UDim2.new(1, -53, 1, -4), palette.Ink, true)
		name.TextWrapped, name.TextTruncate = false, Enum.TextTruncate.AtEnd
		local clock = label(row, "", 11, UDim2.new(1, -42, 0, 2), UDim2.fromOffset(34, 20), palette.Muted, true)
		clock.TextXAlignment = Enum.TextXAlignment.Right
		table.insert(self.ActiveCards, { Frame = row, Name = name, Timer = clock })
	end
	self.Navigation = make("Frame", gui, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -14), Size = UDim2.fromOffset(252, 35), BackgroundTransparency = 1 })
	self.NavButtons = {}
	for index, specification in ipairs({ { "SHOP", "Shop", palette.TealPale, palette.Teal }, { "WINS", "Leaderboard", palette.GoldPale, palette.Gold }, { "PLAYERS", "Roster", palette.LilacPale, palette.Lilac } }) do
		local nav = button(self.Navigation, specification[1], UDim2.fromOffset((index - 1) * 55, 0), UDim2.fromOffset(51, 35), specification[3], specification[4])
		nav.Activated:Connect(function()
			if self.Panel.Visible and self.Tab == specification[2] then self:close()
			else self:open(specification[2]) end
		end)
		table.insert(self.NavButtons, nav)
	end
	self.Sound = button(self.Navigation, "♪", UDim2.fromOffset(165, 0), UDim2.fromOffset(32, 35), palette.Paper, palette.Teal)
	self.Sound.TextSize = 18
	self.Sound.Activated:Connect(function()
		if callbacks.Mute then self.Muted = callbacks.Mute() else self.Muted = not self.Muted end
		self.Sound.Text = self.Muted and "×♪" or "♪"
		self.Sound.TextColor3 = self.Muted and palette.Muted or palette.Teal
	end)
	self.Actions = make("Frame", gui, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -14), Size = UDim2.fromOffset(235, 42), BackgroundTransparency = 1 })
	self.Press = button(self.Actions, "PRESS  [E]", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), palette.CoralButton, palette.White)
	self.Press.TextSize = 14
	self.Press.Visible = false
	self.PressStroke = self.Press:FindFirstChildOfClass("UIStroke")
	self.Press.Activated:Connect(function() if self.CanPress and not self.Panel.Visible then callbacks.Press() end end)
	self.Queue = button(self.Actions, "JOIN NEXT ROUND", UDim2.fromScale(0, 0), UDim2.new(0.65, -3, 1, 0), palette.Teal, palette.White)
	self.Queue.TextSize = 12
	self.Queue.Activated:Connect(function() if callbacks.Queue then callbacks.Queue() end end)
	self.Spectate = button(self.Actions, "WATCH", UDim2.new(0.65, 3, 0, 0), UDim2.new(0.35, -3, 1, 0), palette.LilacPale, palette.Lilac)
	self.Spectate.Visible = false
	self.Spectate.TextSize = 11
	self.Spectate.Activated:Connect(function() if callbacks.Spectate then callbacks.Spectate() end end)
	self.Personal = card(gui, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -64), Size = UDim2.fromOffset(235, 36), Visible = false }, palette.GoldPale)
	self.PersonalText = label(self.Personal, "", 12, UDim2.fromOffset(10, 4), UDim2.new(1, -20, 1, -8), palette.Gold, true)
	self.Spectator = card(gui, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 113), Size = UDim2.fromOffset(180, 67), Visible = false }, palette.Paper)
	self.Watching = label(self.Spectator, "", 13, UDim2.fromOffset(8, 4), UDim2.new(1, -16, 0, 25), palette.Ink, true)
	self.Watching.TextTruncate = Enum.TextTruncate.AtEnd
	self.Watching.TextWrapped = false
	self.WatchPrevious = button(self.Spectator, "<", UDim2.new(0, 8, 0, 32), UDim2.new(0.25, -8, 0, 28), palette.LilacPale, palette.Lilac)
	self.WatchStop = button(self.Spectator, "STOP", UDim2.new(0.25, 4, 0, 32), UDim2.new(0.5, -8, 0, 28), palette.White, palette.Ink)
	self.WatchNext = button(self.Spectator, ">", UDim2.new(0.75, 4, 0, 32), UDim2.new(0.25, -12, 0, 28), palette.LilacPale, palette.Lilac)
	self.WatchPrevious.Activated:Connect(function() if callbacks.SpectatePrevious then callbacks.SpectatePrevious() end end)
	self.WatchNext.Activated:Connect(function() if callbacks.SpectateNext then callbacks.SpectateNext() end end)
	self.WatchStop.Activated:Connect(function() if callbacks.SpectateStop then callbacks.SpectateStop() end end)
	self.Health = card(gui, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 115), Size = UDim2.fromOffset(180, 26), Visible = false }, palette.Paper)
	self.HealthLabel = label(self.Health, "HP 100", 9, UDim2.fromOffset(10, 2), UDim2.fromOffset(54, 20), palette.Teal, true)
	local healthTrack = round(make("Frame", self.Health, { Position = UDim2.fromOffset(67, 9), Size = UDim2.new(1, -77, 0, 7), BackgroundColor3 = palette.Disabled, BorderSizePixel = 0 }), 4)
	self.HealthFill = round(make("Frame", healthTrack, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = palette.Teal, BorderSizePixel = 0 }), 4)
	self.Toast = card(gui, { Position = UDim2.fromOffset(14, 119), Size = UDim2.fromOffset(340, 40), Visible = false, ZIndex = 12 }, palette.Paper)
	self.ToastText = label(self.Toast, "", 11, UDim2.fromOffset(13, 5), UDim2.new(1, -26, 1, -10), palette.Ink, true)
	self.Countdown = label(self.Event, "", 13, UDim2.new(1, -66, 0, 7), UDim2.fromOffset(55, 22), palette.CoralInk, true)
	self.Countdown.TextXAlignment = Enum.TextXAlignment.Right
	self.Countdown.Visible = false
	self.Countdown.ZIndex = 14

	self.Overlay = make("TextButton", gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(35, 66, 73), BackgroundTransparency = 0.45, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 20 })
	self.Overlay.Activated:Connect(function() self:close() end)
	self.Panel = card(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(710, 530), Visible = false, ZIndex = 21 }, palette.Paper)
	self.PanelTitle = label(self.Panel, "SUPPLY SHOP", 25, UDim2.fromOffset(22, 16), UDim2.new(1, -86, 0, 33), palette.Ink, true)
	self.Close = button(self.Panel, "×", UDim2.new(1, -55, 0, 14), UDim2.fromOffset(37, 37), palette.CoralPale, palette.Coral)
	self.Close.TextSize = 24
	self.Close.Activated:Connect(function() self:close() end)
	self.PanelSubtitle = label(self.Panel, "Buy supplies. Use them from your backpack during the next round.", 14, UDim2.fromOffset(22, 54), UDim2.new(1, -44, 0, 32), palette.Muted)
	self.Balance = label(self.Panel, "YOUR TOKENS: 0", 14, UDim2.fromOffset(22, 92), UDim2.new(1, -44, 0, 24), palette.Gold, true)
	self.ReturnLobby = button(self.Panel, "RETURN TO LOBBY", UDim2.new(0, 22, 1, -60), UDim2.new(1, -44, 0, 38), palette.Lilac, palette.White)
	self.ReturnLobby.Visible = false
	self.ReturnLobby.Activated:Connect(function() self:close() end)
	self.List = make("ScrollingFrame", self.Panel, { Position = UDim2.fromOffset(22, 126), Size = UDim2.new(1, -44, 1, -146), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5, ScrollBarImageColor3 = palette.Line, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 22 })
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
	local touch = UserInputService.TouchEnabled == true
	self.Phone, self.Short, self.Touch = phone, short, touch
	local edge = phone and 10 or 14
	local rightWidth = phone and 116 or (size.X < 800 and 152 or 180)
	local eventWidth = math.min(340, size.X - rightWidth - edge * 3)
	local eventHeight = phone and 112 or 96
	self.Event.Position = UDim2.fromOffset(edge, 10)
	self.Event.Size = UDim2.fromOffset(eventWidth, eventHeight)
	self.EventTitle.TextSize = phone and 12 or 15
	self.EventTitle.TextTruncate = Enum.TextTruncate.AtEnd
	self.EventTitle.Size = UDim2.new(1, self.Countdown.Visible and -87 or -32, 0, 21)
	self.EventDescription.Position = UDim2.fromOffset(21, 32)
	self.EventDescription.Size = UDim2.new(1, -34, 0, phone and 57 or 50)
	self.EventDescription.TextSize = phone and 11 or 13
	self.Hint.Position = UDim2.new(0, 21, 1, -21)
	self.Hint.Size = UDim2.new(1, -34, 0, 17)
	self.Hint.TextSize = phone and 9 or 10
	self.Hint.TextTruncate = Enum.TextTruncate.AtEnd
	self.Round.Position = UDim2.new(1, -edge, 0, 10)
	self.Round.Size = UDim2.fromOffset(rightWidth, 60)
	self.PhaseLabel.Position = UDim2.fromOffset(10, 5)
	self.PhaseLabel.Size = UDim2.new(1, -20, 0, 14)
	self.PhaseLabel.TextSize = phone and 8 or 9
	self.RoundInfo.Position = UDim2.fromOffset(10, 37)
	self.RoundInfo.Size = UDim2.new(1, -20, 0, 19)
	self.RoundInfo.TextSize = phone and 9 or 11
	self.Timer.Position = UDim2.fromOffset(10, 17)
	self.Timer.Size = UDim2.new(1, -20, 0, 23)
	self.Timer.TextXAlignment = Enum.TextXAlignment.Left
	self.Timer.TextSize = phone and 19 or 21
	self.Stats.Position = UDim2.new(1, -edge, 0, 76)
	self.Stats.Size = UDim2.fromOffset(rightWidth, 31)
	self.Tokens.TextSize = phone and 13 or 14
	self.Health.Position = UDim2.new(1, -edge, 0, 113)
	self.Health.Size = UDim2.fromOffset(rightWidth, 26)
	self.Spectator.Position = UDim2.new(1, -edge, 0, 113)
	self.Spectator.Size = UDim2.fromOffset(rightWidth, touch and 82 or 67)
	self.Watching.TextSize = phone and 12 or 13
	self.Watching.Text = self.SpectatingName and (phone and self.SpectatingName or ("WATCHING " .. self.SpectatingName)) or ""
	for _, control in ipairs({ self.WatchPrevious, self.WatchStop, self.WatchNext }) do
		control.Size = UDim2.new(control.Size.X.Scale, control.Size.X.Offset, 0, touch and 42 or 28)
	end
	local safeBottom = touch and (short and 170 or 178) or 14
	local actionWidth = phone and math.min(236, size.X - edge * 2) or 235
	self.Actions.AnchorPoint = Vector2.new(1, 1)
	self.Actions.Position = UDim2.new(1, -edge, 1, -safeBottom)
	self.Actions.Size = UDim2.fromOffset(actionWidth, 42)
	self.Press.TextSize = phone and 12 or 14
	self.Queue.TextSize = phone and 11 or 12
	self.Spectate.TextSize = phone and 10 or 11
	self.Navigation.AnchorPoint = Vector2.new(0, 1)
	self.Navigation.Position = UDim2.new(0, edge, 1, -(phone and safeBottom + 52 or safeBottom))
	self.Navigation.Size = UDim2.fromOffset(touch and 209 or 197, touch and 42 or 35)
	for index, nav in ipairs(self.NavButtons) do
		nav.Position = UDim2.fromOffset((index - 1) * 55, 0)
		nav.Size = UDim2.fromOffset(51, touch and 42 or 35)
		nav.TextSize = phone and 11 or 12
	end
	self.Sound.Size = UDim2.fromOffset(touch and 44 or 32, touch and 42 or 35)
	self.Stack.Position = UDim2.fromOffset(edge, eventHeight + 17)
	self.Stack.Size = UDim2.fromOffset(math.min(200, eventWidth), 84)
	self.Personal.Position = UDim2.new(1, -edge, 1, -(phone and (safeBottom + 52 + (touch and 42 or 35) + 8) or safeBottom + 50))
	self.Personal.Size = UDim2.fromOffset(actionWidth, phone and 44 or 36)
	self.PersonalText.TextSize = phone and 11 or 12
	self.Toast.Size = UDim2.fromOffset(math.min(200, eventWidth), 45)
	self.ToastText.TextSize = phone and 10 or 11
	self.Panel.Size = UDim2.fromOffset(math.min(710, size.X - 24), math.min(530, size.Y - 24))
	self.PanelTitle.TextSize = phone and 19 or (short and 20 or 25)
	if self.Panel.Visible then
		if self.Tab == "Shop" then self:renderShop()
		elseif self.Tab == "Roster" then self:renderRoster()
		elseif self.Tab == "Results" then self:renderResults()
		else self:renderLeaders() end
	end
	if self.State then self:tick(self.Nearby) end
end

function UI:open(tab)
	self.Tab = tab
	self.Panel.Visible, self.Overlay.Visible = true, true
	self.Actions.Visible, self.Event.Visible, self.Health.Visible, self.Spectator.Visible, self.Stack.Visible, self.Personal.Visible = false, false, false, false, false, false
	if tab == "Shop" then self:renderShop()
	elseif tab == "Roster" then self:renderRoster()
	elseif tab == "Results" then self:renderResults()
	else self:renderLeaders() end
end
function UI:close()
	if self.Tab == "Results" and self.State then self.DismissedResultsRound = self.State.RoundNumber end
	self.Panel.Visible, self.Overlay.Visible = false, false
	self.Event.Visible = true
	self:tick(self.Nearby)
end
function UI:destroy()
	self.ToastToken = (self.ToastToken or 0) + 1
	self.Gui:Destroy()
end
function UI:clearList()
	for _, child in ipairs(self.List:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
end
function UI:listLayout(shop)
	self.Balance.Visible = shop
	self.ReturnLobby.Visible = self.Tab == "Results"
	self.PanelSubtitle.Visible = true
	local top = shop and 126 or 99
	local bottom = self.Tab == "Results" and 75 or 20
	self.List.Position = UDim2.fromOffset(22, top)
	self.List.Size = UDim2.new(1, -44, 1, -top - bottom)
end
function UI:renderShop()
	self.PanelTitle.Text = "SUPPLY SHOP"
	self.PanelSubtitle.Text = "Buy in the lobby. Use supplies from your backpack in a round. Unused stock stays."
	self:listLayout(true)
	self:clearList()
	local data = self.Data
	self.Balance.Text = "YOUR TOKENS: " .. formatNumber(data and data.Tokens)
	local narrow = self.Phone
	local inRound = attr("InRound") == true
	for index, item in ipairs(Catalog.Items) do
		local row = card(self.List, { Name = item.Id, Size = UDim2.new(1, -6, 0, narrow and 152 or 92), LayoutOrder = index, ZIndex = 23 })
		local stock = data and data.Inventory and data.Inventory[item.Id] or 0
		local full = stock >= (item.MaxStock or 5)
		local affordable = data and (data.Tokens or 0) >= item.Price and not full and not inRound
		local swatchColor = item.Color and Color3.fromRGB(unpack(item.Color)) or palette.LilacPale
		local swatch = card(row, { Position = UDim2.fromOffset(12, 15), Size = UDim2.fromOffset(44, 44), ZIndex = 24 }, swatchColor)
		local icon = label(swatch, supplyIcons[item.Id] or "+", 28, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), palette.Ink, true)
		icon.TextXAlignment = Enum.TextXAlignment.Center
		label(row, item.Name, narrow and 17 or 19, UDim2.fromOffset(68, 8), UDim2.new(1, narrow and -80 or -212, 0, 26), palette.Ink, true)
		label(row, item.Description, 14, UDim2.fromOffset(68, 35), UDim2.new(1, narrow and -80 or -212, 0, narrow and 48 or 45), palette.Muted)
		local stockLabel = label(row, "STOCK: " .. stock .. "/" .. (item.MaxStock or 5), 12, narrow and UDim2.fromOffset(12, 83) or UDim2.new(1, -130, 0, 60), narrow and UDim2.new(1, -24, 0, 22) or UDim2.fromOffset(118, 24), palette.Muted, true)
		stockLabel.TextXAlignment = narrow and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center
		local buy = button(row, full and "STOCK FULL" or (inRound and "BUY IN LOBBY" or ("BUY  " .. formatNumber(item.Price) .. " TOKENS")), narrow and UDim2.new(0, 12, 1, -42) or UDim2.new(1, -130, 0, 15), narrow and UDim2.new(1, -24, 0, 32) or UDim2.fromOffset(118, 37), affordable and palette.Teal or palette.Disabled, affordable and palette.White or palette.Muted)
		buy.Name = "Buy"
		buy.TextSize = narrow and 14 or 13
		buy.Active, buy.Selectable, buy.AutoButtonColor = affordable == true, affordable == true, affordable == true
		buy.Activated:Connect(function() if self.Data and affordable then self.Callbacks.Shop("Buy", item.Id) end end)
	end
end
function UI:profile(data, _persistent)
	self.Data = data
	self.Tokens.Text = compactNumber(data.Tokens) .. " Tokens"
	if self.Panel.Visible and self.Tab == "Shop" then self:renderShop() end
end
function UI:state(state)
	self.State = state
	local phase = state.Phase or "Waiting"
	self.PhaseLabel.Text = phase == "Round" and (state.SuddenDeath and "SUDDEN DEATH" or ("ROUND " .. tostring(state.RoundNumber or 1))) or (phase == "Intermission" and "STARTING SOON" or (phase == "Results" and "RESULTS" or "LOBBY"))
	self.PhaseLabel.TextColor3 = phase == "Round" and palette.CoralInk or (phase == "Results" and palette.Gold or palette.Teal)
	self.RoundInfo.Text = phase == "Round" and (state.RoundMode == "Solo survival" and "SOLO SURVIVAL" or (tostring(state.AliveCount or 0) .. " / " .. tostring(state.RoundPlayers or 0) .. " alive")) or (phase == "Results" and "Next round soon" or (tostring(state.QueuedCount or 0) .. " queued"))
	self.EventTitle.Text = state.EventName or "PRESS FOR CHAOS"
	self.EventDescription.Text = state.EventDescription or "Each press earns Tokens and adds a new surprise."
	local category = string.lower(tostring(state.EventCategory or ""))
	self.EventMark.BackgroundColor3 = phase == "Results" and palette.Gold or (phase ~= "Round" and palette.Teal or ((category == "role" or category == "chase") and palette.Lilac or ((tonumber(state.EventIntensity) or 2) <= 1 and palette.Teal or palette.Coral)))
	self.Event.Visible = not self.Panel.Visible
	if self.Panel.Visible and self.Tab == "Roster" then self:renderRoster() end
	if self.Panel.Visible and self.Tab == "Shop" then self:renderShop() end
	if phase == "Results" and type(state.Results) == "table" then
		if self.ShownResultsRound ~= state.RoundNumber then
			self.ShownResultsRound = state.RoundNumber
			self:open("Results")
		elseif self.Panel.Visible and self.Tab == "Results" then self:renderResults() end
	elseif self.Panel.Visible and self.Tab == "Results" then self:close() end
	self:tick(self.Nearby)
end
function UI:renderActiveEvents(now)
	local active = {}
	if self.State and self.State.Phase == "Round" then
		for _, entry in ipairs(self.State.ActiveEvents or {}) do
			if type(entry.EndsAt) == "number" and entry.EndsAt > now then table.insert(active, entry) end
		end
	end
	table.sort(active, function(a, b) return a.EndsAt < b.EndsAt end)
	local maximum = self.Short and self.Touch and 2 or 3
	local shown = math.min(maximum, #active)
	for index, view in ipairs(self.ActiveCards) do
		local entry = active[index]
		view.Frame.Visible = entry ~= nil and index <= shown
		if view.Frame.Visible then
			local ink, tint = eventColor(entry.Category, entry.Intensity)
			view.Frame.BackgroundColor3 = tint
			view.Name.Text, view.Name.TextColor3 = entry.Name or "Chaos", ink
			view.Timer.Text, view.Timer.TextColor3 = tostring(math.ceil(entry.EndsAt - now)) .. "s", ink
			view.Id = entry.Id
		end
	end
	self.ActiveCount = #active
	self.Stack.Size = UDim2.new(self.Stack.Size.X.Scale, self.Stack.Size.X.Offset, 0, shown > 0 and shown * 28 - 4 or 0)
	self.Stack.Visible = shown > 0 and not self.Panel.Visible and not (self.Short and self.Touch and self.Toast.Visible)
	local toastOffset = self.Short and self.Touch and 0 or (shown > 0 and shown * 28 + 3 or 0)
	self.Toast.Position = UDim2.fromOffset(self.Stack.Position.X.Offset, self.Stack.Position.Y.Offset + toastOffset)
end
function UI:pressFeedback()
	self.PressFeedbackEndsAt = workspace:GetServerTimeNow() + 0.22
	self:tick(self.Nearby)
end
function UI:spectating(name, index, total)
	self.SpectatingName = name
	self.Watching.Text = name and (self.Phone and name or ("WATCHING " .. name)) or ""
	self.WatchPrevious.Active = (total or 0) > 1
	self.WatchNext.Active = (total or 0) > 1
	self.WatchPrevious.AutoButtonColor = self.WatchPrevious.Active
	self.WatchNext.AutoButtonColor = self.WatchNext.Active
	self.Spectator.Visible = name ~= nil and not self.Panel.Visible
	self.WatchIndex = index
	self:tick(self.Nearby)
end
function UI:countdown(seconds)
	self.Countdown.Visible = seconds >= 0
	self.Countdown.Text = seconds == 0 and "GO!" or (tostring(seconds) .. "s")
	self.EventTitle.Size = UDim2.new(1, self.Countdown.Visible and -87 or -32, 0, 21)
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
	self.Press.Visible, self.Queue.Visible = inRound and self.Nearby and not state.SuddenDeath, not inRound
	self.Spectate.Visible = not inRound and not self.SpectatingName and phase == "Round" and (state.AliveCount or 0) > 0
	self.Spectator.Visible = self.SpectatingName ~= nil and not inRound and phase == "Round" and not self.Panel.Visible
	self.Queue.Size = self.Spectate.Visible and UDim2.new(0.65, -4, 1, 0) or UDim2.fromScale(1, 1)
	self.Queue.Text = queued and "QUEUED  ·  LEAVE" or "JOIN ROUND"
	self.Queue.BackgroundColor3 = queued and palette.GoldPale or palette.Teal
	self.Queue.TextColor3 = queued and palette.Gold or palette.White
	local remaining = math.max(0, math.max(state.ReadyAt or 0, attr("PrivatePressReadyAt") or 0) - now)
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local alive = humanoid and humanoid.Health > 0
	self.CanPress = inRound and not state.SuddenDeath and alive == true and self.Nearby and remaining <= 0
	self.Press.Active, self.Press.Selectable = self.CanPress, self.CanPress
	self.Press.AutoButtonColor = self.CanPress
	if state.SuddenDeath then self.Press.Text = "SURVIVE THE STORM"
	elseif remaining > 0 then self.Press.Text = "NEXT PRESS  " .. string.format("%.1f", remaining) .. "s"
	else self.Press.Text = "PRESS  +" .. tostring(Config.PressTokens or 2) .. " TOKENS" .. (self.Touch and "" or "  [E / X]") end
	self.Press.BackgroundColor3 = self.CanPress and palette.CoralButton or palette.Disabled
	self.Press.TextColor3 = self.CanPress and palette.White or palette.Muted
	local pop = (self.PressFeedbackEndsAt or 0) > now
	if pop then self.Press.BackgroundColor3 = palette.CoralPale end
	self.PressStroke.Thickness = pop and 2.5 or 1.2
	self.PressStroke.Color = pop and palette.Coral or palette.Line
	self.Actions.Visible = not self.Panel.Visible and (self.Press.Visible or self.Queue.Visible)
	self.Hint.Text = ""
	self.Hint.Visible = false
	if inRound then
		local role = attr("PrivateRole") or attr("Role")
		local eventHint = attr("PrivateHint") or attr("EventHint")
		local eventTimer = attr("EventTimer")
		local personalInstructions = eventHint and eventHint ~= "" and not sameText(eventHint, state.EventDescription)
		if personalInstructions then
			self.EventDescription.Text = tostring(eventHint)
		else
			self.EventDescription.Text = state.EventDescription or "Survive the chaos."
		end
		local specialRole = role and role ~= "" and role ~= "Survivor" and role ~= "Lobby" and role ~= "Spectator"
		self.Hint.Text = personalInstructions and specialRole and not sameText(role, self.EventDescription.Text) and string.upper(tostring(role)) or ""
		if type(eventTimer) == "number" then
			self.Hint.Text = "BOMB  " .. tostring(math.max(0, math.ceil(eventTimer - now))) .. "s"
		end
		self.Hint.TextColor3 = type(eventTimer) == "number" and palette.CoralInk or palette.Ink
	elseif queued then self.Hint.Text = "QUEUED FOR THE NEXT ROUND"
	elseif attr("Status") == "Eliminated" then self.Hint.Text = "OUT THIS ROUND. MAKE A COMEBACK." end
	self.Hint.Visible = self.Hint.Text ~= ""
	self.EventDescription.Size = UDim2.new(1, -34, 0, self.Phone and (self.Hint.Visible and 57 or 70) or (self.Hint.Visible and 42 or 50))
	self.Health.Visible = inRound and not self.Panel.Visible
	local personal = attr("PrivatePersonalHint")
	local personalEndsAt = attr("PrivatePersonalEndsAt")
	self.Personal.Visible = inRound and not self.Panel.Visible and type(personal) == "string" and personal ~= "" and type(personalEndsAt) == "number" and personalEndsAt > now
	if self.Personal.Visible then self.PersonalText.Text = personal end
	self:renderActiveEvents(now)
	if phase == "Round" then
		local livingText = state.RoundMode == "Solo survival" and "SOLO" or (self.Phone and tostring(state.AliveCount or 0) .. " alive" or tostring(state.AliveCount or 0) .. " / " .. tostring(state.RoundPlayers or 0) .. " alive")
		self.RoundInfo.Text = livingText .. (self.ActiveCount > 0 and (" · " .. self.ActiveCount .. " hazards") or "")
	end
	if humanoid then
		local fraction = math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1)
		self.HealthLabel.Text = "HP " .. tostring(math.ceil(math.max(0, humanoid.Health)))
		self.HealthFill.Size = UDim2.fromScale(fraction, 1)
		local color = fraction < 0.3 and palette.CoralInk or (fraction < 0.6 and palette.Gold or palette.Teal)
		self.HealthFill.BackgroundColor3, self.HealthLabel.TextColor3 = color, color
	end
end
function UI:toast(message, kind)
	if kind == "event" and (sameText(message, self.State and self.State.EventDescription) or sameText(message, attr("PrivateHint") or attr("EventHint"))) then return end
	self.ToastToken = (self.ToastToken or 0) + 1
	local token = self.ToastToken
	self.Toast.Visible = true
	self.ToastText.Text = message
	self.ToastText.TextColor3 = kind == "good" and palette.Teal or (kind == "bad" and palette.CoralInk or palette.Ink)
	self.Toast.BackgroundColor3 = kind == "good" and palette.TealPale or (kind == "bad" and palette.CoralPale or palette.Paper)
	self:renderActiveEvents(workspace:GetServerTimeNow())
	task.delay(4.5, function() if self.ToastToken == token then self.Toast.Visible = false; self:renderActiveEvents(workspace:GetServerTimeNow()) end end)
end
function UI:leaders(entries, labelText)
	self.Entries = entries or {}
	self.LeaderboardLabel = labelText
	if self.Panel.Visible and self.Tab == "Leaderboard" then self:renderLeaders() end
end
function UI:renderResults()
	local results = self.State and self.State.Results or {}
	local winner = results.WinnerName
	local outcome = tostring(results.Outcome or "Round complete")
	local titles = {
		Winner = "WE HAVE A WINNER!", SoloSurvived = "YOU SURVIVED!", SoloFailed = "BETTER LUCK NEXT ROUND",
		Timeout = "STORM DRAW - NO WINNER", Wipeout = "EVERYONE WAS ELIMINATED", Cancelled = "ROUND CANCELLED", NoContest = "NO BUTTON PRESS - NO CONTEST",
	}
	self.PanelTitle.Text = titles[outcome] or "ROUND RESULTS"
	self.PanelSubtitle.Text = winner and winner ~= "" and (winner .. " wins round " .. tostring(self.State.RoundNumber or "") .. "!") or ("Round " .. tostring(self.State and self.State.RoundNumber or "") .. " complete. Your earned Tokens are shown below.")
	self:listLayout(false)
	self:clearList()
	local rows = {}
	for _, entry in ipairs(results.Rows or {}) do table.insert(rows, entry) end
	table.sort(rows, function(a, b)
		if (a.Place or 999) == (b.Place or 999) then return (a.UserId or 0) < (b.UserId or 0) end
		return (a.Place or 999) < (b.Place or 999)
	end)
	for index, entry in ipairs(rows) do
		local isYou = entry.UserId == Players.LocalPlayer.UserId
		local isWinner = entry.UserId == results.WinnerUserId
		local row = card(self.List, { Name = "Result_" .. tostring(entry.UserId), Size = UDim2.new(1, -6, 0, self.Phone and 87 or 68), LayoutOrder = index, ZIndex = 23 }, isYou and palette.LilacPale or palette.White)
		local rank = label(row, "#" .. tostring(entry.Place or index), 23, UDim2.fromOffset(10, 9), UDim2.fromOffset(43, 40), isWinner and palette.Gold or palette.Muted, true)
		rank.TextXAlignment = Enum.TextXAlignment.Center
		label(row, tostring(entry.Name or "Player") .. (isYou and " (YOU)" or ""), self.Phone and 16 or 18, UDim2.fromOffset(63, 7), UDim2.new(1, self.Phone and -75 or -212, 0, 28), palette.Ink, true)
		label(row, isWinner and "WINNER" or (entry.Survived and "SURVIVED" or "ELIMINATED"), 12, UDim2.fromOffset(63, 35), UDim2.new(1, -75, 0, 22), entry.Survived and palette.Teal or palette.CoralInk, true)
		local reward = label(row, "+" .. formatNumber(entry.Tokens) .. " TOKENS  |  " .. tostring(entry.KOs or 0) .. " KOs", self.Phone and 12 or 13, self.Phone and UDim2.fromOffset(63, 58) or UDim2.new(1, -188, 0, 20), self.Phone and UDim2.new(1, -75, 0, 21) or UDim2.fromOffset(176, 28), palette.Gold, true)
		reward.TextXAlignment = self.Phone and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
	end
	if #rows == 0 then
		local empty = card(self.List, { Size = UDim2.new(1, -6, 0, 70), ZIndex = 23 })
		label(empty, "The next round is starting soon. Join the queue to play!", 16, UDim2.fromOffset(14, 10), UDim2.new(1, -28, 1, -20), palette.Muted)
	end
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
		label(row, entry.Name or "Player", self.Phone and 15 or 18, UDim2.fromOffset(72, 12), UDim2.new(1, -180, 0, 39), palette.Ink, true)
		local score = label(row, formatNumber(entry.Wins), 16, UDim2.new(1, -101, 0, 11), UDim2.fromOffset(85, 26), palette.Teal, true)
		score.TextXAlignment = Enum.TextXAlignment.Right
		local caption = label(row, "WINS", 11, UDim2.new(1, -101, 0, 36), UDim2.fromOffset(85, 15), palette.Muted)
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
			local initial = label(avatar, initialOf(entry.Name or "?"), 19, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), ink, true)
			initial.TextXAlignment = Enum.TextXAlignment.Center
			local playerName = (entry.Name or "Player") .. (entry.UserId == Players.LocalPlayer.UserId and " (YOU)" or "")
			label(row, playerName, self.Phone and 15 or 17, UDim2.fromOffset(62, 10), UDim2.new(1, -160, 0, 27), palette.Ink, true)
			local role = entry.Role and entry.Role ~= "" and ("  ·  " .. tostring(entry.Role)) or ""
			label(row, tostring(entry.Status or "Lobby") .. role, 12, UDim2.fromOffset(62, 39), UDim2.new(1, -160, 0, 24), ink)
			local score = label(row, tostring(entry.Wins or 0) .. " WINS", 11, UDim2.new(1, -93, 0, 13), UDim2.fromOffset(78, 23), palette.Gold, true)
			score.TextXAlignment = Enum.TextXAlignment.Right
			local presses = label(row, formatNumber(entry.Presses) .. " presses", 11, UDim2.new(1, -99, 0, 39), UDim2.fromOffset(84, 23), palette.Muted)
			presses.TextXAlignment = Enum.TextXAlignment.Right
		end
	end
end
return UI
