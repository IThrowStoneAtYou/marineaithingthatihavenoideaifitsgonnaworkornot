local targeting = {}

local targetings = script.Parent
local core = require(targetings.Core)
local EnemyCache = require(targetings.EnemyCache)

function targeting:GetSeeTarget()
	local dist = self.Settings.DetectionRange.Value

	for _, entry in pairs(EnemyCache.getAll()) do
		if entry.model ~= self.Instance and entry.human.Health > 0 and not core.isAlly(entry.model) then
			local d = (self.Root.Position - entry.root.Position).Magnitude
			if d < dist and self:CheckSight(entry.root) then
				return true
			end
		end
	end
	return false
end

function targeting:FindTarget()
	local dist = self.Settings.DetectionRange.Value
	local target = nil
	local activeAllies = {}
	local potentialTargets = {}
	local seeTargets = {}

	for _, entry in pairs(EnemyCache.getAll()) do
		if entry.model ~= self.Instance and entry.human.Health > 0 then
			local d = (self.Root.Position - entry.root.Position).Magnitude
			if d < dist then
				if core.isAlly(entry.model) then
					table.insert(activeAllies, entry.root)
				else
					table.insert(potentialTargets, entry.root)
				end
			end
		end
	end

	self:SetPotentialTargets(potentialTargets)
	self:SetActiveAllies(activeAllies)

	if #potentialTargets > 0 then
		for i,v in ipairs(potentialTargets) do
			if self:CheckSight(v) then
				table.insert(seeTargets,v)
			end
		end
		if #seeTargets > 0 then
			for i,v in ipairs(seeTargets) do
				local tempDist = (self.Root.Position - v.Position).Magnitude
				if tempDist < dist then
					target = v
					dist = tempDist
				end
			end
		else
			for i,v in ipairs(potentialTargets) do
				local tempDist = (self.Root.Position - v.Position).Magnitude
				if tempDist < dist then
					target = v
					dist = tempDist
				end
			end
		end
	end
	self:SetTarget(target)
end

function targeting:GetTarget()
	return self.Target.Instance
end

function targeting:SetTarget(target)
	self.Target.Instance = target
end

function targeting:GetTargetVehicle()
	return self.Target.Vehicle
end

function targeting:SetTargetVehicle(vehicle: Instance)
	self.Target.Vehicle = vehicle
end

function targeting:SetTargetLastSeen()
	self.Target.LastSeen = tick()
end

function targeting:CheckTarget()
	local target = self.Target.Instance
	if target and target.Parent and target.Parent.Humanoid.Health > 0 then
		return true
	end
	return false
end

function targeting:GetTargetLastSeen()
	return self.Target.LastSeen
end

local raycastParams = RaycastParams.new()
function targeting:CheckSightToTarget(dist: IntValue)
	if not self:GetTarget() then
		return false
	end
	if not dist then
		dist = self.Settings.M4.Range.Value
	end

	local ignoreList = {self.Instance}
	if self.Vehicle and self.Vehicle:IsInVehicle() then
		table.insert(ignoreList, self.Vehicle.Instance)
	end

	local enemyTargetVehicle = self:GetTargetVehicle()
	if enemyTargetVehicle then
		table.insert(ignoreList, enemyTargetVehicle)
	end

	raycastParams.FilterDescendantsInstances = ignoreList
	local result = workspace:Raycast(self.Head.Position,(self:GetTarget().Position - self.Head.Position).Unit*dist,raycastParams)
	if result and result.Instance.Parent then
		if result.Instance:IsDescendantOf(self:GetTarget().Parent) or result.Instance.Name == "Bullet" then
			return true
		else
			local human = core.getHuman(result.Instance.Parent)
			if human and human.Health>0 and not core.isAlly(human.Parent) and human.RootPart then
				self:SetTarget(human.RootPart)
				return true
			end
		end
	end
	return false
end

function targeting:GetTargetPoints()
	local points = 8
	local radius = self.Settings.Vehicle.MinDrivingDist.Value * 0.75
	local drivablePoints = {}
	for i = 1, points do
		local angle = i * (2 * math.pi / points)
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		local position = self:GetTarget().Position + Vector3.new(x,3,z)

		local result = workspace:Raycast(position, Vector3.new(0,-10,0))

		if core.isLine(position, self:GetTarget().Position, {self.Instance, self:GetTarget().Parent}) and result then
			position = Vector3.new(position.X, result.Position.Y + 0.5, position.Z)
			table.insert(drivablePoints, position)
		end
	end
	return drivablePoints
end

function targeting:GetIncomingAttackers()
	local myPos = self.Root.Position
	local closest = nil
	local closestDist = math.huge

	for _, entry in pairs(EnemyCache.getAll()) do
		if entry.model ~= self.Instance and entry.human.Health > 0 and not core.isAlly(entry.model) then
			local d = (myPos - entry.root.Position).Magnitude
			if d < 20 and d < closestDist then
				closest = entry.root
				closestDist = d
			end
		end
	end

	if closest then
		self:SetTarget(closest)
	end
end

return targeting