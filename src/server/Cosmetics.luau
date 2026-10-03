local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Cosmetics = {}
function Cosmetics.apply(player, data)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not head or not root or not data then return end
	local old = character:FindFirstChild("ButtonCosmetics")
	if old then old:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "ButtonCosmetics"
	folder.Parent = character
	local title = Catalog.ById[data.Equipped.Title]
	local king = (player:GetAttribute("KingUntil") or 0) > workspace:GetServerTimeNow()
	if title or king then
		local billboard = Instance.new("BillboardGui")
		billboard.Adornee = head
		billboard.Size = UDim2.fromOffset(240, 60)
		billboard.StudsOffset = Vector3.new(0, 3, 0)
		billboard.AlwaysOnTop = true
		billboard.MaxDistance = 110
		billboard.Parent = folder
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = king and "♛ BUTTON KING ♛" or title.Name
		label.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold)
		label.TextSize = 16
		label.TextStrokeTransparency = 0.45
		label.TextColor3 = king and Color3.fromRGB(255, 199, 65) or Color3.fromRGB(78, 255, 191)
		label.Parent = billboard
	end
	if king then
		local crown = Instance.new("Part")
		crown.Name = "Crown"
		crown.Size = Vector3.new(2, 0.6, 2)
		crown.Material = Enum.Material.Neon
		crown.Color = Color3.fromRGB(255, 199, 65)
		crown.CanCollide = false
		crown.CanTouch = false
		crown.Massless = true
		crown.CFrame = head.CFrame * CFrame.new(0, 1, 0)
		crown.Parent = folder
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = crown
		weld.Parent = crown
	end
	local item = Catalog.ById[data.Equipped.Trail]
	if item then
		local attachments = {}
		for _, y in ipairs({ -1, 1 }) do
			local attachment = Instance.new("Attachment")
			attachment.Name = "ButtonTrailAttachment"
			attachment.Position = Vector3.new(0, y, 0.8)
			attachment.Parent = root
			table.insert(attachments, attachment)
		end
		-- Attachments live under the root because Trail needs attachment world transforms.
		folder.Destroying:Connect(function() for _, attachment in ipairs(attachments) do attachment:Destroy() end end)
		local trail = Instance.new("Trail")
		trail.Attachment0 = attachments[1]
		trail.Attachment1 = attachments[2]
		trail.Color = ColorSequence.new(Color3.fromRGB(unpack(item.Color)))
		trail.Lifetime = 0.55
		trail.Transparency = NumberSequence.new(0.15, 1)
		trail.LightEmission = 1
		trail.FaceCamera = true
		trail.Parent = folder
	end
end
return Cosmetics
