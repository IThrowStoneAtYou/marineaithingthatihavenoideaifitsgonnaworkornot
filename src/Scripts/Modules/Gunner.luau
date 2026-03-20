local Gunner = {}
Gunner.__index = Gunner

local Vehicle = require(script.Parent.Vehicle)
local core = require(script.Parent.Core)
local combat = require(script.Parent.Combat)
local debugger = require(script.Parent.Debug)
local formulas = require(script.Parent.Formulas)

setmetatable(Gunner, Vehicle)

local DebrisService = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")


local MARINE_VEHICLE_TAG = "MarineVehicle"

function Gunner.new(vehicle, npc)
	
	local o = {}
	o.Instance = vehicle
	o.Seat = vehicle.VehicleSeat
	o.Role = "Gunner"
	o.BarrelMotor = vehicle.Turret.Barrel.BarrelMotor
	o.Aimer = vehicle.Body.Body.Aimer
	o.Aiming = false
	o.Shooting = false
	o.ShootingRequestStop = false
	o.Top = vehicle.Turret.Top
	o.Barrel = vehicle.Turret.Barrel
	o.Body = vehicle.Body.Body
	o.Occupant = npc
	o.InVehicle = false
	o.TopToBaseHinge = o.Top.TopToBaseHinge
	o.Team = vehicle.Settings.Team
	
	setmetatable(o,Gunner)
	
	o:SetTeam(npc.Team)
	
	vehicle:SetAttribute(o.Role, true)
	
	return o
end

-- Teleport NPC into the Gunner position
function Gunner:Enter()
	
	local npc = self.Occupant
	npc:YieldWeapons()

	npc.Human.PlatformStand = true
	npc.Root.CFrame = self.Instance.Turret.Base.CFrame * CFrame.new(0,1.5,1.7)
	
	self.GunnerWeld = Instance.new("WeldConstraint")
	self.GunnerWeld.Part0 = self.Instance.Turret.Base
	self.GunnerWeld.Part1 = npc.Root
	self.GunnerWeld.Parent = npc.Root
	self.Top.AlignOrientation.Attachment1 = self.Aimer

	for i,v in ipairs(npc.Instance:GetDescendants()) do
		if v:IsA("BasePart") then
			PhysicsService:SetPartCollisionGroup(v,"Passengers")
		end
	end
	
	RunService.Heartbeat:Wait()
	RunService.Heartbeat:Wait()

	-- Setup NPC stance
	npc.LeftShoulder.Enabled = false
	npc.RightShoulder.Enabled = false
	npc.LeftHip.Enabled = false
	npc.RightHip.Enabled = false

	-- Set CFrame
	npc.RightLeg.CFrame = npc.Root.CFrame * CFrame.new(0.6,-2,0) * CFrame.fromEulerAnglesXYZ(0,0,math.rad(8))
	npc.LeftLeg.CFrame = npc.Root.CFrame * CFrame.new(-0.6,-2,0) * CFrame.fromEulerAnglesXYZ(0,0,math.rad(-8))

	npc.Instance.Torso.GunnerWeld_LL.Enabled = true
	npc.Instance.Torso.GunnerWeld_RL.Enabled = true
	
	npc.LeftShoulder.Enabled = false
	npc.RightShoulder.Enabled = false
	npc.ShoulderHingeR.Enabled = true
	npc.ShoulderHingeL.Enabled = true
	
	self.InVehicle = true
end

function Gunner:Exit()
	
	local npc = self.Occupant
	
	-- Reset the turret back to the original orientation
	self.Aimer.WorldCFrame = self.Body.CFrame
	
	npc.ShoulderHingeR.Enabled = false
	npc.ShoulderHingeL.Enabled = false
	npc.Instance.Torso.GunnerWeld_LL.Enabled = false
	npc.Instance.Torso.GunnerWeld_RL.Enabled = false

	--npc.Aimer.Parent = npc.Vehicle.Body
	npc.Aimer = nil
	if self.GunnerWeld then
		self.GunnerWeld:Destroy()
	end
	self.GunnerWeld = nil

	for i,v in ipairs(npc.Instance:GetDescendants()) do
		if v:IsA("BasePart") then
			PhysicsService:SetPartCollisionGroup(v, "Default")
		end
	end

	-- Setup NPC stance
	npc.LeftShoulder.Enabled = true
	npc.RightShoulder.Enabled = true
	npc.LeftHip.Enabled = true
	npc.RightHip.Enabled = true
	
	RunService.Heartbeat:Wait()
	
	npc.Root.CFrame = self.Instance.Body.Body.RearBumper.WorldCFrame * CFrame.new(0,0,-3)
	npc.Human.PlatformStand = false
	
	npc:SetVehicleTimestamp()
	
	self:Destroy()
	
	return nil
end

local flashIndex = 1
function Gunner:StartShootingTurret()
	if self.Shooting then return end
	self.Shooting = true
	self.ShootingRequestStop = false
	self.BarrelMotor.AngularVelocity = 50
	local cooldown = 0.4
	task.spawn(function()
		repeat
			local shootSound = self.Barrel.Shoot:Clone()
			shootSound.Parent = self.Barrel
			shootSound:Play()
			DebrisService:AddItem(shootSound, shootSound.TimeLength)
			
	
			local bullet = combat.getBullet()
			RunService.Heartbeat:Wait()
			bullet.CFrame = self.Barrel.CFrame * CFrame.new(0,0,-2.3)
			RunService.Heartbeat:Wait() --Give bullet time to render from barrel
			combat.pushBullet(self.Occupant,bullet)
			
			local flashCoroutine = coroutine.create(function()
				self.Barrel.Tip.MuzzleFlashEffect:Emit(15)
				self.Barrel.Tip.MuzzleFlashInnerEffect:Emit(15)
				self.Barrel.Tip.SmokeEffect:Emit(3)
				self.Barrel.Tip.SparkEffect:Emit(20)
				self.Barrel.Tip.MuzzleDynamicLight.Enabled = true 
				wait(0.05)
				self.Barrel.Tip.MuzzleDynamicLight.Enabled = false  
			end)
			
			coroutine.resume(flashCoroutine)
			
			task.wait(cooldown)
			if cooldown > 0.1 then
				cooldown = cooldown - cooldown * 0.2
			end
		until not self.Shooting or self.ShootingRequestStop or self.Occupant:IsDead() or not Vehicle.isValid(self.Occupant,self.Instance) or
			not self.Instance:GetAttribute("Gunner")
		
		self.Shooting = false
		self.BarrelMotor.AngularVelocity = 0
	end)
end

function Gunner:StopShootingTurret()
	self.ShootingRequestStop = true
end

--local function calcOffset(vehicle, offset)
	
--	-- Add inaccuracy
--	local offset = math.random(0, 100 - vehicle.Occupant.Settings.Vehicle.Accuracy.Value) / 20
	
--	if math.random(2) == 1 then
--		offset = -offset
--	end
	
--	return offset
--end

function Gunner:StartAimingTurret()
	if self.Aiming then return end
	self.Aiming = true
	local offsetX = 0
	local offsetY = 0
	task.spawn(function()
		repeat
			local target = self.Occupant:GetTarget()
			if self.Occupant:CheckTarget() then
				
				-- Should hopefully improve performance since this should 60x less raycasts per second lol.
				
				if core.runAtTS("GunnerCheckSight",2) then
					if not self:CheckSightTurret(self.Occupant.Settings.Vehicle.MaxTurretRange.Value) then
						break
					end
				end
				
				-- Stuff to account for when aiming.
				-- The distance, our velocity, the target's velocity.
				local lookPos = formulas.getAimVector3(self.Occupant.Root, target, 240) --120
				
				-- Simulates variations in the aim like a real person would have.
				if core.runAtTS("GunnerOffset",0.5) then
					offsetX = core.calcRandomOffset(self.Occupant.Settings.Vehicle.Accuracy.Value)
					offsetY = core.calcRandomOffset(self.Occupant.Settings.Vehicle.Accuracy.Value)
				end
				
				lookPos = lookPos + Vector3.new(offsetX, offsetY, 0)
				
				self.Aimer.WorldCFrame = CFrame.lookAt(self.Instance.Turret.Top.Anchor.WorldPosition,
					lookPos,
					self.Body.CFrame.UpVector)
			elseif tick() - self.Occupant:GetTargetLastSeen() > 2 then
				self.Aimer.WorldCFrame = self.Body.CFrame
			end
			
			self.Occupant.ShoulderHingeR.TargetAngle = -self.TopToBaseHinge.CurrentAngle
			self.Occupant.ShoulderHingeL.TargetAngle = -self.TopToBaseHinge.CurrentAngle
			
			task.wait()
		until not self.Aiming or self.Occupant:IsDead() or not self.Instance or not Vehicle.isValid(self.Occupant,self.Instance) or 
			not self.Instance:GetAttribute("Gunner")

		self.Aiming = false
	end)
end

function Gunner:StopAimingTurret()
	self.Aiming = false
end

function Gunner:Validate()
	if not Vehicle.isValid(self.Occupant,self.Instance) then
		self:Exit()
		return false
	end
	return true
end


function Gunner.IsValid(npc,veh)
	-- TODO: Add more stuff that makes it invalid
	return not veh:GetAttribute("Gunner")
end

function Gunner:CheckSightTurret()
	local dist = core.checkDist(self.Occupant:GetTarget(), self.Occupant.Root)
	
	local ignoreList = {self.Occupant.Instance, self.Instance}
	
	local enemyTargetVehicle = self.Occupant:GetTargetVehicle()
	if enemyTargetVehicle then
		table.insert(ignoreList, enemyTargetVehicle)
	end
	
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = ignoreList
	local result = workspace:Raycast(self.Occupant.Head.Position, (self.Occupant:GetTarget().Position - self.Occupant.Head.Position).Unit*dist, raycastParams)
	if result and result.Instance.Parent then
		if result.Instance:IsDescendantOf(self.Occupant:GetTarget().Parent) or result.Instance.Name == "Bullet" then
			self.Occupant:SetTargetLastSeen()
			return true
		end
		local human = core.getHuman(result.Instance.Parent)
		if human and human.Health>0 and not core.isAlly(human.Parent) then
			self.Occupant:SetTarget(human.RootPart)
			self.Occupant:SetTargetLastSeen()
			return true
		end
	end
	return false
end

function Gunner:CheckAim()
	return (self.Top.Anchor.WorldOrientation - self.Aimer.WorldOrientation).Magnitude < 20
end

function Gunner:IsTargetInRange()
	if not self.Occupant:CheckTarget() then return false end
	return (self.Occupant.Root.Position - self.Occupant:GetTarget().Position).Magnitude <= self.Occupant.Settings.Vehicle.MaxTurretRange.Value
end

return Gunner
