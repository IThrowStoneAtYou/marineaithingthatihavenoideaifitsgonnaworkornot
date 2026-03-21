local combat = {}

--Services
local runService = game:GetService("RunService")
local debrisService = game:GetService("Debris")
local tweenService = game:GetService("TweenService")
local insertService = game:GetService("InsertService")
local serverStorage = game:GetService("ServerStorage")

local modules = script.Parent
local core = require(modules.Core)
local debug = require(modules.Debug)
local formulas = require(modules.Formulas)
local targetmodule = require(modules.Target)

local marine = script.Parent.Parent.Parent
local myRoot = marine.HumanoidRootPart
local myHuman = marine.Humanoid

local m4 = marine.M4
local barrel = m4.Barrel
local lightFlash = barrel.MuzzleDynamicLight
local chamber = m4.Chamber
local fireSound = m4.Fire
local impact = m4.Impact

--Settings--
local mySettings = marine.Settings
local m4Settings = mySettings.M4
local bulletSettings = mySettings.BulletPhysics
local visualSettings = mySettings.Visuals
local damageSettings = mySettings.Damage

-- Animations --
local stabAnimation = myHuman:LoadAnimation(marine.Stab)
stabAnimation.Priority = Enum.AnimationPriority.Action

local stabPunchAnimation = myHuman:LoadAnimation(marine.StabPunch)
stabPunchAnimation.Priority = Enum.AnimationPriority.Action

local throwAnimation = myHuman:LoadAnimation(marine.ThrowAnimation)
throwAnimation.Priority = Enum.AnimationPriority.Action
throwAnimation.Looped = false

local fullMag = m4Settings.MagSize.Value
local mag = fullMag
local minBulletSpread = m4Settings.MinBulletSpread.Value -- minimum amount of bullet spread (in degrees)
local maxBulletSpread = m4Settings.MaxBulletSpread.Value -- maximum amount of bullet spread (in degrees)
local minKnifeDamage = damageSettings.MinKnifeDamage.Value -- min amount of knife damage
local maxKnifeDamage = damageSettings.MaxKnifeDamage.Value -- max amount of knife damage
local minGunDamage = damageSettings.MinGunDamage.Value -- min amount of gun damage
local maxGunDamage = damageSettings.MaxGunDamage.Value -- max amount of gun damage
local falloffRange = damageSettings.RangeAtDropoff.Value -- range at which drop off starts
local minDamageRange = damageSettings.RangeAtMinimum.Value -- range at which stays at min damage
local bulletsPerShot = m4Settings.BulletsPerShot.Value -- self explanitory
local semiRange = m4Settings.SemiRange.Value -- range at which the marine will shoot in semi automatic mode
local fullAuto = m4Settings.FullAuto.Value -- if the gun is full auto (OVERRIDES BURST VALUE)
local burst = m4Settings.Burst.Value -- if the gun is burst (TURN OFF FULL AUTO IF THIS IS ENABLED)
local debrisOnHit = visualSettings.DebrisOnHit.Value -- debri chunks when hitting a wall
local meleeRange = mySettings.MeleeRange.Value -- range at which the marine will do melee
local fireRate = m4Settings.Firerate.Value -- wait time between shots
local reloadDelay = m4Settings.ReloadDelay.Value -- wait time before reloading
local iterations = bulletSettings.Iterations.Value -- iterations
local bulletSpeed = bulletSettings.BulletSpeed.Value -- bullet speed
local ricochetIterations = bulletSettings.RicochetIterations.Value -- iterations only on ricochetting bullets
local speedDecrease = bulletSettings.SpeedDecrease.Value -- speed decrease on ricochet
local ricochet = bulletSettings.Ricochet.Value -- if bullets ricochet
local maxBounces = bulletSettings.MaxBounces.Value -- max amount of ricochet bounces
local bounceChance = bulletSettings.BounceChance.Value -- chance of ricochet
local ignoreFolder = mySettings.IgnoreFolder.Value

if ignoreFolder == nil then
	repeat task.wait() ignoreFolder = mySettings.IgnoreFolder.Value until ignoreFolder ~= nil
end

local bulletClone -- saving this for later
local bulletHoleClone
local shooting = false

print(ignoreFolder)

function getObjects()
	local bulletModel = serverStorage:WaitForChild("MarineStuff")
	local bullet = bulletModel:FindFirstChild("Bullet") -- change the thing in quotes if you wanna change the bullet
	local bulletHole = bulletModel:FindFirstChild("BulletHole")
	
	bullet.Position = Vector3.new(0,0,0)
	bulletHole.Decal.Transparency = 1
	bulletClone = bullet
	bulletHoleClone = bulletHole
	
	print(bulletClone)
	print(bulletHoleClone)
end

getObjects()

function reflectBullet(raycastresult,currentNormal)
	local resultNormal = raycastresult.Normal
	local reflectedNormal = (currentNormal - (2 * currentNormal:Dot(resultNormal) * resultNormal))
	
	currentNormal = reflectedNormal
	return currentNormal
end

function combat.getBullet() -- doing this because i dont want to have to script all the trail properties
	local newBullet = bulletClone:Clone()
	newBullet.Parent = ignoreFolder
	newBullet.Transparency = 0

	if newBullet:FindFirstChild("Whiz") then
		newBullet.Whiz:Play()
	end
	
	return newBullet
end

function combat.getBulletHole(partHit)
	if bulletHoleClone then
		local bulletHole = bulletHoleClone:Clone()
		local debrisAttachment = bulletHole.DebrisAttachment
		bulletHole.Decal.Transparency = 0
		bulletHole.Decal.Color3 = partHit.Color
		bulletHole.Parent = ignoreFolder

		debrisAttachment.TinyDustParticles.Color = ColorSequence.new(partHit.Color)
		debrisAttachment.MainDustEffect.Color = ColorSequence.new(partHit.Color)
		debrisAttachment.SmokeEffect.Color = ColorSequence.new(partHit.Color)
		return bulletHole
	else
		return nil
	end
end

function canRicochet()
	local bounce = false
	if ricochet then
		if bounceChance <= 100 then
			bounce = true
		else
			local chance = bounceChance
			local rand = math.random(0,100)

			if rand > chance then
				bounce = true
			end
		end
	end
	return bounce
end

function removeBullet(bullet)
	bullet.Transparency = 1

	if bullet:findFirstChild("Whiz") then
		bullet.Whiz:Stop()
	end

	bullet.Parent = workspace.Terrain
	--bullet.Size = Vector3.new() -- huh?
	debrisService:AddItem(bullet, 0.5)
end

function combat:applySpread(bullet,direction)
	local dirCF = CFrame.new(Vector3.new(),direction)
	local spreadDirection = CFrame.fromOrientation(0, 0, math.random(0, math.pi * 2))
	local angle = CFrame.fromOrientation(math.rad(math.random(minBulletSpread, maxBulletSpread)),0,0)
	local newDirection = (dirCF * spreadDirection * angle)

	bullet.CFrame = CFrame.new(Vector3.new(),newDirection.LookVector)
	bullet.Position = barrel.WorldPosition
end

function linearDropOff(distance) -- credit to dthecoolest for damage fall off calculations
	local slope = (minGunDamage - maxGunDamage) / (minDamageRange - falloffRange)
	local solvedEq = slope * (distance - falloffRange) + maxGunDamage
	
	return math.clamp(solvedEq, minGunDamage, maxGunDamage)
end

function combat.pushBullet(npc,bullet,speed,iterations)
	--Testing removing marine from ignore list
	--Magic fastcast
	
	if speed == nil or iterations == nil then -- changing this to default settings
		speed = 20 -- 7 before / uses studs per sec
		iterations = 20 -- if i recall, this is how precise the detections wwas???
	end
	
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {marine,workspace.Terrain,ignoreFolder}

	local startPosition = barrel.WorldPosition
	local success,Error = pcall(function()
		task.spawn(function()
			while true do
				local position,nextPosition = bullet.Position,Vector3.new(0,0,speed)
		        local result = workspace:Raycast(position, bullet.CFrame.LookVector * speed, params)

				if result and result.Instance.Name ~= "Bullet" then
					local currentNormal = bullet.CFrame.LookVector
					bullet.CFrame = CFrame.new(result.Position)
					removeBullet(bullet)
					
					--local human = result.Instance.Parent:FindFirstChildWhichIsA("Humanoid")
					local human = core.getHuman(result.Instance.Parent)
					impact.WorldPosition = result.Position

					if human and human.Health > 0 then
						--human:TakeDamage(math.random(5,15))
						local distance = (result.Position - startPosition).Magnitude
						local damageToTake = linearDropOff(distance)
						core.applyDamage(human,damageToTake)
						--print(damageToTake)
						--impact.Hit:Play()
						if human.Health <= 0 then
							npc:FindTarget()
						end
					elseif not human then
						--impact.Miss:Play()
						local newBulletHole = combat.getBulletHole(result.Instance)
						if newBulletHole then
							newBulletHole.CFrame = CFrame.new(newBulletHole.Position, newBulletHole.Position + result.Normal)
							newBulletHole.Position = result.Position
							debrisService:AddItem(newBulletHole,5)
							
							if result.Instance.Material ~= Enum.Material.Metal and result.Instance.Material ~= Enum.Material.DiamondPlate then
								local debrisAttachment = newBulletHole.DebrisAttachment
								debrisAttachment.TinyDustParticles:Emit(15)
								debrisAttachment.MainDustEffect:Emit(15)
								debrisAttachment.SmokeEffect:Emit(15)
								
								if debrisOnHit then
									for i = 1, math.random(2,3) do
										local chunk = Instance.new("Part")
										chunk.Color = result.Instance.Color
										chunk.Material = result.Instance.Material
										local size = math.random(5)/20
										chunk.Size = Vector3.new(size,size,size)
										chunk.CFrame = CFrame.new(result.Position)
										chunk.Anchored = false
										chunk.AssemblyLinearVelocity = Vector3.new(math.random(-20,20),math.random(10,20),math.random(-20,20))
										chunk.Parent = workspace
										debrisService:AddItem(chunk,1)
									end
								end
							end
						end
					end
					
					if result.Material == Enum.Material.Metal then
						impact.Metal:Play()
						impact.Spark:Emit(10)
						impact.FlashEffect:Emit(10)
						impact.FlashInnerEffect:Emit(5)

						local canBounce = canRicochet()

						if canBounce then
							local newBullet = combat.getBullet()
							local reflect = reflectBullet(result,currentNormal)
							newBullet.CFrame = CFrame.new(Vector3.new(0,0,0),reflect)
							newBullet.Position = result.Position
							newBullet.CFrame = newBullet.CFrame * CFrame.new(0,0,-0.01)
						--	runService.Heartbeat:Wait()  -- what???
						--	runService.Heartbeat:Wait()
							combat.pushBullet(marine,newBullet,(speed - speedDecrease),ricochetIterations)
						end

					elseif human then
						impact.Hit:Play()
						impact.BloodCloud:Emit(30)
						impact.BloodParticles:Emit(30)
					else
						impact.Miss:Play()
					end

					break
		        else
					bullet.CFrame = bullet.CFrame * CFrame.new(-nextPosition)
				end
		
				iterations -= 1

				if iterations < 0 then
					removeBullet(bullet)
					break
				end

				task.wait()
			end
		end)
	end)

	if not success then
		warn(Error)
		removeBullet(bullet)
	end
end

function checkSight(target)
	local canSee = false
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {marine,ignoreFolder}
	params.FilterType = Enum.RaycastFilterType.Exclude
	
	local raycastResult = workspace:Raycast(myRoot.Position,CFrame.new(myRoot.Position,target.Position).LookVector * mySettings.DetectionRange.Value,params)
	local Success,Error = pcall(function()
		if raycastResult.Instance then
			if raycastResult.Instance:IsDescendantOf(target.Parent) then
				canSee = true
			end
		end
	end)
	
	if not Success then warn(Error) end
	
	return canSee
end

local flashIndex = 1
function combat:Shoot(target)
	local targetHumanoid = target.Parent:FindFirstChildOfClass("Humanoid")
	if self:GetWeaponCool() and not self:GetReloading() then
		self:SetWeaponCool(false)
		
		local shot
		if core.checkDist(target,myRoot) > semiRange and semiRange ~= 0 then
			shot = 1
		else
			if burst then
				shot = 3
			end
			
			if fullAuto then
				shot = self:GetMag()
			end
		end
		
		for i = 1, shot do
			if fullAuto then
				if checkSight(target) ~= true then
					break
				end
				
				if targetHumanoid and myHuman then
					if targetHumanoid.Health <= 0 or myHuman.Health <= 0 then
						break
					end
				end
						
				if core.checkDist(target,myRoot) < meleeRange then
					print("in melee range")
					break
				end
			end

			task.wait(60/fireRate) -- actually converted into irl weapon RPM
			self:SetMag(self:GetMag()-1)
			
			fireSound:Play()
					
			--flash:Emit(1)
			local flashCoroutine = coroutine.create(function()
				barrel.MuzzleFlashEffect:Emit(15)
				barrel.MuzzleFlashInnerEffect:Emit(15)
				barrel.SmokeEffect:Emit(3)
				barrel.SparkEffect:Emit(20)
				lightFlash.Enabled = true 
				task.wait(0.05)
				lightFlash.Enabled = false 
			end)
			
			coroutine.resume(flashCoroutine)
			
			--bullet.CFrame = m4.CFrame * CFrame.new(0,0.2,-2.5) --z: 0.5
			for i = 1, bulletsPerShot, 1 do
				local bulletCoroutine = coroutine.create(function()
					local bullet = combat.getBullet()
				--	runService.Heartbeat:Wait() --Give bullet time to render from barrel -- (me in the future: figure out this is useless)

					combat:applySpread(bullet,barrel.WorldCFrame.LookVector)

				--	runService.Heartbeat:Wait() --Give bullet time to render from barrel

					combat.pushBullet(self, bullet, bulletSpeed, iterations)
				end)
				
				coroutine.resume(bulletCoroutine)
			end
			
		--[[
			--Kick
			local original = m4.HingeAttach1.Position
			m4.HingeAttach1.Position = original - Vector3.new(0,0,0.2)
			tweenService:Create(m4.HingeAttach1, TweenInfo.new(0.1),{Position = original}):Play()
		--[[]]
		end
		
		if self:GetMag() <= 0 and not shooting then
			task.wait(reloadDelay)
			self:Reload()
		end

		--New thread here before
		task.wait(mySettings.M4.Delay.Value)
		self:SetWeaponCool(true)
	end
end

function combat:ThrowGrenade()
	if self:GetWeaponCool() and self:GetGrenadeCool() then
		self:SetWeaponCool(false)
		self:SetGrenadeCool(false)
		self:YieldWeapons()
		
		local g = self.Grenade:Clone()
		g.Boom.PlayOnRemove = true
		g.Parent = workspace
		g.CanCollide = true
		
		g.CFrame = marine["Right Arm"].CFrame * CFrame.new(0,-1.3,0) * CFrame.Angles(0,0,math.rad(90))
		g:SetNetworkOwner(nil)
		debrisService:AddItem(g,5)
		
		self.Grenade.Transparency = 1
		
		local w = Instance.new("WeldConstraint",g)
		w.Part0 = marine["Right Arm"]
		w.Part1 = g
		
		throwAnimation:Play()
		self.Grenade.Pin:Play()
		
		--Rotate and throw
		self.Human.AutoRotate = false
		for i = 1, 4 do
			task.wait(0.1)
			self.Root.CFrame = CFrame.lookAt(
				Vector3.new(self.Root.Position.X, self.Root.Position.Y, self.Root.Position.Z),
				Vector3.new(self:GetTarget().Position.X,self.Root.Position.Y,self:GetTarget().Position.Z)
			)
		end

		self.Human.AutoRotate = true
		
		if self.Human.Health <= 0 then
			return
		end
		
		throwAnimation:Stop()
		
		w.Part1 = nil
		local targetPos = self:GetTarget().Position + (self:GetTarget().Velocity)

		debug.mark(targetPos)

		local dist = core.checkDist(myRoot,self:GetTarget())
		local aimCFrame = CFrame.lookAt(myRoot.Position,targetPos)
		--g.Velocity = (aimCFrame.LookVector + Vector3.new(0,1.1,0)) * Vector3.new(dist,dist*1.5,dist)
		--g.Velocity = (myRoot.CFrame.LookVector + Vector3.new(0,1,0)) * Vector3.new(dist,dist*1.5,dist)
		g.Velocity = formulas.CalculateArc(g, targetPos, dist*1.3)
		
		--Wait until grenade is thrown before it can be primed
		local touched
		touched = g.Touched:Connect(function(obj)
			if not obj:IsDescendantOf(marine) then
				touched:Disconnect()
				g.Pin:Play()

				task.wait(0.5)
				local x = Instance.new("Explosion",workspace)
				x.Position = g.Position
				x.BlastRadius = 16
				x.BlastPressure = 50000
				x.DestroyJointRadiusPercent = 0

				x.Hit:Connect(function(obj, dist)
					local human = obj.Parent:FindFirstChild("Humanoid")
					if human then
						core.applyDamage(human, 20 - dist)
					end
				end)

				g:Destroy()
				debrisService:AddItem(x,2)
			end
		end)
		
		local attach0 = g.Attach0
		local attach1 = g.Attach1
		local t = Instance.new("Trail",g)

		t.Attachment0 = attach0
		t.Attachment1 = attach1
		t.Lifetime = 0.5
		t.Color = ColorSequence.new(Color3.fromRGB(150,150,150))
		t.WidthScale = NumberSequence.new(1,0)
		
		core.spawn(function()
			task.wait(1)
			self:SetWeaponCool(true)

			task.wait(5)
			self:SetGrenadeCool(true)
			self.Grenade.Transparency = 0
		end)
	end
end

function combat:Stab()
	
	local canStab = false
	for i,v in pairs(self:GetTarget().Parent:GetChildren()) do
		if v:IsA("BasePart") and core.checkDist(v,self.Root) < meleeRange then
			canStab = true
		end
	end
	if canStab then
		self:ChaseTargetDirectly()
		
		self.Knife.Stab:Play()
		self.Knife.Attack:Play()
		self.Knife.KnifeTrail.Enabled = true
		
		if math.random(2) == 1 then
			stabAnimation:Play(0.1,1,2)
		else
			stabPunchAnimation:Play()
		end
		
		local human = self:GetTarget().Parent.Humanoid
		core.applyDamage(human,math.random(minKnifeDamage, maxKnifeDamage))
		if human.Health <= 0 then
			self:FindTarget()
		end
		
		task.wait(0.5)
		
		self.Knife.KnifeTrail.Enabled = false
	else
		task.wait(0.2)
	end
end

function combat:CheckClusterAtTarget()
	--Check for nearby allies
	for i,v in ipairs(self:GetActiveAllies()) do
		if core.checkDist(self:GetTarget(),v) < 30 then
			return false
		end
	end
	--Check if enemies are paired close together
	for i,v in ipairs(self:GetPotentialTarget()) do
		if v ~= self:GetTarget() then
			if core.checkDist(self:GetTarget(),v) < 15 then
				return true
			end
		end
	end
	return false
end


return combat
