local Character = {} do
	local function child(parent, className, name)
		local object = parent:FindFirstChild(name)
		if (object and not object:IsA(className)) then object:Destroy(); object = nil end
		if (object) then return object end
		object = Instance.new(className)
		object.Name = name
		object.Parent = parent
		return object;
	end

	function Character.preparePart(object)
		if (object:IsA("BasePart")) then
			object.CanCollide = false
			object.CanTouch = false
			object.CanQuery = false
			if (object.Name == "HumanoidRootPart") then
				object.Anchored = false
				object.AssemblyLinearVelocity = Vector3.zero
				object.AssemblyAngularVelocity = Vector3.zero
			end
		elseif (object:IsA("BillboardGui")) then object.Enabled = false end
	end

	function Character.constrain(model: Model, target: Attachment)
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart")
		if (not humanoid or not root) then return false end
		local attachment = child(root, "Attachment", "OutfitRootAttachment")
		local position = child(root, "AlignPosition", "OutfitPosition")
		position.Mode = Enum.PositionAlignmentMode.TwoAttachment
		position.Attachment0 = attachment
		position.Attachment1 = target
		position.ApplyAtCenterOfMass = true
		position.RigidityEnabled = true
		position.MaxForce = math.huge
		position.MaxVelocity = math.huge
		position.Responsiveness = 200
		local orientation = root:FindFirstChild("OutfitOrientation")
		local created = not orientation or not orientation:IsA("AlignOrientation")
		orientation = child(root, "AlignOrientation", "OutfitOrientation")
		orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
		orientation.Attachment0 = attachment
		orientation.RigidityEnabled = true
		orientation.MaxTorque = math.huge
		orientation.MaxAngularVelocity = math.huge
		orientation.Responsiveness = 200
		if (created) then orientation.CFrame = target.WorldCFrame.Rotation end
		root.Anchored = false
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		humanoid.Jump = false
		humanoid.AutoRotate = false
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.NameDisplayDistance = 0
		humanoid.HealthDisplayDistance = 0
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		humanoid:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
		humanoid:Move(Vector3.zero)
		for _, object in model:GetDescendants() do Character.preparePart(object) end
		return true, orientation;
	end
end return Character;
