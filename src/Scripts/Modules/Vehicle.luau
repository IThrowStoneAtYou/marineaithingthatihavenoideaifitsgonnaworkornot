-- propbably not gonna be used, either remove vehicle support or not...

local Vehicle = {}
Vehicle.__index = Vehicle

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

-- Constants
MARINE_VEHICLE_TAG = "MarineVehicle"

-- Modules
local pathing = require(script.Parent.Pathing)
local debugger = require(script.Parent.Debug)
local core = require(script.Parent.Core)


function Vehicle.new(vehicle, npc)
	
	local o = {}
	o.Instance = vehicle
	o.Occupant = npc
	o.Body = vehicle.Body.Body
	o.FrontBumper = vehicle.Body.Body.FrontBumper
	o.RearBumper = vehicle.Body.Body.RearBumper
	o.Seat = vehicle.VehicleSeat
	o.Team = vehicle.Settings.Team
	o.InVehicle = false
	o.Role = "Driver"
	
	vehicle:SetAttribute(o.Role, true)
	
	setmetatable(o, Vehicle)
	
	o:SetTeam(npc.Team)
	
	return o
end

function Vehicle:Destroy()
	self.Instance:SetAttribute(self.Role, false)
	if not self.Instance:GetAttribute("Driver") and not self.Instance:GetAttribute("Gunner") and not self.Instance:GetAttribute("Passenger") then
		self:SetTeam("")
	end
	self = nil
end

function Vehicle:Enter()

	self.Occupant:YieldWeapons()
	self.Seat:Sit(self.Occupant.Human)
	
	RunService.Heartbeat:Wait()
	RunService.Heartbeat:Wait()
	
	self.Occupant.LeftShoulder.Enabled = false
	self.Occupant.RightShoulder.Enabled = false
	self.Occupant.ShoulderHingeR.Enabled = true
	self.Occupant.ShoulderHingeL.Enabled = true
	
	self.InVehicle = true
end


function Vehicle:Exit()
	self.Instance:SetAttribute("Failures",0)
	
	self.Occupant.ShoulderHingeR.Enabled = false
	self.Occupant.ShoulderHingeL.Enabled = false	
	self.Occupant.LeftShoulder.Enabled = true
	self.Occupant.RightShoulder.Enabled = true
	
	-- TODO: Why is this set here but not in Enter?
	if self.Seat.Parent then
		pcall(function()
			self.Seat:SetNetworkOwnershipAuto()
		end)
	end
	self.Occupant:SetVehicleTimestamp()
	self.Occupant.Human.Sit = false
	
	self:Destroy()
	
	return nil
end

function Vehicle:IsInVehicle()
	return self.InVehicle
end

function Vehicle:Go(speed: number)
	self.Seat.ThrottleFloat = speed
end

function Vehicle:SmartGo(speed, length)

	local backwards = false
	if speed < 0 then
		backwards = true
	end
	
	self:Go(speed)

	for i=1, length*10 do
		if self:CheckBumper(backwards) then
			break
		end
		task.wait(0.1)
	end

	self:Go(0)
	self:TurnTowardsAngle(0)
end

-- pos is the position of the NPC root
-- Returns a tuple of the Vehicle and distance
function Vehicle.findNearest(npc: ObjectValue, requireDriver: BoolValue, role: string)
	local Vehicles = CollectionService:GetTagged(MARINE_VEHICLE_TAG)
	local bestDist = math.huge
	local bestVeh = nil
	for i, tempVehicle in ipairs(Vehicles) do
		
		if Vehicle.isValid(npc, tempVehicle) and tempVehicle:GetAttribute(role) == false
			and not Vehicle.isBlacklisted(npc, tempVehicle) and (not requireDriver or tempVehicle:GetAttribute("Driver")) then
			
			local tempDist = (npc.Root.Position - tempVehicle.Body.Body.Position).Magnitude
			if tempDist < bestDist then
				bestDist = tempDist
				bestVeh = tempVehicle
			end
		end
	end
	
	return bestVeh, bestDist
end

-- Includes NPC related checks once using the vehicle.
-- Will automatically correct weird stuff that happens while driving the vehicle.
-- TODO: Add checks that include the vehicle flipping, blown up, missing wheels
function Vehicle:Validate()
	if self.Seat.Occupant ~= self.Occupant.Human or not Vehicle.isValid(self.Occupant, self.Instance) then
		self:Exit()
		return false
	end
	return true
end

function Vehicle:GetFree()
	if not self:CheckBumper(true) then
		-- If we can reverse then try it.
		self:TurnRandom()
		self:SmartGo(-0.4,2)
		
	elseif not self:CheckBumper() then
		-- If we can move forward then try it.
		self:TurnRandom()
		self:SmartGo(0.4,2)
	end
end

function Vehicle.isFree(veh)
	return not veh:GetAttribute("Driver")
end

function Vehicle.isValid(npc,veh)
	-- TODO: More logic like checking the tire status, if it is stuck, upsidedown, destroyed etc
	local bodyModel = veh:FindFirstChild("Body")
	return veh.Parent and bodyModel and bodyModel:FindFirstChild("Body") and veh.Humanoid.Health > 0
		and bodyModel.Body.CFrame.UpVector.Y > 0.5 and Vehicle.checkTeam(npc, veh)
end

-- Returns true if blocked
function Vehicle:CheckBumper(back)
	
	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = {self.Occupant.Instance,self.Instance}
	local VehicleLength = self.Instance:GetExtentsSize().Z
	local VehicleWidth = math.ceil(self.Instance:GetExtentsSize().X/3)
	for i = -VehicleWidth, VehicleWidth do

		--Raising bumper slightly to avoid weirdness on uneven ground
		local origin = (self.FrontBumper.WorldCFrame * CFrame.new(i,1,3)).Position
		local dir = self.FrontBumper.WorldCFrame.LookVector*3
		if back then
			origin = (self.RearBumper.WorldCFrame * CFrame.new(i,1,3)).Position
			dir = -dir
		end


		local result = workspace:Raycast(origin,dir,rayParams)
		debugger.showRay(origin,dir)
		if result and result.Instance then
			--return result.Instance
			return true
		end
		
		-- Check downwards to ensure we don't drive off a cliff (hopefully)
		origin += dir
		dir = Vector3.new(0,-5,0)
		result = workspace:Raycast(origin,dir,rayParams)
		debugger.showRay(origin,dir)
		if not result then
			return true
		end
	end
end

function checkBrokenPoints(veh, path)

	local waypoints = path:GetWaypoints()
	local confirmedWaypoints = {}

	for i,waypoint in ipairs(waypoints) do

		--Raycast below each waypoint to ensure there is ground underneath
		--Prevents waypoints that are glitched under the map
		--5/7/21 Fixed bug on baseplate maps. Waypoints were slightly too low causing the whole path
		--to return as broken. Fixed this by raising the initial waypoint height by half a stud.
		local rayParams = RaycastParams.new()
		rayParams.FilterDescendantsInstances = {veh.Occupant.Instance}
		local result = workspace:Raycast(waypoint.Position+Vector3.new(0,0.5,0),Vector3.new(0,-5,0), rayParams)
		if result then
			table.insert(confirmedWaypoints,waypoint)
		end
	end

	return confirmedWaypoints
end

function findTurns(veh, path)

	--Found line from waypoint 1 to 40
	--Waypoints are in a line if x or z value changes very little over a period of time

	local waypoints = checkBrokenPoints(veh, path)
	local currentDifference = Vector2.new(0,0)

	local importantWaypoints = {}

	--First find which axis the line is by finding the axis with the smallest difference
	--Then loop through next points and check axis until axis has a difference > 1
	for i,waypoint in ipairs(waypoints) do
		if i ~= #waypoints then
			local difference = (Vector2.new(waypoint.Position.X,waypoint.Position.Z) - Vector2.new(waypoints[i+1].Position.X,waypoints[i+1].Position.Z))
			if ((currentDifference - difference).Magnitude) > 0.5 then
				debugger.mark(waypoint.Position)
				table.insert(importantWaypoints,waypoint)
			end
			currentDifference = difference
		end
	end

	--Ensure final point is included also
	table.insert(importantWaypoints,waypoints[#waypoints])

	return importantWaypoints
end

function Vehicle:IsAtWaypoint(pos)
	return (pos - self.FrontBumper.WorldPosition).Magnitude < self.Occupant.Settings.Vehicle.MaxWaypointDist.Value
end

function Vehicle:TurnTowardsAngle(desiredAngle)
	
	self.Occupant.ShoulderHingeR.TargetAngle = -desiredAngle
	self.Occupant.ShoulderHingeL.TargetAngle = desiredAngle

	--Changed 15 to 30 turning too sharply before
	local turndir = desiredAngle/55

	self.Seat.SteerFloat = turndir

	return desiredAngle
end

local maxSpeed = 0.5
function Vehicle:DriveTowards(pos)

	local currentDist = (self.FrontBumper.WorldPosition - pos).Magnitude
	
	local desiredAngle = core.findYaw(self.FrontBumper.WorldPosition,pos,self.Occupant.Root)
	

	--Changed from 20 to 100 to make faster turns
	local speed = math.abs(50/desiredAngle)
	
	-- Reverse if too tight of a turn
	if (desiredAngle > 100 or desiredAngle < -100) and not self:CheckBumper(true) then

		self:SmartReverse(pos,-desiredAngle)
	end
	
	self:TurnTowardsAngle(desiredAngle)

	--self.Seat.ThrottleFloat = speed
	self:Go(speed)
end

-- The goal of this is to reverse while our angle is getting smaller. 
-- Angle of 0 should be the front so we should continue until it doesn't get closer to this value. 
function Vehicle:SmartReverse(pos, turnAngle, minReverseTime)
	
	minReverseTime = minReverseTime or 0
	
	--self.Seat.ThrottleFloat = -0.4
	self:Go(-0.4)
	
	-- Should allow the NPC to back straight up into a waypoint
	if math.abs(turnAngle) > 170 then
		turnAngle = 0
	end
	
	
	self:TurnTowardsAngle(turnAngle)
	
	local currentAngle = math.abs(core.findYaw(self.FrontBumper.WorldPosition,pos,self.Occupant.Root))
	local prevAngle = math.huge
	
	-- Continously backsup until we are being counter productive or at the waypoint.
	local lastMove = tick()
	while currentAngle <= prevAngle and not self:IsAtWaypoint(pos) do
		prevAngle = currentAngle
		currentAngle = math.abs(math.abs(core.findYaw(self.FrontBumper.WorldPosition,pos,self.Occupant.Root)))
		
		if self:GetSpeed() > 2 then
			lastMove = tick()
		end
		
		if currentAngle < 20 then
			break
		elseif tick() - lastMove > 0.5 then
			self:Go(1)
			task.wait(0.5)
			break
		elseif self:CheckBumper(true) then
			break
		elseif not self:Validate() then
			break
		end
		task.wait(0.2)
	end
	
	-- Ensure we backup for the minimum amount time
	task.wait((tick() + minReverseTime) - tick())
end

function Vehicle:TurnRandom()
	local turn = 45
	if math.random(2) == 1 then 
		turn = -turn 
	end
	self:TurnTowardsAngle(turn)
end

function Vehicle:Reverse(length)
	
	
	--self.Seat.ThrottleFloat = -0.2
	self:Go(-0.4)
	
	for i=1, length*10 do
		if self:CheckBumper(true) then
			break
		end
		task.wait(0.1)
	end

	self:Go(0)
	self:TurnTowardsAngle(0)
end

local pathFailures = 0
local maxPathFailures = 3
function Vehicle:DrivePath(path,instance)
	
	-- Now we can determine seperate logic if we are driving to an instance such as
	-- our ally or our enemy. 
	local currentTarget = nil
	local toTarget = false
	if instance == self.Occupant:GetTarget() then
		currentTarget = instance
		toTarget = true
	end
	
	local waypointTimeout = 20
	local waypointsFailed = 0
	local maxWaypointsFailed = 3
	local currentDist = math.huge
	local bestDist = math.huge
	local bestDistTimeout = 3 -- Seconds...
	local velocityTimeout = 10
	local killPath = false

	local waypoints = findTurns(self, path)

	for i,waypoint in ipairs(waypoints) do
		
		local waypointProgressTimestamp = tick()
		
		if killPath or not self.Instance then
			break
		end

		local reversed = false

		waypointTimeout = (self.FrontBumper.WorldPosition-waypoint.Position).Magnitude/2
		waypointTimeout = math.clamp(waypointTimeout,100,1000)

		while not self:IsAtWaypoint(waypoint.Position) do
			
			reversed = false

			debugger.waypoint(waypoint.Position)

			-- If an obstacle blocks our path and slows our velocity to almost a stop reverse.
			local velocity = self.Seat.Velocity.Magnitude
			if not reversed and (self.FrontBumper.WorldPosition - waypoint.Position).Magnitude >= currentDist and velocity < 5 then
				if self:CheckBumper() then
					local desiredAngle = core.findYaw(self.FrontBumper.WorldPosition,waypoint.Position,self.Occupant.Root)
					self:SmartReverse(waypoint.Position, -desiredAngle, 1)
					reversed = true
				end
			end
			
			local closer = false
			local newDist = (self.FrontBumper.WorldPosition - waypoint.Position).Magnitude
			if currentDist > newDist then
				closer = true
			end
			
			currentDist = newDist
			if velocity<1 then
				velocityTimeout = velocityTimeout-1
				if velocityTimeout<=0 then
					velocityTimeout = 10
					local desiredAngle = core.findYaw(self.FrontBumper.WorldPosition,waypoint.Position,self.Occupant.Root)
					self:SmartReverse(waypoint.Position, -desiredAngle, 1)
					reversed = true
					--self:Reverse(1.5)
				end
			else
				velocityTimeout = 10
			end

			--Ensure we are making progress to our end goal.
			if closer then
				--bestDistTimeout = 10
				waypointProgressTimestamp = tick()
			else
				--bestDistTimeout = bestDistTimeout - 1
				--if bestDistTimeout <= 0 then
				if tick() - waypointProgressTimestamp > bestDistTimeout then
					killPath = true
					pathFailures = pathFailures + 1
					break
				end
			end

			--Ensure we aren't stuck on the same waypoint for too long.
			--This may be redundant with the new end goal position timeout.
			if not closer then
				waypointTimeout = waypointTimeout - 1
			end
			if waypointTimeout <= 0 then --and myRoot.Velocity.Magnitude < 3
				waypointsFailed = waypointsFailed + 1

				if i == #waypoints or waypointsFailed >= maxWaypointsFailed or not core.checkDirectPath(self.Occupant,waypoints[i+1],self.Instance,self.FrontBumper.WorldPosition) then
					pathFailures = pathFailures + 1
					killPath = true
					break
				end
			end

			-- Skip to next waypoint if we can see it and close enough to current one.
			-- This results in very natural looking turns.
			if self.Seat.Velocity.Magnitude>50 and currentDist < 20 and i ~= #waypoints and core.checkDirectPath(self.Occupant,waypoints[i+1],self.Instance,self.RearBumper.WorldPosition) then
				break
			end
			
			if instance then
				-- If we are driving to a target we need to do additional checks.
				if toTarget then
					if not self.Occupant:CheckTarget() then
						killPath = true
						break
					end
					
					local dist = core.checkDist(self.Occupant.Root,currentTarget)
					if dist < self.Occupant.Settings.Vehicle.MinDrivingDist.Value then
						
						-- If I am alone and close enough the target then I can stop if I can see.
						-- If I have a gunner and I am close enough then I can stop if the GUNNER can see. 
						if (self:CheckTurretSightToTarget() and self.Instance:GetAttribute("Gunner"))
							or (self.Occupant:CheckSightToTarget() and not self.Instance:GetAttribute("Gunner"))then
							killPath = true
							break
						end
						
					end
					
					if currentTarget ~= self.Occupant:GetTarget() then
						killPath = true
						break
					end
				else
					-- If we are driving to an instance it is probably to pick up the gunner.
					local dist = core.checkDist(self.Body,instance)
					if dist <= self.Occupant.Settings.Vehicle.MinDrivingDist.Value * 0.75 then
						killPath = true
						break
					end
				end
			end
			
			-- TODO Idk if these values will update from outside of the module
			if self.Occupant:GetTarget() and self.Occupant.GoingHome then
				killPath = true
				break
			end
			
			if not self:Validate() then
				break
			end

			self:DriveTowards(waypoint.Position)

			task.wait()
		end

		if i == #waypoints and waypointsFailed == 0 then
			pathFailures = 0
		end
	end

	if self.Instance then
		self:Go(0)
	end
end

local VehicleBlacklist = {}
function Vehicle.isBlacklisted(npc,vehModel)
	for _, veh in pairs(VehicleBlacklist) do
		if veh.Instance == vehModel then --and npc:GetTarget() == veh.Target then
			return tick() - veh.Time < npc.Settings.Vehicle.BlacklistDelay.Value
		end
	end
	return false
end

-- Prevent a Vehicle from being used for a certain target
function Vehicle:Blacklist(target)
	for i, veh in pairs(VehicleBlacklist) do
		if veh.Instance == self.Instance and veh.Target == target then
			VehicleBlacklist[i].Time = tick()
			return
		end
	end
	
	table.insert(VehicleBlacklist, {
		Time = tick(),
		Instance = self.Instance,
		Target = target
	})
end

function Vehicle:GetSpeed()
	return self.Seat.Velocity.Magnitude
end

-- True/False if we were able to get some kind of path going.
function Vehicle:DriveTo(pos,instance)
	
	if instance and instance == self.Occupant:GetTarget() then
		local points = self.Occupant:GetTargetPoints()
		for i,v in ipairs(points) do
			local vehPath = pathing.getVehiclePath(self.Instance, v, 20, true)
			if vehPath then
				self:DrivePath(vehPath, instance)
				return true
			end
		end
	end
	
	
	local vehPath = pathing.getVehiclePath(self.Instance, pos, 20)
	if vehPath then
		self:DrivePath(vehPath,instance)
		return true
	end
	return false
end

-- Returns true/false based on if the the turret would be able to shoot the target
function Vehicle:CheckTurretSightToTarget()
	local top = self.Instance.Turret.Top
	return core.isLine(top.Position,self.Occupant:GetTarget().Position,{
		self.Occupant:GetTarget().Parent,
		self.Instance,
		self.Occupant.Instance
	})
end


function Vehicle:GetAllies()
	local allies = {}
	if self.Instance:GetAttribute("Gunner") then
		local allyModels = CollectionService:GetTagged(self.Occupant.Settings.Team.Value)
		for i,v in ipairs(allyModels) do
			local query = v:FindFirstChild("Query")
			if query then
				local allyNPC = query:Invoke()

				-- Find allies we need to pickup / wait for that aren't already in the vehicle. 
				if allyNPC.Vehicle and allyNPC.Vehicle.Instance == self.Instance and not allyNPC.Vehicle.InVehicle
					and allyNPC.Vehicle.Role ~= "Driver" then
					--return allyNPC
					table.insert(allies,allyNPC)
				end
			end
		end
	end
	return allies
end

-- Returns true/false if we need to pick up more allies.
function Vehicle:PickupNearestAlly()
	
	local allies = self:GetAllies()
	local ally
	
	-- Get the closest ally
	local dist = math.huge
	for _,tempAlly in allies do
		local tempDist = core.checkDist(tempAlly.Root,self.Occupant.Root)
		if tempDist < dist then
			dist = tempDist
			ally = tempAlly
		end
	end
	
	-- No allies to pickup
	if not ally then return end
	
	if dist > 20 then
		self:DriveTo(ally.Root.Position, ally.Root)
	end
	
	return true
end

function Vehicle:SetTeam(team: string)
	self.Team.Value = team
end

-- Checks if the vehicle's team is none or ally.
function Vehicle.checkTeam(npc: ObjectValue, vehicleModel: Model)
	local team = vehicleModel.Settings.Team.Value
	return team == npc.Team or team == ""
end

return Vehicle
