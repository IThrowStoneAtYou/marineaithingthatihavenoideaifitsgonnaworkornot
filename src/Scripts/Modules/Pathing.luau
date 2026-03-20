local pathing = {}

local debugger = require(script.Parent.Debug)

local pathFinding = game:GetService("PathfindingService")
function pathing.generatePath(startPos,goal,vehicle)
	
	local path
	if vehicle then

		local size = vehicle:GetExtentsSize()
		local radius = size.X

		local pathParams = {
			AgentRadius = radius,
			AgentHeight = size.Y,
			AgentCanJump = false
		}
		path = pathFinding:CreatePath(pathParams)
	else
		path = pathFinding:CreatePath()
	end
	
	path:ComputeAsync(startPos,goal)

	return path

end

function pathing.getVehiclePath(vehicle: Instance, pos: Vector3, minDrivingDist: IntValue, noStubs: BoolValue)

	--local veh = npc.Vehicle
	
	local body = vehicle.Body.Body
	local frontBumper = body.FrontBumper
	local rearBumper = body.RearBumper

	local startPos = frontBumper.WorldPosition + frontBumper.WorldCFrame.LookVector

	-- For loop for checking paths from the front bumper and rear bumper. 
	for _=1, 2 do

		local mark = debugger.mark(startPos)
		--mark.BrickColor = BrickColor.new("Pink")

		local path = pathing.generatePath(startPos,pos,vehicle)
		if path.Status == Enum.PathStatus.Success then
			--This path will take us directly to the target
			return path
		elseif not noStubs then
			--Generate walking path and see how much of it is drivable
			local tempPath = pathing.generatePath(startPos,pos,false)
			debugger.visualizePath(tempPath)
			if tempPath.Status == Enum.PathStatus.Success then
				local tempWaypoints = tempPath:GetWaypoints()
				for index = 1, 5 do

					local targetWaypoint = math.ceil(#tempWaypoints - #tempWaypoints*(index/6))


					--Make sure path contains at least 10 waypoints
					if targetWaypoint > 10 then --mySettings.MinDrivingDist.Value
						local waypointPos = tempWaypoints[targetWaypoint].Position

						local mark = debugger.mark(waypointPos)

						--Ensure path length meets our minimum driving distance requirement
						--If path is too short we should just walk it
						if (startPos - waypointPos).Magnitude > minDrivingDist then
							--if core.checkDist(startPos,waypointPos) > minDrivingDist then
							local path = pathing.generatePath(startPos,waypointPos,vehicle)
							if path.Status == Enum.PathStatus.Success then
								debugger.visualizePath(path)
								return path
							end
						else
							break
						end
					end

				end
			end
		end

		startPos = rearBumper.WorldPosition + rearBumper.WorldCFrame.LookVector*2
	end
end

return pathing
