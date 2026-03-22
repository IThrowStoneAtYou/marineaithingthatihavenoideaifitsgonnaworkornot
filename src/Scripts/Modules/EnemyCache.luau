local EnemyCache = {}

local Players = game:GetService("Players")
local cache = {}  -- model -> { root, human, model }

local function add(model)
	local root = model:FindFirstChild("HumanoidRootPart")
	local human = model:FindFirstChildOfClass("Humanoid")
	if root and human then
		cache[model] = { root = root, human = human, model = model }
	end
end

local function remove(model)
	cache[model] = nil
end

-- Watch NPC models
workspace.ChildAdded:Connect(function(child)
	if child:FindFirstChildOfClass("Humanoid") then
		add(child)
	end
end)

workspace.ChildRemoved:Connect(function(child)
	remove(child)
end)

-- Watch players
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		add(char)
	end)
	player.CharacterRemoving:Connect(function(char)
		remove(char)
	end)
end)

-- Seed existing
for _, child in ipairs(workspace:GetChildren()) do
	if child:FindFirstChildOfClass("Humanoid") then
		add(child)
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then
		add(player.Character)
	end
end

function EnemyCache.getAll()
	return cache
end

return EnemyCache