local marine = script.Parent.Parent.Parent
local clone = marine:Clone()

------Fix network issues------
pcall(function()
	while marine.HumanoidRootPart:GetNetworkOwnershipAuto() do
		marine.HumanoidRootPart:SetNetworkOwner(nil)
		task.wait()
	end
end)

-- Tag NPC with it's team so it can be referenced and communicated with by other NPCs.
local CollectionService = game:GetService("CollectionService")
CollectionService:AddTag(marine, marine.Settings.Team.Value)

-----Settings------
local mySettings = marine.Settings

local meleeRange = mySettings.MeleeRange.Value -- range at which the marine will do melee
local ignoreFolder = mySettings.IgnoreFolder.Value
if ignoreFolder == nil then
	if workspace:FindFirstChild("MarineIgnoreFolder") then
		ignoreFolder = workspace.MarineIgnoreFolder
	else
		local newIgnoreFolder = Instance.new("Folder",workspace)
		newIgnoreFolder.Name = "MarineIgnoreFolder"
		ignoreFolder = newIgnoreFolder
	end
end
mySettings.IgnoreFolder.Value = ignoreFolder

------Modules------
local modules = script.Parent.Parent.Modules
local core = require(modules.Core)
local actions = require(modules.Actions)
local combat = require(modules.Combat)
local targeting = require(modules.Target)
local movement = require(modules.Movement)
local debugger = require(modules.Debug)
local vehicle = require(modules.Vehicle)
local gunner = require(modules.Gunner)
local pathing = require(modules.Pathing)
local NPC = require(modules.NPC)
local Passenger = require(modules.Passenger)

------Body Variables------
local myHuman = marine.Humanoid
local myRoot = marine.HumanoidRootPart
local myHead = marine.Head

-- What the heck does this do...
local rotAttach1 = Instance.new("Attachment")
rotAttach1.Parent = workspace.Terrain

-- Sounds
local hurtSound = myHead.Hurt
local diedSound = myHead.Died

-----OOP Stuff------

local npc = NPC.new{
	Instance = script.Parent.Parent.Parent
}

npc:Inherit(actions)
npc:Inherit(movement)
npc:Inherit(targeting)
npc:Inherit(combat)

local function vehicleLogic(targetDist)
	if npc.Vehicle.Role == "Driver" then
		
		
		-- Don't start driving to the target until we have all of our passengers. 
		if npc.Vehicle:PickupNearestAlly() then

			task.wait(1)
			
		elseif targetDist > npc.Settings.Vehicle.MinDrivingDist.Value then 
			-- If we do have a vehicle determine how to drive there or to exit etc
			if npc.Vehicle:DriveTo(npc:GetTarget().Position,npc:GetTarget()) then
				
			elseif not npc.Vehicle.Instance:GetAttribute("Gunner") then
				npc.Vehicle:Blacklist(npc:GetTarget())
				npc.Vehicle = npc.Vehicle:Exit()
				
			else
				npc.Vehicle:GetFree()
			end
			
		elseif not npc.Vehicle.Instance:GetAttribute("Gunner") and npc.Vehicle:GetSpeed() < 2 then
			-- Exit vehicle
			-- TODO: Never exits when gunner is present. Eventually they should probably get out.
			npc.Vehicle = npc.Vehicle:Exit()
			
		elseif npc.Vehicle.Instance:GetAttribute("Gunner") and targetDist < npc.Settings.Vehicle.MinDrivingDist.Value / 1.5 then
			-- This case is when we have a gunner and we are too close to the enemy. 
			

			-- Is the enemy more towards the front of us or the back?
			local enemyYaw = math.abs(core.findYaw(npc.Vehicle.Body.Position, npc:GetTarget().Position, npc.Vehicle.Body))
			
			-- Maybe we can just reverse straight back from the enemy?
			if not npc.Vehicle:CheckBumper(true) and enemyYaw < 90 then
				npc.Vehicle:TurnTowardsAngle(0)
				npc.Vehicle:SmartGo(-0.4, 1)

				
				-- If the back bumper is clear of obstacles we can back away.
			elseif not npc.Vehicle:CheckBumper() and enemyYaw > 90 then
				npc.Vehicle:TurnTowardsAngle(0)
				npc.Vehicle:SmartGo(1, 1)
				
			else
				-- TODO: Need some way of finding a location to drive to 
				task.wait(1)
			end
		end
	elseif npc.Vehicle.Role == "Gunner" then
		-- TODO: Determine when we should exit the gun
		-- Exit when there is no target sight for x amount of time and there is no driver.
		if not npc.Vehicle.Instance:GetAttribute("Driver") and tick() - npc:GetTargetLastSeen() > npc.Settings.Vehicle.Patience.Value and npc.Vehicle:GetSpeed() < 2  then
			npc.Vehicle = npc.Vehicle:Exit()
		elseif npc:GetTarget() and core.checkDist(npc:GetTarget(),npc.Root) < 7 and npc.Vehicle:GetSpeed() < 2 then
			npc.Vehicle = npc.Vehicle:Exit()
		else
			task.wait(0.5) -- 2
		end
	elseif npc.Vehicle.Role == "Passenger" then
		if npc:CheckSightToTarget() and npc.Vehicle:GetSpeed() < 2 and npc:CanExitVehicle() then
			npc.Vehicle = npc.Vehicle:Exit()
		end
	else
		task.wait(1)
	end
end

local function getVehicleSpot(targetDist)
	-- Try to get in a gun position if there is a Warthog with a driver. 
	local veh, vehDist = vehicle.findNearest(npc, true, "Gunner")
	if veh and vehDist <= targetDist then

		npc.Vehicle = gunner.new(veh, npc)

		local bumper = veh.Body.Body.RearBumper

		npc:PathToLocation(bumper)

		if ((npc.Vehicle.Body.Position - npc.Root.Position).Magnitude <= npc.Settings.Vehicle.EnterDist.Value or 
			(bumper.WorldPosition - npc.Root.Position).Magnitude <= npc.Settings.Vehicle.EnterDist.Value) then					
			npc.Vehicle:Enter()
		else
			npc.Vehicle = npc.Vehicle:Destroy()
		end
		return
	end
	
	local veh, vehDist = vehicle.findNearest(npc, true, "Passenger")
	if veh and vehDist <= targetDist then

		npc.Vehicle = Passenger.new(veh, npc)

		local door = veh.Body.Body.SideDoor

		npc:PathToLocation(door)

		if ((npc.Vehicle.Body.Position - npc.Root.Position).Magnitude <= npc.Settings.Vehicle.EnterDist.Value or 
			(door.WorldPosition - npc.Root.Position).Magnitude <= npc.Settings.Vehicle.EnterDist.Value) then
			npc.Vehicle:Enter()
		else
			npc.Vehicle = npc.Vehicle:Destroy()
		end
		return
	end

	-- We don't have a vehicle do we need one?
	local veh, vehDist = vehicle.findNearest(npc, false, "Driver")

	-- Try to generate a path with it
	-- Kind of a waste that we don't use this path.

	if veh and vehDist <= targetDist then

		npc.Vehicle = vehicle.new(veh, npc)
		
		local vehPath = pathing.getVehiclePath(veh, npc:GetTarget().Position, 20)

		if vehPath then

			local door = veh.Body.Body.FrontDoor

			if (npc.Vehicle.Body.Position - npc.Root.Position).Magnitude >= npc.Settings.Vehicle.EnterDist.Value then
				-- Walk to the vehicle

				-- Set that the driver position is now occupied so that other NPCs don't try to steal it.
				if not npc:PathToLocation(door) then
					-- No valid path to the vehicle, blacklist it.
					npc.Vehicle:Blacklist(npc:GetTarget())
				end
			end

			-- Sit when we are close enough
			if (door.WorldPosition - npc.Root.Position).Magnitude <= npc.Settings.Vehicle.EnterDist.Value 
				and not npc:CheckSightToTarget() then
				npc.Vehicle:Enter()
			else
				npc.Vehicle = npc.Vehicle:Destroy()
			end

		else
			npc.Vehicle = npc.Vehicle:Destroy()
			npc:PathToLocation(npc:GetTarget())
		end
	else
		npc:PathToLocation(npc:GetTarget())
	end
end


local idleIndex = 5
local function movementLogic(target)
	local targetDist = core.checkDist(target,npc.Root)
	
	local canSee = npc:CheckSightToTarget()
	
	idleIndex -= 1
	if canSee then
		npc:SetTargetLastSeen()
		idleIndex = 5 --100
	end
	
	-- Vehicle logic first
	if npc.Vehicle and npc.Vehicle:IsInVehicle() and npc.Vehicle:Validate() then
		vehicleLogic(targetDist)
	
	elseif (targetDist > 50 or not canSee) and (myRoot.Position.Y < target.Position.Y-10 or idleIndex <= 0) then
		-- This case we need to either drive to the target or pathfind to it. 
		
		if core.runAtTS("SoldierAICheckForVehicle", 5) and targetDist > npc.Settings.Vehicle.MinDrivingDist.Value and npc:CanEnterVehicle() then
			getVehicleSpot(targetDist)
		else
			npc:PathToLocation(target)
		end
		
	elseif (targetDist > 30 or not canSee) and core.checkPotentialSight(target) then
		npc:SlowAdvance()
		task.wait(0.3)
		
	elseif npc.Settings.Movement.CanCrouch.Value and targetDist > 50 and canSee and npc:GetM4Equipped() and math.random(5) == 1
		and core.isLine(npc.Root.Position - Vector3.new(0,1.5,0), target.Position, {npc.Instance, target.Parent}) then
		npc:Crouch()
		-- Busy waiting... sue me
		local startedCrouch = core.tick()
		while npc:CheckSightToTarget() and core.checkDist(npc.Root,target) > 50 do
			if core.tick() - startedCrouch > 5 and math.random(3) == 1 then
				break
			end
			task.wait(0.5)
		end
		npc:Stand()
		
	elseif npc.Settings.Movement.CanStrafe.Value and targetDist > 50 and targetDist < 90 and canSee and npc:GetM4Equipped() then
		npc:Strafe()
		task.wait(0.5)
		
	elseif npc.Settings.Movement.CanBackpedal.Value and targetDist > 4 and targetDist < 50 and canSee 
		and math.abs(myRoot.Position.Y - target.Position.Y) < 2 and (npc:GetM4Aimed() or npc:GetReloading()) then
		npc:Retreat()
		task.wait(0.2)
		
	elseif (targetDist < 4 and canSee) or npc:GetKnifeEquipped() then
		npc:ChaseTargetDirectly()
	else
		task.wait(0.5)
	end
end


local function movementLoop()
	while myHuman.Health>0 do
		local target = npc:GetTarget()
		if target then
			movementLogic(target)
		else
			if mySettings.Wander.Value and math.random(4) == 3 then
				npc:WalkRandom()
			end
			task.wait(3)
		end
		task.wait(0.1)
	end
end

local function searchTargetLoop()
	while myHuman.Health>0 do
		
		-- Updates the target based on any that are really close to the NPC.
		-- Looks good for quick updates when melee units are attacking. 
		if core.runAtTS("GetIncomingAttackers",2) then
			npc:GetIncomingAttackers()
		end
		
		-- Keep track of what vehicle the target is potentially using.
		-- We need to know so we can ignore it during raycasting.
		if npc:GetTarget() and core.runAtTS("UpdateEnemyVehicle",2) then
			npc:SetTargetVehicle(core.getEnemyVehicleInstance(npc:GetTarget()))
		end
		
		-- Find a new target if the current one is not valid
		-- Also find a new target if we are hurt. This should make the marine look more reactionary to damage. 
		if not npc:CheckTarget() or npc:GetTookDamage() then
			npc:SetTookDamage(false)
			--npc:SetTarget(nil)
			npc:FindTarget()
			
		-- Find a new target if we can't see the target try finding one we can see.
		elseif not npc:CheckSightToTarget() and npc:GetSeeTarget() then
			npc:FindTarget()
			if not npc:GetTarget() then
				task.wait(3)
			end
		end
		task.wait(0.5)
	end
end

local function aimingLoop()
	while myHuman.Health>0 do
		
		-- Vehicle integrity check
		if npc.Vehicle and npc.Vehicle:IsInVehicle() then 
			if not npc.Vehicle:Validate() then
				npc.Vehicle = nil
			end
		end
		
		if npc:GetTarget() then
			if npc:CheckSightToTarget() and npc:GetM4Equipped() then
				npc:Aim()
			else
				task.wait(0.5)
			end
		else
			task.wait(2)
		end
		task.wait(0.1)
	end
end

local function attackLogic()
	npc:UpdateFace("Attacking")
	
	local distance = core.checkDist(myRoot,npc:GetTarget())
	if distance > meleeRange then
		
		-- If there is a cluster of enemies far enough away throw grenade.
		-- 5/20/22 added randomness, probably gotta tweak
		if npc:CheckClusterAtTarget() and distance < 100 and distance > 40 and npc:GetGrenadeCool() and math.random(10) == 1  then
			npc:ThrowGrenade(npc:GetTarget())
		elseif npc:GetM4Equipped() then
			if npc:FacingTarget() and npc:CheckShot() then
				npc:Shoot(npc:GetTarget())
			end
		else
			npc:DrawM4()
		end
	else
		npc:DrawKnife()
		npc:Stab()
	end
end

local function turretLogic()
	if npc:CheckTarget() and npc.Vehicle:CheckSightTurret() then
		npc.Vehicle:StartAimingTurret()
		while npc.Vehicle.Aiming and not npc.Vehicle.Shooting do
			task.wait(0.1)
			if npc.Vehicle:CheckAim() and npc.Vehicle:IsTargetInRange() then
				npc.Vehicle:StartShootingTurret()
			end
		end

		if not npc:CheckSightToTarget(npc.Settings.Vehicle.MaxTurretRange.Value) then
			-- Once we start shooting don't stop until we can't see it.
			-- I don't care about hitting every shot it's a machine gun.
			npc.Vehicle:StopShootingTurret()
		end
	else
		npc.Vehicle:StopShootingTurret()
	end
	task.wait(1)
end

local function attackLoop()
	while myHuman.Health>0 do
		
		if not npc.Vehicle or not npc.Vehicle:IsInVehicle() then
			
			if npc:GetTarget() then
				npc:UpdateFace("Hunting")
				
				-- If we have a target we can see
				if npc:CheckSightToTarget() and npc:CheckTarget() and core.checkDist(myRoot,npc:GetTarget()) < mySettings.M4.Range.Value then
					attackLogic()
				elseif npc:GetM4Equipped() and not npc:GetM4Aimed() then
					npc:LowerM4()
				end
			else
				task.wait(2)
				npc:UpdateFace("Idle")
				npc:YieldWeapons()
			end
		elseif npc.Vehicle.Role == "Gunner" then 
			turretLogic()
		else
			task.wait(1)
		end
		task.wait(0.3)
	end
end

task.spawn(searchTargetLoop)
task.spawn(attackLoop)
task.spawn(movementLoop)
task.spawn(aimingLoop)

-- Soldier COMMs
-- Found out you can't pass tables with metamethods using this.
marine.Query.OnInvoke = function()
	local cleanNPC = {}
	if npc.Vehicle then
		cleanNPC.Vehicle = {}
		cleanNPC.Vehicle.Instance = npc.Vehicle.Instance
		cleanNPC.Vehicle.Role = npc.Vehicle.Role
		cleanNPC.Vehicle.InVehicle = npc.Vehicle:IsInVehicle()
	else
		cleanNPC.Vehicle = nil
	end
	
	cleanNPC.Root = npc.Root

	return cleanNPC
end

myHuman.Died:Connect(function()
	if npc.Vehicle then
		if npc.Vehicle:IsInVehicle() then
			npc.Vehicle:Exit()
		else
			npc.Vehicle:Destroy()
		end
	end
	npc.Torso.AssemblyLinearVelocity  = Vector3.new(math.random(-25,25),math.random(50,75),math.random(-25,25))
	diedSound:Play()
	npc:YieldM4()
	npc:UpdateFace("Dead")
	for i,v in ipairs(marine:GetDescendants()) do
		if v:IsA("BallSocketConstraint") then
			v.Enabled = true
		elseif v:IsA("BasePart") and v.Name ~= "myHumanoidRootPart" then
			v.CanCollide = false
		elseif v:IsA("Motor6D") then
			v:Destroy()
		end
	end
	npc.Head.CanCollide = true
	if marine.Settings.Respawn.Value then
		task.wait(marine.Settings.RespawnDelay.Value)
		clone.Parent = marine.Parent
	end
	for i,v in ipairs(marine:GetDescendants()) do
		if v:IsA("BasePart") or v:IsA("Decal") then
			game:GetService("TweenService"):Create(v,TweenInfo.new(0.2),{Transparency = 1}):Play()
		end
	end
	rotAttach1:Destroy()
	task.wait(0.2)
	marine:Destroy()
end)

local oldHealth = myHuman.Health
local soundSpeeds = {0.9,0.95,1,1.05,1.1}
myHuman.HealthChanged:Connect(function(health)
	if health < oldHealth and hurtSound.IsPlaying == false then
		npc:SetTookDamage(true)
		if math.random(3) == 1 then
			hurtSound.PlaybackSpeed = soundSpeeds[math.random(#soundSpeeds)]
			hurtSound:Play()
		end
		task.spawn(function()
			npc:UpdateFace("Hurt")
			task.wait(1)
			if myHead:FindFirstChild("faceHurt") then
				npc:UpdateFace(npc:GetMood(),true)
			end
		end)
	end
	oldHealth = health
end)
