local Debugger = {}

local myModel = script.Parent.Parent.Parent
local myRoot = myModel.HumanoidRootPart

local mySettings = myModel.Settings
local debugOption = mySettings.Debug.Value

function Debugger.print(msg)
	if script.Output.Value then
		print(msg)
	end
end

function Debugger.visualizePath(path)
	if not script.Paths.Value then return end
	
	for i,v in ipairs(script:GetChildren()) do
		if v.Name == "Waypoint" then
			v:Destroy()
		end
	end
	
	local waypoints = path:GetWaypoints()
	for i,waypoint in ipairs(waypoints) do
		local p = Instance.new("Part")
		p.Size = Vector3.new(1,1,1)
		p.CanCollide = false
		p.Shape = Enum.PartType.Ball
		p.Transparency = 0.5
		p.Material = Enum.Material.Neon
		p.BrickColor = BrickColor.Random()
		p.Anchored = true
		p.Position = waypoint.Position
		p.Name = "Waypoint"
		p.Parent = script
	end
end

local p = Instance.new("Part")
if debugOption then
	p.Size = Vector3.new(3,3,3)
	p.CanCollide = false
	p.Shape = Enum.PartType.Ball
	p.Transparency = 0.5
	p.Material = Enum.Material.Neon
	p.BrickColor = BrickColor.new("Bright bluish green")
	p.Anchored = true
	p.Parent = script
end
function Debugger.waypoint(pos)
	if not debugOption then return end
	p.Position = pos
end

function Debugger.showRay(origin,dir)
	if not debugOption or not script.Beams.Value then return end
	local a0 = Instance.new("Attachment")
	a0.Parent = workspace.Terrain
	a0.Position = origin
	a0.Name = "DebugAttachment"
	local a1 = Instance.new("Attachment")
	a1.Parent = workspace.Terrain
	a1.Name = "DebugAttachment"
	a1.Position = origin+dir
	local beam = Instance.new("Beam")
	beam.Parent = script.Parent
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = 0.2
	beam.Width1 = 0.2
	beam.FaceCamera = true
	game:GetService("Debris"):AddItem(beam,3)
	game:GetService("Debris"):AddItem(a0,3)
	game:GetService("Debris"):AddItem(a1,3)
end

function Debugger.mark(pos)
	if not debugOption or not script.Marks.Value then return end
	local p = Instance.new("Part")
	p.Size = Vector3.new(2,2,2)
	p.CanCollide = false
	p.Shape = Enum.PartType.Ball
	p.Transparency = 0.5
	p.Material = Enum.Material.Neon
	p.BrickColor = BrickColor.new("Really red")
	p.Anchored = true
	p.Name = "Waypoint"
	p.Parent = script
	p.Position = pos
end

local beams = {}
function initBeams()
	for i = 1, 100 do
		local attach0 = Instance.new("Attachment")
		attach0.Parent = workspace.Terrain
		attach0.Name = "DebugAttachment"

		local attach1 = Instance.new("Attachment")
		attach1.Parent = workspace.Terrain
		attach1.Name = "DebugAttachment"

		local b = Instance.new("Beam")
		b.FaceCamera = true
		b.Color = ColorSequence.new(Color3.new(0,1,0))
		b.Parent = myModel.Beams
		b.Width0 = 0.3
		b.Width1 = 0.3
		b.Attachment0 = attach0
		b.Attachment1 = attach1
		table.insert(beams,{
			beam = b,
			a0 = attach0,
			a1 = attach1
		})
	end
end
if debugOption then
	initBeams()
end

local currentBeam = 1
function Debugger.createBeam(origin,direction)
	
	if not debugOption or not script.Beams.Value then return end

	currentBeam = currentBeam + 1
	if currentBeam > #beams then
		currentBeam = 1
	end

	beams[currentBeam].a0.WorldPosition = origin
	beams[currentBeam].a1.WorldPosition = origin+direction

	return beams[currentBeam].beam
end

function Debugger.newBeam(origin,direction)
	
	
	local a0 = Instance.new("Attachment")
	a0.Parent = workspace.Terrain
	
	local a1 = Instance.new("Attachment")
	a1.Parent = workspace.Terrain

	a0.WorldPosition = origin
	a1.WorldPosition = origin+direction
	
	local beam = Instance.new("Beam")
	beam.Width0 = 0.2
	beam.Width1 = 0.2
	beam.Parent = workspace
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	
	game:GetService("Debris"):AddItem(beam,3)
end

local sb = Instance.new("SelectionBox")
if debugOption then
	sb.Parent = myModel
	sb.Color3 = Color3.new(1,0,0)
	sb.LineThickness = 0.1	
end
function Debugger.selectionBox(instance)
	if not debugOption then return end
	sb.Adornee = instance
end

local lineEnd = Instance.new("Attachment")
function Debugger.createLine(instance)
	if not debugOption then return end
	lineEnd.Parent = instance
end

return Debugger
