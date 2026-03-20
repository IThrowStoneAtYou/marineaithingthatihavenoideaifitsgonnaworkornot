local Vehicle = require(script.Parent.Vehicle)

local Passenger = {}
Passenger.__index = Passenger
setmetatable(Passenger, Vehicle)

-- Constructor
function Passenger.new(vehicle, npc)
	
	local o = {}
	o.Instance = vehicle
	o.Occupant = npc
	o.Seat = vehicle.Seat
	o.Role = "Passenger"
	o.InVehicle = false
	o.Body = vehicle.Body.Body
	o.Door = vehicle.Body.Body.SideDoor
	o.Team = vehicle.Settings.Team
	
	vehicle:SetAttribute(o.Role, true)
	
	setmetatable(o, Passenger)
	
	o:SetTeam(npc.Team)
	
	return o 
end

function Passenger:Enter()
	self.Seat:Sit(self.Occupant.Human)
	self.Occupant:YieldWeapons()
	self.InVehicle = true
end

function Passenger:Exit()
	self.Occupant.Human.Sit = false
	if not self.Occupant:IsDead() then
		task.wait()
		self.Occupant.Root.CFrame = self.Door.WorldCFrame * CFrame.new(1.5,0.5,0)
	end
	self.Occupant:SetVehicleTimestamp()
	self:Destroy()
	return nil
end


return Passenger
