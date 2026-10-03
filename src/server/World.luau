local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local World = {}
local palette = {
	Normal = { Color3.fromRGB(20, 27, 40), Color3.fromRGB(32, 42, 58), Color3.fromRGB(78, 255, 191) },
	Cosmic = { Color3.fromRGB(28, 15, 62), Color3.fromRGB(65, 32, 96), Color3.fromRGB(178, 112, 255) },
	Candy = { Color3.fromRGB(65, 22, 44), Color3.fromRGB(111, 49, 89), Color3.fromRGB(255, 149, 208) },
	Gold = { Color3.fromRGB(44, 31, 16), Color3.fromRGB(81, 59, 25), Color3.fromRGB(255, 199, 65) },
}
function World.part(parent, name, size, position, color, material, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape then part.Shape = shape end
	part.Parent = parent
	return part
end
function World.sign(part, face, text, color, pixels)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixels or 35
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold)
	label.Text = text
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = color or Color3.fromRGB(245, 249, 255)
	label.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.09, 0)
	padding.PaddingBottom = UDim.new(0.09, 0)
	padding.PaddingLeft = UDim.new(0.05, 0)
	padding.PaddingRight = UDim.new(0.05, 0)
	padding.Parent = label
	return label
end
function World.build()
	for _, name in ipairs({ "EditorFloor", "EditorSpawn", "ButtonRoom" }) do
		local old = workspace:FindFirstChild(name)
		if old then old:Destroy() end
	end
	local root = Instance.new("Folder")
	root.Name = "ButtonRoom"
	root.Parent = workspace
	World.Root = root
	World.Walls = {}
	World.Accents = {}
	World.Floor = World.part(root, "Floor", Vector3.new(100, 2, 100), Vector3.new(0, -1, 0), palette.Normal[1])
	for _, spec in ipairs({ { Vector3.new(100, 24, 2), Vector3.new(0, 12, -50) }, { Vector3.new(100, 24, 2), Vector3.new(0, 12, 50) }, { Vector3.new(2, 24, 100), Vector3.new(-50, 12, 0) }, { Vector3.new(2, 24, 100), Vector3.new(50, 12, 0) } }) do
		table.insert(World.Walls, World.part(root, "Wall", spec[1], spec[2], palette.Normal[2]))
	end
	for i = -40, 40, 10 do
		for _, spec in ipairs({ { Vector3.new(0.09, 0.02, 98), Vector3.new(i, 0.02, 0) }, { Vector3.new(98, 0.02, 0.09), Vector3.new(0, 0.02, i) } }) do
			local line = World.part(root, "FloorGrid", spec[1], spec[2], Color3.fromRGB(50, 67, 84), Enum.Material.Neon)
			line.CanCollide = false
		end
	end
	for _, z in ipairs({ -48.8, 48.8 }) do
		table.insert(World.Accents, World.part(root, "LightStrip", Vector3.new(96, 0.25, 0.25), Vector3.new(0, 3, z), palette.Normal[3], Enum.Material.Neon))
	end
	for _, x in ipairs({ -48.8, 48.8 }) do
		table.insert(World.Accents, World.part(root, "LightStrip", Vector3.new(0.25, 0.25, 96), Vector3.new(x, 3, 0), palette.Normal[3], Enum.Material.Neon))
	end
	for _, position in ipairs({ Vector3.new(-27, 0.5, 27), Vector3.new(27, 0.5, 27), Vector3.new(-27, 0.5, -27), Vector3.new(27, 0.5, -27) }) do
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn"
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Duration = 3
		spawn.Size = Vector3.new(7, 1, 7)
		spawn.Position = position
		spawn.Color = palette.Normal[3]
		spawn.Material = Enum.Material.Neon
		spawn.Transparency = 0.55
		spawn.Parent = root
	end
	local base = World.part(root, "Pedestal", Vector3.new(3, 14, 14), Vector3.new(0, 1.5, 0), Color3.fromRGB(48, 56, 73), nil, Enum.PartType.Cylinder)
	base.Orientation = Vector3.new(0, 0, 90)
	local ring = World.part(root, "ButtonRing", Vector3.new(0.5, 11, 11), Vector3.new(0, 3.25, 0), palette.Normal[3], Enum.Material.Neon, Enum.PartType.Cylinder)
	ring.Orientation = base.Orientation
	table.insert(World.Accents, ring)
	World.Button = World.part(root, "Button", Vector3.new(1.7, 9.5, 9.5), Vector3.new(0, 4.1, 0), Color3.fromRGB(255, 68, 83), Enum.Material.Neon, Enum.PartType.Cylinder)
	World.Button.Orientation = base.Orientation
	local light = Instance.new("PointLight")
	light.Color = World.Button.Color
	light.Brightness = 1.5
	light.Range = 24
	light.Parent = World.Button
	World.ButtonLight = light
	World.Prompt = Instance.new("ProximityPrompt")
	World.Prompt.ActionText = "Press it anyway"
	World.Prompt.ObjectText = "DON'T PRESS THE BUTTON"
	World.Prompt.KeyboardKeyCode = Enum.KeyCode.E
	World.Prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	World.Prompt.MaxActivationDistance = 15
	World.Prompt.RequiresLineOfSight = false
	World.Prompt.Parent = World.Button
	World.Click = Instance.new("ClickDetector")
	World.Click.MaxActivationDistance = 15
	World.Click.Parent = World.Button
	local header = World.part(root, "WarningBoard", Vector3.new(64, 8, 0.8), Vector3.new(0, 18, -48.5), Color3.fromRGB(13, 18, 27))
	World.sign(header, Enum.NormalId.Back, "DON'T PRESS THE BUTTON", Color3.fromRGB(255, 68, 83))
	local counter = World.part(root, "CounterBoard", Vector3.new(54, 4, 0.8), Vector3.new(0, 10.7, -48.5), Color3.fromRGB(13, 18, 27))
	World.CounterLabel = World.sign(counter, Enum.NormalId.Back, "99 PRESSES UNTIL SOMETHING SPECIAL", palette.Normal[3])
	local rules = World.part(root, "RulesBoard", Vector3.new(0.8, 12, 24), Vector3.new(48.5, 11, 0), Color3.fromRGB(13, 18, 27))
	World.sign(rules, Enum.NormalId.Left, "ONE BUTTON.\nABSOLUTELY NO SELF CONTROL.\n\nPress = points + coins\nEvery 99 presses = a special event\nSpend points in the SHOP")
	local board = World.part(root, "LeaderboardBoard", Vector3.new(0.8, 17, 30), Vector3.new(-48.5, 12, 0), Color3.fromRGB(13, 18, 27))
	World.LeaderboardLabel = World.sign(board, Enum.NormalId.Right, "MOST BUTTON PRESSES\n\nLoading leaderboard...", palette.Normal[3], 28)
	local instruction = World.part(root, "FloorWarning", Vector3.new(22, 0.03, 4), Vector3.new(0, 0.05, 13), Color3.fromRGB(20, 27, 40))
	World.sign(instruction, Enum.NormalId.Top, "GO ON. WHAT COULD GO WRONG?", Color3.fromRGB(255, 199, 65))
	World.Effects = Instance.new("Folder")
	World.Effects.Name = "EventEffects"
	World.Effects.Parent = root
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.25
	bloom.Size = 24
	bloom.Threshold = 1.2
	bloom.Parent = Lighting
	-- Rescue launches, falling characters, or respawns outside the arena.
	task.spawn(function()
		while root.Parent do
			task.wait(0.5)
			for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
				local character = player.Character
				local pivot = character and character:FindFirstChild("HumanoidRootPart")
				if pivot and (pivot.Position.Y < -20 or math.abs(pivot.Position.X) > 65 or math.abs(pivot.Position.Z) > 65) then
					character:PivotTo(CFrame.new(0, 5, 25))
					pivot.AssemblyLinearVelocity = Vector3.zero
				end
			end
		end
	end)
	return World
end
function World.theme(name)
	local colors = palette[name] or palette.Normal
	World.Floor.Color = colors[1]
	for _, wall in ipairs(World.Walls) do wall.Color = colors[2] end
	for _, accent in ipairs(World.Accents) do accent.Color = colors[3] end
	Lighting.ClockTime = name == "Cosmic" and 0 or 17
end
function World.press(color)
	World.Button.Color = color
	World.ButtonLight.Color = color
	local down = TweenService:Create(World.Button, TweenInfo.new(0.12), { Position = Vector3.new(0, 3.5, 0) })
	down:Play()
	task.delay(0.14, function()
		TweenService:Create(World.Button, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Position = Vector3.new(0, 4.1, 0) }):Play()
	end)
end
function World.counter(state)
	World.CounterLabel.Text = state.Special and "SPECIAL EVENT • EVERYONE GETS A REWARD!" or (state.Remaining .. " PRESSES UNTIL SOMETHING SPECIAL")
	World.Prompt.Enabled = workspace:GetServerTimeNow() >= state.ReadyAt
	World.Prompt.ActionText = state.Cost > 0 and ("Press • " .. state.Cost .. " coins") or "Press it anyway"
end
return World
