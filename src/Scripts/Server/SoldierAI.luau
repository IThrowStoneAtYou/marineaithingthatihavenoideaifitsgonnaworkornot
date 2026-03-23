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

local meleeRange = mySettings.MeleeRange.Value
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
local NPC = require(modules.NPC)

------Body Variables------
local myHuman = marine.Humanoid
local myRoot = marine.HumanoidRootPart
local myHead = marine.Head

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

local function alliesBlockingPath(target)
	local allies = npc:GetActiveAllies()
	if #allies == 0 then return false end

	local toTarget = (target.Position - npc.Root.Position).Unit
	local blockedCount = 0

	for _, ally in ipairs(allies) do
		local toAlly = (ally.Position - npc.Root.Position)
		local dist = toAlly.Magnitude
		local dot = toAlly.Unit:Dot(toTarget)
		if dot > 0.8 and dist < core.checkDist(npc.Root, target) then
			blockedCount += 1
		end
	end

	return blockedCount >= 1
end

local function getFlankPosition(target)
	local angles = {90, -90, 120, -120}

	for _, angle in ipairs(angles) do
		local rad = math.rad(angle)
		local toTarget = (target.Position - npc.Root.Position).Unit
		local flankDir = CFrame.fromAxisAngle(Vector3.new(0,1,0), rad) * toTarget
		local flankPos = target.Position + flankDir * 30

		local result = workspace:Raycast(flankPos + Vector3.new(0,5,0), Vector3.new(0,-20,0))
		if result then
			flankPos = result.Position
		end

		if core.isLine(npc.Root.Position, flankPos, {npc.Instance, target.Parent}) then
			return flankPos
		end
	end
	return nil
end

local function shouldFlank()
	local allies = npc:GetActiveAllies()
	local target = npc:GetTarget()
	if not target or #allies == 0 then return false end

	local frontCount = 0
	for _, ally in ipairs(allies) do
		local toTarget = (target.Position - ally.Position).Unit
		if toTarget:Dot((target.Position - npc.Root.Position).Unit) > 0.7 then
			frontCount += 1
		end
	end

	return frontCount >= 1 and math.random(2) == 1
end

local function getApproachPosition(target)
	local allies = npc:GetActiveAllies()
	local takenAngles = {}

	for _, ally in ipairs(allies) do
		if ally.Parent then
			local toTarget = (target.Position - ally.Position)
			local angle = math.atan2(toTarget.Z, toTarget.X)
			table.insert(takenAngles, angle)
		end
	end

	local bestAngle = 0
	local bestScore = -1

	for i = 0, 7 do
		local candidate = (i / 8) * math.pi * 2
		local minDiff = math.huge

		for _, taken in ipairs(takenAngles) do
			local diff = math.abs(candidate - taken)
			if diff > math.pi then diff = math.pi * 2 - diff end
			if diff < minDiff then minDiff = diff end
		end

		if minDiff > bestScore then
			bestScore = minDiff
			bestAngle = candidate
		end
	end

	local engageDist = 35
	local offset = Vector3.new(math.cos(bestAngle) * engageDist, 0, math.sin(bestAngle) * engageDist)
	local approachPos = target.Position + offset

	local groundResult = workspace:Raycast(approachPos + Vector3.new(0, 5, 0), Vector3.new(0, -20, 0))
	if groundResult then
		approachPos = groundResult.Position
	end

	if not core.isLine(npc.Root.Position, approachPos, {npc.Instance, target.Parent}) then
		return nil
	end

	return approachPos
end

-- Hold and push state
local holdDuration = 6
local pushCooldown = 20
local lastHoldTS = 0
local currentlyHolding = false

local idleIndex = 5
local function movementLogic(target)
	local targetDist = core.checkDist(target, npc.Root)
	local canSee = npc:CheckSightToTarget()

	idleIndex -= 1
	if canSee then
		npc:SetTargetLastSeen()
		idleIndex = 5
		currentlyHolding = false -- spotted target, cancel hold
	end

	if (targetDist > 50 or not canSee) and (myRoot.Position.Y < target.Position.Y - 10 or idleIndex <= 0) then

		-- Hold and push: stop short, watch, then push
		if not canSee and targetDist > 20 and not currentlyHolding and tick() - lastHoldTS > pushCooldown then
			currentlyHolding = true
			lastHoldTS = tick()

			-- Move to a position short of the target
			local toTarget = (target.Position - npc.Root.Position)
			local holdPos = npc.Root.Position + toTarget.Unit * math.max(toTarget.Magnitude - 35, 10)
			local ground = workspace:Raycast(holdPos + Vector3.new(0,5,0), Vector3.new(0,-20,0))
			if ground then holdPos = ground.Position end

			npc:PathToLocation(holdPos)
			npc:DrawM4()

			-- Hold: face expected direction, strafe, wait
			npc.Human.AutoRotate = false
			npc.BodyRotate.Enabled = true

			local holdStart = tick()
			while tick() - holdStart < holdDuration do
				if myHuman.Health <= 0 then break end
				if not npc:GetTarget() then break end

				-- Enemy appeared, drop hold immediately
				if npc:CheckSightToTarget() then
					currentlyHolding = false
					break
				end

				-- Face where enemy is expected
				npc.BodyRotate.CFrame = CFrame.new(
					myRoot.Position,
					Vector3.new(target.Position.X, myRoot.Position.Y, target.Position.Z)
				)

				if math.random(3) == 1 then
					local sideDir = math.random(2) == 1 and npc.Root.CFrame.RightVector or -npc.Root.CFrame.RightVector
					local sidePos = npc.Root.Position + sideDir * math.random(8, 15)
					local groundCheck = workspace:Raycast(sidePos + Vector3.new(0,3,0), Vector3.new(0,-10,0))
					if groundCheck and not core.raycast(npc.Root.Position, sideDir * 15, {npc.Instance}) then
						npc.Human:MoveTo(sidePos)
					end
				end

				task.wait(0.5)
			end

			npc.Human.AutoRotate = true
			npc.BodyRotate.Enabled = false

			-- Done holding, push forward to target
			if not npc:CheckSightToTarget() and npc:GetTarget() then
				currentlyHolding = false
				npc:PathToLocation(npc:GetTarget())
			end

		elseif alliesBlockingPath(target) then
			local flankPos = getFlankPosition(target)
			if flankPos then
				npc.Human:MoveTo(flankPos)
				task.wait(1)
			else
				npc:PathToLocation(target)
			end
		else
			local approachPos = getApproachPosition(target)
			if approachPos and (npc.Root.Position - approachPos).Magnitude > 10 then
				npc:PathToLocation(approachPos)
			else
				npc:PathToLocation(target)
			end
		end

	elseif (targetDist > 30 or not canSee) and core.checkPotentialSight(target) then
		npc:SlowAdvance()
		task.wait(0.3)

	elseif npc.Settings.Movement.CanCrouch.Value and targetDist > 50 and canSee and npc:GetM4Equipped() and math.random(5) == 1
		and core.isLine(npc.Root.Position - Vector3.new(0,1.5,0), target.Position, {npc.Instance, target.Parent}) then
		npc:Crouch()
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
	while myHuman.Health > 0 do
		if npc:GetRetreating() or npc:GetReloading() then
			task.wait(0.5)
			continue
		end

		local target = npc:GetTarget()
		if target then
			if npc.Settings.Movement.CanFlank.Value and shouldFlank() then
				local flankPos = getFlankPosition(target)
				if flankPos then
					npc.Human:MoveTo(flankPos)
					task.wait(1)
				else
					movementLogic(target)
				end
			else
				movementLogic(target)
			end
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
	while myHuman.Health > 0 do
		if core.runAtTS("GetIncomingAttackers", 2) then
			npc:GetIncomingAttackers()
		end

		if not npc:CheckTarget() or npc:GetTookDamage() then
			npc:SetTookDamage(false)
			npc:FindTarget()
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
	while myHuman.Health > 0 do
		if npc:GetRetreating() or npc:GetReloading() or currentlyHolding then
			task.wait(0.5)
			continue
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

local reengageTS = 0
local reengageCooldown = 15
local retreatHealthThreshold = 50
local regroupDuration = 10

local function shouldRetreat()
	local healthPercent = (myHuman.Health / myHuman.MaxHealth) * 100
	return healthPercent < retreatHealthThreshold
		and not npc:GetRetreating()
		and tick() - reengageTS > reengageCooldown
end

local function regroupLoop()
	while myHuman.Health > 0 do
		if shouldRetreat() then
			npc:SetRetreating(true)
			npc:UpdateFace("Hurt")

			local target = npc:GetTarget()

			if target then
				npc:BreakAway(target)

				local breakStart = tick()
				repeat
					task.wait(0.5)
					if target and core.checkDist(npc.Root, target) < 35 then
						npc:BreakAway(target)
					end
				until core.checkDist(npc.Root, target) >= 35
					or tick() - breakStart > 4
					or myHuman.Health <= 0
			end

			local waitStart = tick()
			repeat
				task.wait(1)
				if target and core.checkDist(npc.Root, target) < 25 then
					npc:BreakAway(target)
				end
			until tick() - waitStart > regroupDuration
				or myHuman.Health <= 0

			npc:SetRetreating(false)
			reengageTS = tick()
			npc:DrawM4()
		end
		task.wait(1)
	end
end

local function attackLogic()
	npc:UpdateFace("Attacking")

	local distance = core.checkDist(myRoot, npc:GetTarget())
	if distance > meleeRange then
		if npc:CheckClusterAtTarget() and distance < 100 and distance > 40 and npc:GetGrenadeCool() and math.random(10) == 1 then
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

local suppressDuration = 3

local function canSuppress()
	local timeSinceSeen = tick() - npc:GetTargetLastSeen()
	return timeSinceSeen < 5
		and timeSinceSeen > 0.5
		and #npc:GetActiveAllies() > 0
		and npc:GetM4Equipped()
		and not npc:GetReloading()
end

local function suppress()
	local lastKnown = npc.Target.LastSeenPosition
	if not lastKnown then return end

	local timeStart = tick()
	while tick() - timeStart < suppressDuration do
		if npc:CheckSightToTarget() then break end
		if npc:GetMag() <= 0 then break end
		if myHuman.Health <= 0 then break end

		npc.BodyRotate.Enabled = true
		npc.BodyRotate.CFrame = CFrame.new(myRoot.Position, Vector3.new(
			lastKnown.X, myRoot.Position.Y, lastKnown.Z
			))

		local sprayPos = lastKnown + Vector3.new(
			math.random(-5, 5), math.random(0, 3), math.random(-5, 5)
		)

		npc:FireOnce(sprayPos)
		task.wait(60 / 600)
	end

	npc.BodyRotate.Enabled = false
end

local function attackLoop()
	while myHuman.Health > 0 do
		if npc:GetTarget() then
			npc:UpdateFace("Hunting")

			if npc:GetRetreating() then
				if npc:CheckSightToTarget() and npc:CheckTarget()
					and core.checkDist(myRoot, npc:GetTarget()) < 25 then
					if npc:FacingTarget() and npc:CheckShot() then
						npc:Shoot(npc:GetTarget())
					end
				end
			elseif currentlyHolding then
				-- During hold, keep M4 drawn and ready but don't attack or lower
				if not npc:GetM4Equipped() then
					npc:DrawM4()
				end
			elseif npc:CheckSightToTarget() and npc:CheckTarget() and core.checkDist(myRoot, npc:GetTarget()) < mySettings.M4.Range.Value then
				attackLogic()
			elseif canSuppress() then
				suppress()
			elseif npc:GetM4Equipped() and not npc:GetM4Aimed() then
				npc:LowerM4()
			end
		else
			task.wait(2)
			npc:UpdateFace("Idle")
			npc:YieldWeapons()
		end
		task.wait(0.3)
	end
end

task.spawn(searchTargetLoop)
task.spawn(attackLoop)
task.spawn(movementLoop)
task.spawn(aimingLoop)
task.spawn(regroupLoop)

marine.Query.OnInvoke = function()
	local cleanNPC = {}
	cleanNPC.Root = npc.Root
	return cleanNPC
end

myHuman.Died:Connect(function()
	diedSound:Play()
	npc:YieldM4()
	npc:UpdateFace("Dead")

	if marine.Settings.Respawn.Value then
		task.wait(marine.Settings.RespawnDelay.Value)
		clone.Parent = marine.Parent
	end

	for i,v in ipairs(marine:GetDescendants()) do
		if v:IsA("BasePart") or v:IsA("Decal") then
			game:GetService("TweenService"):Create(v, TweenInfo.new(0.2), {Transparency = 1}):Play()
		end
	end

	task.wait(0.2)
	marine:Destroy()
end)

local oldHealth = myHuman.Health
local soundSpeeds = {0.9, 0.95, 1, 1.05, 1.1}
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
				npc:UpdateFace(npc:GetMood(), true)
			end
		end)
	end
	oldHealth = health
end)
