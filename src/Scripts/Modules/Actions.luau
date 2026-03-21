local actions = {}

--Services
local debrisService = game:GetService("Debris")
local runService = game:GetService("RunService")
local tweenService = game:GetService("TweenService")

--Required Modules
local modules = script.Parent
local core = require(modules.Core)
local formulas = require(modules.Formulas)

-- references --
local marine = script.Parent.Parent.Parent
local myHuman = marine.Humanoid
local myRoot = marine.HumanoidRootPart
local m4 = marine.M4
local reloadSound = m4.Reload
--local magazine = marine.Mag

local myHead = marine.Head
local myTorso = marine.Torso
local neck = myTorso.Neck
local lShoulder = myTorso["Left Shoulder"]
local rShoulder = myTorso["Right Shoulder"]
local lArmWeld = myTorso["Left Arm Weld"]
local rArmWeld = myTorso["Right Arm Weld"]
local lArm = marine["Left Arm"]
local rArm = marine["Right Arm"]
local m4Weld = m4["M4 Weld"]

local mySettings = marine.Settings
local ignoreFolder = mySettings.IgnoreFolder.Value

if ignoreFolder == nil then
	repeat task.wait(0.03) ignoreFolder = mySettings.IgnoreFolder.Value until ignoreFolder ~= nil
end

--Motors--
local lHip = myTorso["Left Hip"]
local lHipOrg = lHip.C0
local rHip = myTorso["Right Hip"]
local rHipOrg = rHip.C0
local rootJoint = myRoot.RootJoint
local rootJointOrg = rootJoint.C0

--Align Orientations
local bodyRotate = myRoot.AlignOrientation

local xAxisAttach = Instance.new("Attachment")
xAxisAttach.Parent = workspace.Terrain
xAxisAttach.CFrame = myRoot.CFrame

local reloadAnimation = myHuman:LoadAnimation(marine.Reload)
reloadAnimation.Priority = Enum.AnimationPriority.Action

local IdleM4 = myHuman:LoadAnimation(marine.IdleM4)
IdleM4.Priority = Enum.AnimationPriority.Action  -- this is setting IdleM4 correctly

local YieldM4Anim = myHuman:LoadAnimation(marine.YieldM4)
YieldM4Anim.Priority = Enum.AnimationPriority.Action  -- and again

local LowerM4Anim = myHuman:LoadAnimation(marine.LowerM4)
LowerM4Anim.Priority = Enum.AnimationPriority.Action  -- and again

YieldM4Anim:Play()

function actions:Crouch()
	lHip.Enabled = false
	rHip.Enabled = false 
	self.Human.WalkSpeed = 0
	self.Human.HipHeight = -1.5
	self.Human:MoveTo(self.Root.Position)

	self.Instance["Right Leg"].CFrame = self.Root.CFrame * CFrame.new(0.5,-1,1) * CFrame.fromEulerAnglesXYZ(math.rad(-90),0,0)
	self.Instance["Left Leg"].CFrame = self.Root.CFrame * CFrame.new(-0.5,-0.5,-0.5)

	self.lWeld = Instance.new("WeldConstraint")
	self.lWeld.Parent = self.Torso
	self.lWeld.Part0 = self.Torso
	self.lWeld.Part1 = self.Instance["Left Leg"]

	self.rWeld = Instance.new("WeldConstraint")
	self.rWeld.Parent = self.Torso
	self.rWeld.Part0 = self.Torso
	self.rWeld.Part1 = self.Instance["Right Leg"]
end

function actions:Stand()

	if self.lWeld then self.lWeld:Destroy() end
	if self.rWeld then self.rWeld:Destroy() end

	lHip.Enabled = true
	rHip.Enabled = true

	self.Human.WalkSpeed = 16
	self.Human.HipHeight = 0
end

function actions:Aim()

	local aimPos = Vector3.new()
	local sightIndex = 50

	self:SetM4Aimed(true)
	self.Human.AutoRotate = false
	self.BodyRotate.Enabled = true
	self.Human.WalkSpeed = 10

	local target = self:GetTarget()

	local offsetX = 0
	local offsetY = 0
	local offsetTS = core.tick() - 1

	local validTargetTS = core.tick()
	local aimSwitchDelay = 1

	local checkSightTS = core.tick()
	local checkSightDelay = 2

	local dist = core.checkDist(target, myTorso)
	local canSee = self:CheckSightToTarget()

	while true do
		if not self:GetM4Equipped() and not self:GetReloading() then
			break
		elseif self:GetTarget() and target ~= self:GetTarget() then
			if self:CheckSightToTarget() then
				target = self:GetTarget()
			else
				target = {
					Position = target.Position,
					Velocity = Vector3.new()
				}
			end
		elseif not self:CheckTarget() then
			if core.tick() - validTargetTS > aimSwitchDelay then
				break
			else
				target = {
					Position = target.Position,
					Velocity = Vector3.new()
				}
			end
		else
			validTargetTS = core.tick()
		end

		if core.runAtTS("ActionsCheckDist", 0.3) then
			dist = core.checkDist(target.Position, myTorso)
		end

		if core.runAtTS("ActionsCheckSightToTarget", 1) then
			canSee = self:CheckSightToTarget()
			if not canSee then
				self.BodyRotate.Enabled = false
				--	self.Human.AutoRotate = true
			else
				self.BodyRotate.Enabled = true
			end
		end

		if not canSee then
			sightIndex = sightIndex - 1
		else
			sightIndex = 50
		end

		if not canSee and self.Root.Velocity.Magnitude > 3 and sightIndex <= 0 then
			local walkPoint = self.Human.WalkToPoint
			local myPos = self.Root.Position
			local dir = (Vector3.new(walkPoint.X, 0, walkPoint.Z) - Vector3.new(myPos.X, 0, myPos.Z)).Unit * 20
			aimPos = self.Root.Position + Vector3.new(0, 1.5, 0) + dir
		else
			aimPos = formulas.getAimVector3(self.Root, target, 700)

			if core.tick() - offsetTS > 0.5 then
				offsetTS = core.tick()
				offsetX = core.calcRandomOffset(self.Settings.M4.Accuracy.Value)
				offsetY = core.calcRandomOffset(self.Settings.M4.Accuracy.Value)
			end

			aimPos = aimPos:Lerp(aimPos + Vector3.new(offsetX, offsetY, 0), 0.5)
		end

		local tilt = (self.Root.Position.Y - aimPos.Y) / (dist * 0.04)
		tilt = math.clamp(tilt, -45, 45)
		rootJoint.C0 = rootJointOrg * CFrame.fromEulerAnglesYXZ(math.rad(tilt), 0, 0)
		lHip.C0 = lHipOrg * CFrame.fromEulerAnglesYXZ(0, 0, math.rad(-tilt))
		rHip.C0 = rHipOrg * CFrame.fromEulerAnglesYXZ(0, 0, math.rad(tilt))

		-- Body yaw via AlignOrientation directly
		self.BodyRotate.CFrame = CFrame.new(myRoot.Position, Vector3.new(
			aimPos.X,
			myRoot.Position.Y,
			aimPos.Z
			))

		if self:GetM4Equipped() then
			self.Neck.C0 = CFrame.new(0, 1, 0) * CFrame.Angles(-1.5 + math.rad(xAxisAttach.Orientation.X), math.rad(15), math.rad(180))
		else
			self.Neck.C0 = CFrame.new(0, 1, 0) * CFrame.Angles(-1.5 + math.rad(xAxisAttach.Orientation.X), 0, math.rad(180))
		end

		task.wait()
	end

	self:ResetHead()
	self.BodyRotate.Enabled = false
	self.Human.WalkSpeed = 16
	self.Human.AutoRotate = true

	rootJoint.C0 = rootJointOrg
	lHip.C0 = lHipOrg
	rHip.C0 = rHipOrg

	self:SetM4Aimed(false)
end

function actions:Reload()
	print("start")
	self:SetM4Aimed(false)
	self:SetReloading(true)
	reloadSound:Play()

	IdleM4:Stop()
	LowerM4Anim:Stop()
	YieldM4Anim:Stop()

	reloadAnimation:Play()
	reloadAnimation:AdjustSpeed(3)

	task.wait(reloadAnimation.Length / 3) -- Length divided by speed

	reloadAnimation:Stop()

	self:SetReloading(false)
	self:SetMag(self.Settings.M4.MagSize.Value)
	self:SetM4Equipped(false) 
	self:DrawM4()
	print("finish?")
end

function actions:DrawM4()
	self:YieldKnife()
	if not self:GetM4Equipped() and not self:GetReloading() then
		self:SetM4Equipped(true)
		self:SetM4Lowered(false)
		self.M4.Equip:Play()

		LowerM4Anim:Stop()
		YieldM4Anim:Stop()
		IdleM4:Play()

		print("Draw")
	end
end

function actions:YieldM4()
	if self:GetM4Equipped() or self:GetM4Lowered() then
		self:SetM4Equipped(false)
		self:SetM4Aimed(false)
		self:SetM4Lowered(false)
		self.M4.Equip:Play()

		IdleM4:Stop()
		LowerM4Anim:Stop()
		YieldM4Anim:Play()
	end
end

function actions:LowerM4()
	if not self:GetM4Lowered() and self:GetM4Equipped() and not self:GetReloading() then
		self:SetM4Aimed(false)
		self:SetM4Equipped(false)
		self:SetM4Lowered(true)
		self.M4.Equip:Play()

		IdleM4:Stop()
		YieldM4Anim:Stop()
		LowerM4Anim:Play()
	end
end

function actions:DrawKnife()
	if not self:GetKnifeEquipped() then
		self:YieldM4()
		self.Knife.Equip:Play()
		self:SetKnifeEquipped(true)
		self.Knife.Weld.Part0 = nil
		self.Knife.CFrame = rArm.CFrame * CFrame.new(0,-1,-1) * CFrame.Angles(math.rad(90),math.rad(180),math.rad(180))
		self.Knife.Weld.Part0 = rArm
	end
end

function actions:YieldKnife()
	if self:GetKnifeEquipped() then
		self:SetKnifeEquipped(false)
		self.Knife.Weld.Part0 = nil
		self.Knife.CFrame = myTorso.CFrame * CFrame.new(-1,-1,0.5) * CFrame.Angles(math.rad(-65),0,math.rad(180))
		self.Knife.Weld.Part0 = myTorso
	end
end

function actions:YieldWeapons()
	self:YieldKnife()
	self:YieldM4()
end

function actions:ResetHead()
	tweenService:Create(self.Neck,TweenInfo.new(0.5),{C0 = CFrame.new(0,1,0) * CFrame.Angles(math.rad(-90),0,math.rad(180))}):Play()
end

local faces = myHead.Faces
function actions:UpdateFace(newStatus,recovered)
	if self:GetMood() ~= "Dead" then
		if self:GetMood() ~= "Hurt" or recovered or newStatus == "Dead" then
			local currentFace = self:GetFace()
			currentFace.Parent = faces 
			self:SetFace(self.Faces["face"..newStatus])
			self:GetFace().Parent = self.Head
		end
		self:SetMood(newStatus)
	end
end

return actions