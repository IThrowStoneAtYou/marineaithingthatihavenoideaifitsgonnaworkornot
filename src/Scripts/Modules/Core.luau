local core = {}

local playersService = game:GetService("Players")
local teamsService = game:GetService("Teams")
local marine = script.Parent.Parent.Parent
local myHead = marine.Head

local event = Instance.new("BindableEvent")
function core.spawn(func,...)
	local connection = event.Event:Connect(func)
	event:Fire(...)
	connection:Disconnect()
end

function core.tick()
	return DateTime.now().UnixTimestamp
end

-- Allows me to add expensive functions to very fast loops but only run them so often.
-- This is really good for the aiming loops that updates 60 times a second. 
local tags = {}
function core.runAtTS(tag: StringValue, delayTime: IntValue, func: Function)
	if tags[tag] then
		if core.tick() - tags[tag].ts > delayTime then
			if func then 
				func()
			end
			tags[tag].ts = core.tick()
			return true
		end
	else
		tags[tag] = {
			ts = core.tick()
		}
		if func then 
			func() -- yes
		end
		return true
	end
	return false
end

--Calculates an angle in relation to another part.
function core.findYaw(pos1: Vector3, pos2: Vector3, part: Instance)
	local yOrientation = part.Orientation.Y
	local rot = math.atan2(pos2.Z-pos1.Z,pos2.X-pos1.X)


	local desiredAngle = math.deg(rot)+yOrientation+90
	if desiredAngle > 180 then
		desiredAngle = - (360 - desiredAngle)
	elseif desiredAngle < -180 then
		desiredAngle = 360 + desiredAngle
	end	

	return desiredAngle
end

function core.checkDist(pos1,pos2)
	if typeof(pos1) ~= "Vector3" then pos1 = pos1.Position end -- "vector3" so no more confusing number to calc
	if typeof(pos2) ~= "Vector3" then pos2 = pos2.Position end
	return (pos1-pos2).Magnitude
end

function core.applyDamage(human,dmg)
	if not core.isAlly(human.Parent) and human.Health > 0 then
		human:TakeDamage(dmg)
	end
end

-- Finds the angle between a Part/Attachment and the end position
function core.findRelativePitch(startPos, endPos, relativeInstance, axis)
	
	local dX = startPos.X - endPos.X
	local dY = startPos.Y - endPos.Y
	local dZ = startPos.Z - endPos.Z
	
	local xRot = relativeInstance.Orientation.X
	local pitch = math.atan2(math.sqrt(dZ * dZ + dX * dX), dY) --+ math.pi
	
	
	pitch = math.deg(pitch) - 90 + xRot
	if pitch > 180 then
		pitch = -(360 - pitch)
	elseif pitch < -180 then
		pitch = 360 + pitch
	end

	return pitch
end

-- Finds the angle between a Part/Attachment and the end position
function core.findRelativeYaw(startPos, endPos, relativeInstance, axis)
	axis = axis or "x"
	
	local yOrientation = relativeInstance.Orientation.Y
	local rot = math.atan2(endPos.Z-startPos.Z,endPos[axis]-startPos[axis])
	
	local desiredAngle = math.deg(rot) + yOrientation + 90
	if desiredAngle > 180 then
		desiredAngle = -(360 - desiredAngle)
	elseif desiredAngle < -180 then
		desiredAngle = 360 + desiredAngle
	end
	
	return desiredAngle
end

function core.getHuman(instance)
	if instance:IsA("Tool") or instance:IsA("Accessory") then
		instance = instance.Parent
	end
	
	local human = instance:FindFirstChild("Humanoid")
	if not human and instance.Parent and instance.Parent:IsA("Model") then
		return core.getHuman(instance.Parent)
	end
	
	return human
end

-- TODO: This needs to be fixed at some point
function core.checkPotentialSight(target)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {marine}

	local dist = core.checkDist(myHead,target)
	local pos2 = Vector3.new(target.Position.X,myHead.Position.Y,target.Position.Z)
	local result = workspace:Raycast(myHead.Position,(pos2 - myHead.Position).Unit*dist,raycastParams)

	if result then
		return false
	else
		--return true
		return false
	end
end

function core.raycast(origin, dir)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {marine}

	local result = workspace:Raycast(origin,dir,raycastParams)

	if result then
		return true, result
	else
		return false
	end
end

local allies = {}
local team = marine.Settings.Team.Value
local attackPlayers = marine.Settings.AttackPlayers.Value
local playerTeamsList = marine.Settings.PlayerTeams

function core.isAlly(model)
	--Check and see if they are on our team, if they are break the loop.
	local isAlly = false
	local targetTeam
	if model:FindFirstChild("Team") then
		targetTeam = model.Team.Value
	elseif model:FindFirstChild("Settings") and model.Settings:FindFirstChild("Team") then
		targetTeam = model.Settings.Team.Value			
	end
	for _,ally in ipairs(allies) do
		if model.Name == ally then
			isAlly = true
		end
	end
	if (targetTeam and targetTeam == team) or (not attackPlayers and game.Players:GetPlayerFromCharacter(model)) then
		isAlly = true
	end
	if attackPlayers then
		local player = playersService:GetPlayerFromCharacter(model)
		if player then
			local teamColor = player.TeamColor
			if not player.Neutral then
				for i,v in pairs(playerTeamsList:GetChildren()) do
					if v:IsA("BrickColorValue") then
						if v.Value == teamColor then
							isAlly = true
						end
					end
				end
			end
		end
	end
	
	return isAlly
end

function core.checkDirectPath(npc, target, ignoredInstance, origin)
	origin = origin or myHead.Position
	
	local dist = core.checkDist(origin,target.Position)
	local dir = (target.Position - origin).Unit
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {npc.Instance,ignoredInstance}
	local result = workspace:Raycast(origin,dir*dist,raycastParams)

	--Just use random parent if we pass a waypoint
	local targetParent = game.Lighting
	if typeof(target) == "Instance" then
		targetParent = target.Parent
	end

	--Raycast directly to target to make sure we don't hit anything or we hit the target.
	if (result and result.Instance.Parent and result.Instance:IsDescendantOf(targetParent)) or not result then

		--Raycast down every 2 studs to ensure there are not holes in the ground
		local down = Vector3.new(0, -5, 0)
		for i = 0, dist, 3 do
			local newOrigin = origin + dir * i
			result = workspace:Raycast(newOrigin, down, raycastParams)
			if not result then
				return false
			end
		end
		return true

	else
		return false
	end
end

function core.isLine(p1: Vector3, p2: Vector3, ignoreList: Table)
	ignoreList = ignoreList or {}

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = ignoreList

	local dist = core.checkDist(p1,p2)

	local result = workspace:Raycast(p1, (p2 - p1).Unit*dist, raycastParams)

	return not result
end

function core.calcRandomOffset(accuracy: IntValue)

	-- Add inaccuracy
	local offset = math.random(0, 100 - accuracy) / 20

	if math.random(2) == 1 then
		offset = -offset
	end

	return offset
end

function core.getEnemyVehicleInstance(target)
	if not target or not target.Parent then return end
	-- Get target vehicle information if necssary
	-- We want to ignore their vehicle so we can shoot it
	local query = target.Parent:FindFirstChild("Query")
	if query then
		local targetNPC = query:Invoke()
		if targetNPC.Vehicle and targetNPC.Vehicle.InVehicle and targetNPC.Vehicle.Instance then
			return targetNPC.Vehicle.Instance
		end
	end
end

return core