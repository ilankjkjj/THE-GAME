local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Pets = {}
function Pets.start()
	local pets = {}
	local container = Instance.new("Folder")
	container.Name = "LocalButtonPets"
	container.Parent = workspace
	local function refresh(player)
		if pets[player] then pets[player].Model:Destroy(); pets[player] = nil end
		local id = player:GetAttribute("Pet")
		local item = id and Catalog.ById[id]
		if not item then return end
		local model = Instance.new("Model")
		model.Name = player.Name .. "Pet"
		local function part(name, size, offset, color, shape)
			local object = Instance.new("Part")
			object.Name = name
			object.Size = size
			object.CFrame = CFrame.new(offset)
			object.Color = color
			object.Shape = shape or Enum.PartType.Ball
			object.Material = Enum.Material.SmoothPlastic
			object.Anchored = true
			object.CanCollide = false
			object.CanTouch = false
			object.CanQuery = false
			object.Parent = model
			return object
		end
		local color = Color3.fromRGB(unpack(item.Color))
		local body = part("Body", Vector3.new(1.7, 1.7, 1.7), Vector3.zero, color)
		for _, sign in ipairs({ -1, 1 }) do
			part("Eye", Vector3.new(0.18, 0.26, 0.18), Vector3.new(sign * 0.37, 0.2, -0.77), Color3.fromRGB(13, 18, 27))
		end
		if id == "pet_chicken" then
			part("Beak", Vector3.new(0.45, 0.25, 0.5), Vector3.new(0, -0.12, -0.9), Color3.fromRGB(255, 153, 34), Enum.PartType.Block)
			part("Comb", Vector3.new(0.3, 0.6, 0.65), Vector3.new(0, 0.9, 0), Color3.fromRGB(255, 68, 83), Enum.PartType.Block)
		else
			body.Material = Enum.Material.Neon
		end
		model.PrimaryPart = body
		model.Parent = container
		-- Start at the owner's character to avoid displaying a pet at the button on equip.
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then model:PivotTo(root.CFrame * CFrame.new(3, 0, 3)) end
		pets[player] = { Model = model }
	end
	local function added(player)
		player:GetAttributeChangedSignal("Pet"):Connect(function() refresh(player) end)
		refresh(player)
	end
	Players.PlayerAdded:Connect(added)
	Players.PlayerRemoving:Connect(function(player)
		if pets[player] then pets[player].Model:Destroy(); pets[player] = nil end
	end)
	for _, player in ipairs(Players:GetPlayers()) do added(player) end
	RunService.RenderStepped:Connect(function(delta)
		for player, pet in pairs(pets) do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				local target = root.CFrame * CFrame.new(3, math.sin(os.clock() * 3 + player.UserId % 10) * 0.45, 3)
				pet.Model:PivotTo(pet.Model:GetPivot():Lerp(target, 1 - math.exp(-8 * delta)))
			end
		end
	end)
end
return Pets
