local Roles = {}
function Roles.apply(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then return end
	local obsolete = character:FindFirstChild("ButtonCosmetics")
	if obsolete then obsolete:Destroy() end
	for _, child in ipairs(character:GetDescendants()) do if child.Name == "ButtonTrailAttachment" then child:Destroy() end end
	local old = character:FindFirstChild("EventRoleLabel")
	if old then old:Destroy() end
	local role = player:GetAttribute("Role")
	if not role or table.find({ "Lobby", "Survivor", "Spectator", "Murderer", "Sheriff", "Innocent" }, role) then return end
	local gui = Instance.new("BillboardGui")
	gui.Name, gui.Adornee, gui.Size, gui.StudsOffset = "EventRoleLabel", head, UDim2.fromScale(6, 1.3), Vector3.new(0, 2.8, 0)
	gui.AlwaysOnTop, gui.MaxDistance = true, 55
	gui.Parent = character
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	label.Text, label.Font, label.TextScaled = string.upper(role), Enum.Font.ArialBold, true
	label.TextColor3, label.TextStrokeTransparency = Color3.new(1, 1, 1), 0.35
	label.Parent = gui
end
return Roles
