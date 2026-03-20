local movement = {}

--Services
local pathfindingService = game:GetService("PathfindingService")
local runService = game:GetService("RunService")

local modules = script.Parent
local core = require(modules.Core)
local debugger = require(modules.Debug)

local marine = script.Parent.Parent.Parent
local myHuman = marine.Humanoid
local myRoot = marine.HumanoidRootPart


local moveEvent = Instance.new("BindableEvent")
function movement.moveToFinished()
	local success = true
	local completed = false
    
    core.spawn(function() 
        task.wait(1)
		if not completed then
	        success = false
	        moveEvent:Fire()   
		end
    end)
    
    core.spawn(function()
        myHuman.MoveToFinished:Wait()
        moveEvent:Fire()
    end)
    
	moveEvent.Event:Wait()

	completed = true

    return success
end

local path = pathfindingService:CreatePath()
function movement:PathToLocation(target)
	--if not target or not target.Parent then return end
	if not target or (typeof(target) == "Instance" and not target.Parent) then return end
	
	local pathingToTarget = false
	if target == self:GetTarget() then
		pathingToTarget = true
	end
	
	-- Added so that we can path to attachments which specific spots on a vehicle to enter.
	local posProperty = "Position"
	if target:IsA("Attachment") then
		posProperty = "WorldPosition"
	end
	
	path:ComputeAsync(myRoot.Position, target[posProperty])
	
	if path.Status == Enum.PathStatus.NoPath then
		return false
	end
	
	local waypoints = path:GetWaypoints()
	
	--Make sure that path is actually valid
	if waypoints[1] and core.checkDist(waypoints[1],myRoot) > 10 then
		task.wait()
		self:PathToLocation(target)
	end
	
	debugger.visualizePath(path)
	
	local canSee = self:CheckSightToTarget()
	
	
	for _,waypoint in ipairs(waypoints) do
		if waypoint.Action == Enum.PathWaypointAction.Jump and (not self.Vehicle or not self.Vehicle:IsInVehicle()) then
			self.Human.Jump = true
		end
		self.Human:MoveTo(waypoint.Position)
		task.spawn(function()
			local tries = 0
			while self.Human.WalkToPoint.Y > self.Root.Position.Y - 1 and (not self.Vehicle or not self.Vehicle:IsInVehicle())
				and myHuman.Health>0 do
				
				tries += 1
				myHuman.Jump = true
				task.wait(0.1)
				if tries > 10 then
					break
				end
			end
		end)
		
		-- Bunch of logic to determine when the path should be interrupted.
		local moveSuccess = movement.moveToFinished()
		local dist = core.checkDist(self.Root,target[posProperty])
		
		-- Sometimes the NPC will get stuck behind it's vehicle or other unanchored objects.
		-- I think a simple jump could fix this.
		if core.raycast(self.Root.Position, (waypoint.Position - self.Root.Position).Unit * 2, {self.Instance}) then
			if not self.Vehicle or not self.Vehicle:IsInVehicle() then
				self.Human.Jump = true
				task.wait(1.2)
			end
		end
		
		
		if not moveSuccess then
			break
			
		elseif core.checkDist(target[posProperty],waypoints[#waypoints]) > 30 then
			-- Kind of an exception for when pathing to an attachment which is probably a vehicle
			-- Try to path to it again.
			self:PathToLocation(target)
			break
			
		elseif not target.Parent then
			break
			
		elseif pathingToTarget then
			
			-- Additional checks when we are pathing to a target.
			if core.runAtTS("PathToLocationCheckSight",1) then
				canSee = self:CheckSightToTarget()
			end
			
			if dist < 30 and canSee then
				break
				
			elseif (canSee and target.Position.Y <= myRoot.Position.Y-5) then
				self.Human:MoveTo(myRoot.Position)
				break
			elseif target ~= self:GetTarget() or not self:CheckTarget() then
				break
			end
			
		elseif target:IsA("Attachment") and dist < self.Settings.Vehicle.EnterDist.Value then
			break
		end
	end
	
	return true 
end

function movement:WalkRandom()
	local randX = math.random(-100,100)
	local randZ = math.random(-100,100)
	local goal = self.Root.Position + Vector3.new(randX, 0, randZ)
	local path = pathfindingService:CreatePath()
	path:ComputeAsync(self.Root.Position, goal)
	local waypoints = path:GetWaypoints()
	
	if path.Status == Enum.PathStatus.Success then
		for i,waypoint in ipairs(waypoints) do
			if waypoint.Action == Enum.PathWaypointAction.Jump then
				self.Human.Jump = true
			end
			self.Human:MoveTo(waypoint.Position)
			core.spawn(function()
				task.wait(0.5)
				if self.Human.WalkToPoint.Y > self.Root.Position.Y then
					self.Human.Jump = true
				end
			end)
			local moveSuccess = myHuman.MoveToFinished:Wait()
			if not moveSuccess or self:GetTarget() then
				break
			end
		end
	else
		task.wait(2)
	end
end

--When strafing make sure you can see target from end pos
function movement:Strafe()
	local goalPos = self:GetTarget().Position
	local origin,dir = self.Root.Position,nil
	
	local action = math.random(2)
	if action == 1 then
		dir = self.Root.CFrame.RightVector
	elseif action == 2 then
		dir = -self.Root.CFrame.RightVector
	end
	
	for _=1,10 do
		if not core.raycast(origin,dir*2) and core.raycast(origin,Vector3.new(0,-7,0)) then
			origin += dir*2
		else
			origin += dir*-2
			break
		end
	end
	
	local _,result = core.raycast(origin,(self:GetTarget().Position - origin).Unit * 30)
	if result then
		if result.Instance:IsDescendantOf(self:GetTarget().Parent) then

		else

			origin = self.Root.Position
		end
		origin = self.Root.Position
	end
	
	self.Human:MoveTo(origin)
end

function checkDirection(npc, dir)
	local goalPos = npc:GetTarget().Position
	local origin = myRoot.Position
	
	local success = false
	for i=1, 5 do
		if not core.raycast(origin,dir*1) and core.raycast(origin,Vector3.new(0,-7,0)) then
			origin = origin + dir*1
		else
			origin = origin + dir*-1
			break
		end
		
		if i == 5 then
			success = true
		end
	end
	
	return success,origin
end

function movement:Retreat()
	
	--Check if we can retreat directly from the enemy.
	local result,pos = checkDirection(self,-(self:GetTarget().Position - self.Root.Position).Unit)
	if result then
		self.Human:MoveTo(pos)
		return
	end
	
	--Check if we can move away to the right.
	result,pos = checkDirection(self,self.Root.CFrame.RightVector)
	if result then
		self.Human:MoveTo(pos)
		return
	end
	
	--Check if can move away to the left.
	result,pos = checkDirection(self,-self.Root.CFrame.RightVector)
	if result then
		self.Human:MoveTo(pos)
		return
	end
end

function movement:SlowAdvance()
	local goalPos = self:GetTarget().Position
	local origin = self.Root.Position
	
	local maxIterations = 30
	repeat
		maxIterations -= 1
		if not core.raycast(origin,(goalPos - origin).Unit*1) and core.raycast(origin,Vector3.new(0,-7,0)) then
			origin = origin + (goalPos - origin).Unit*1
		else
			origin = origin + (goalPos - origin).Unit*-1
			break
		end
		if maxIterations <= 0 then
			break
		end
	until false 
	
	self.Human:MoveTo(origin)
end

function movement:ChaseTargetDirectly()
	self.Human:MoveTo(self:GetTarget().Position)
end

return movement
