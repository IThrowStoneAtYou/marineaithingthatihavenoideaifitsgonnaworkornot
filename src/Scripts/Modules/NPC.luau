local NPC = {}
NPC.__index = NPC

local Core = require(script.Parent.Core)

function NPC.new(o)
	
	if not o.Instance then
		error("No instance provided for the NPC.")
		return
	end
	
	setmetatable(o, NPC)
	
	-- NPC instance parts
	o.Root = o.Instance.HumanoidRootPart
	o.Human = o.Instance.Humanoid
	o.Head = o.Instance.Head
	o.Torso = o.Instance.Torso
	o.Neck = o.Torso.Neck
	o.LeftArm = o.Instance["Left Arm"]
	o.RightArm = o.Instance["Right Arm"]
	o.LeftLeg = o.Instance["Left Leg"]
	o.RightLeg = o.Instance["Right Leg"]
	o.LeftShoulder = o.Torso["Left Shoulder"]
	o.RightShoulder = o.Torso["Right Shoulder"]
	o.LeftHip = o.Torso["Left Hip"]
	o.RightHip = o.Torso["Right Hip"]
	
	o.Settings = o.Instance.Settings
	o.Knife = o.Instance.Knife
	o.StabAnimation = o.Instance.Stab
	o.StabPunchAnimation = o.Instance.StabPunch

	o.M4 = o.Instance.M4
	o.Grenade = o.Instance.Grenade
	o.BodyRotate = o.Root.AlignOrientation
	o.Dead = false
	o.Target = {}
	o.Target.Root = nil
	o.Target.LastSeen = tick()
	o.GoingHome = false
	o.Team = o.Settings.Team.Value
	o.M4Equipped = false
	o.M4Lowered = false
	o.M4Aimed = false
	o.Reloading = false
	o.WeaponCool = true
	o.KnifeEquipped = false
	o.GrenadeCool = true
	o.Mood = "Idle"
	o.Face = o.Head.faceIdle
	o.Faces = o.Head.Faces
	o.TookDamage = false
	o.PotentialTargets = {}
	o.ActiveAllies = {}
	o.Mag = o.Settings.M4.MagSize.Value
	
	o.Retreating = false
	o.RegroupTS = 0
	
	return o
end

-- Allows all functions from the module to be natively called from the NPC object.
function NPC:Inherit(module: Table)
	for k,v in pairs(module) do 
		if not self[k] then
			self[k] = v
		else
			warn("Tried to inherit an already existing function ", k, " from ", module)
		end
	end
end

function NPC:IsDead()
	return self.Human.Health <= 0
end

function NPC:SetMag(mag: IntValue)
	self.Mag = mag
end

function NPC:GetMag()
	return self.Mag
end

function NPC:SetActiveAllies(allies: Table)
	self.ActiveAllies = allies
end

function NPC:GetActiveAllies()
	return self.ActiveAllies
end

function NPC:SetPotentialTargets(targets: Table)
	self.PotentialTargets = targets
end

function NPC:GetPotentialTarget()
	return self.PotentialTargets
end

function NPC:SetTookDamage(damageTaken)
	self.TookDamage = damageTaken
end

function NPC:GetTookDamage()
	return self.TookDamage
end

function NPC:SetFace(face: Decal)
	self.Face = face
end

function NPC:GetFace()
	return self.Face
end

function NPC:SetMood(mood: string)
	self.Mood = mood
end

function NPC:GetMood()
	return self.Mood
end

function NPC:SetGrenadeCool(cool: BoolValue)
	self.GrenadeCool = cool
end

function NPC:GetGrenadeCool()
	return self.GrenadeCool
end

function NPC:SetKnifeEquipped(equipped)
	self.KnifeEquipped = equipped
end

function NPC:GetKnifeEquipped()
	return self.KnifeEquipped
end

function NPC:SetWeaponCool(cool)
	self.WeaponCool = cool
end

function NPC:GetWeaponCool()
	return self.WeaponCool
end

function NPC:SetReloading(reloading: BoolValue)
	self.Reloading = reloading
end

function NPC:GetReloading()
	return self.Reloading
end

function NPC:SetM4Aimed(aimed: BoolValue)
	self.M4Aimed = aimed
end

function NPC:GetM4Aimed()
	return self.M4Aimed
end

function NPC:SetM4Lowered(lowered: BoolValue)
	self.M4Lowered = lowered
end

function NPC:GetM4Lowered()
	return self.M4Lowered
end

function NPC:SetM4Equipped(equip: BoolValue)
	self.M4Equipped = equip
end

function NPC:GetM4Equipped()
	return self.M4Equipped
end

function NPC:CheckSight(target)
	
	local ignoreList = {self.Instance}
	
	-- Ignore all friendly models so they don't block LOS
	for _, ally in ipairs(self:GetActiveAllies()) do
		if ally.Parent then
			table.insert(ignoreList, ally.Parent)
		end
	end
	
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = ignoreList
	
	local result = workspace:Raycast(self.Head.Position,(target.Position - self.Head.Position).Unit*self.Settings.M4.Range.Value,raycastParams)
	if result and result.Instance.Parent then
		if result.Instance:IsDescendantOf(target.Parent) or result.Instance.Name == "Bullet" then
			self:SetTargetLastSeen()
			return true
		else
			local human = Core.getHuman(result.Instance.Parent)
			if human and human.Health>0 and not Core.isAlly(human.Parent) and human.RootPart then
				self:SetTarget(human.RootPart)
				self:SetTargetLastSeen()
				return true
			end
		end
	end
	return false
end

function NPC:CheckShot()
	local raycastParams = RaycastParams.new()
	local ignoreList = {self.Instance}

	raycastParams.FilterDescendantsInstances = ignoreList
	
	local dist = Core.checkDist(self.Root,self:GetTarget())
	local result1 = workspace:Raycast(self.M4.Barrel.WorldPosition,(self:GetTarget().Position - self.M4.Barrel.WorldPosition).Unit*dist,raycastParams)
	local result2 = workspace:Raycast(self.Head.Position, (self:GetTarget().Position - self.Head.Position).Unit*dist,raycastParams)
	if result1 and result2 and result1.Instance.Parent == result2.Instance.Parent then
		if result1.Instance:IsDescendantOf(self:GetTarget().Parent) or result1.Instance.Name == "Bullet" then
			return true
		else
			local human = result1.Instance.Parent:FindFirstChild("Humanoid")
			if human and human.Health>0 and not Core.isAlly(human.Parent) then
				self:SetTarget(human.RootPart)
				return true
			end
		end
	end
	return false
end

function NPC:FacingTarget()
	--Make sure we're facing the target
	local currentLookVector = self.Root.CFrame.LookVector
	local targetPos = self:GetTarget().Position
	local goalLookVector = CFrame.new(self.Root.Position,Vector3.new(
		targetPos.X,
		self.Root.Position.Y,
		targetPos.Z
		)).LookVector
	local difference = (currentLookVector - goalLookVector).Magnitude
	if difference < 0.5 then
		return true
	else
		return false
	end
end

function NPC:SetRetreating(val)
	self.Retreating = val
end

function NPC:GetRetreating()
	return self.Retreating
end

return NPC
