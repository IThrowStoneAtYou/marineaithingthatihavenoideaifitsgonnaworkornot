local Formulas = {}

-- nerd stuff

function Formulas.getAimVector3(myRoot, target, bulletVel)
	
	local dist = (myRoot.Position - target.Position).Magnitude
	
	--local toTarget = target.Position - (myRoot.Position + myRoot.Velocity * dist/15)
	local toTarget = target.Position - myRoot.Position

	local a = target.Velocity:Dot(target.Velocity) - (bulletVel * bulletVel)
	local b = 2 * target.Velocity:Dot(toTarget)
	local c = toTarget:Dot(toTarget)

	local p = - b / (2 * a)
	local q = math.sqrt((b * b) - 4 * a * c) / (2 * a)

	local t1 = p - q
	local t2 = p + 1
	local t

	if t1 > t2 and t2 > 0 then
		t = t2
	else 
		t = t1
	end

	local aimSpot = target.Position + target.Velocity * t

	if aimSpot.X == "nan" then
		return Vector3.new(0,0,0)
	end

	return aimSpot
end

local velocity = 85


function computeLaunchAngle(dx,dy,grav)
	local g = math.abs(grav)
	local inRoot = (velocity*velocity*velocity*velocity) - (g * ((g*dx*dx) + (2*dy*velocity*velocity)))
	if inRoot <= 0 then
		return .25 * math.pi
	end
	local root = math.sqrt(inRoot)
	local inATan1 = ((velocity*velocity) + root) / (g*dx)

	local inATan2 = ((velocity*velocity) - root) / (g*dx)
	local answer1 = math.atan(inATan1)
	local answer2 = math.atan(inATan2)
	if answer1 < answer2 then return answer1 end
	return answer2
end

function computeDirection(vec)
	local lenSquared = vec.magnitude * vec.magnitude
	local invSqrt = 1 / math.sqrt(lenSquared)
	return Vector3.new(vec.x * invSqrt, vec.y * invSqrt, vec.z * invSqrt)
end

function Formulas.CalculateArc(handle: Instance,targetPos: Vector3, speed: IntValue)

	velocity = speed

	local dir = targetPos - handle.Position
	dir = computeDirection(dir)

	local launch = handle.Position + 5 * dir

	local delta = targetPos - launch

	local dy = delta.y

	local new_delta = Vector3.new(delta.x, 0, delta.z)
	delta = new_delta

	local dx = delta.Magnitude
	local unit_delta = delta.Unit

	-- acceleration due to gravity in RBX units
	local g = (-9.81 * 20)

	local theta = computeLaunchAngle( dx, dy, g)

	local vy = math.sin(theta)
	local xz = math.cos(theta)
	local vx = unit_delta.x * xz
	local vz = unit_delta.z * xz

	return (Vector3.new(vx,vy,vz) * velocity)
end

return Formulas
