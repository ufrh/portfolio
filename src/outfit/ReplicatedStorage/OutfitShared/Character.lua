local Character = {} do
	function Character.preparePart(object)
		if (object:IsA("BasePart")) then
			object.CanCollide = false
			object.CanTouch = false
			object.CanQuery = false
		elseif (object:IsA("BillboardGui")) then object.Enabled = false end
	end

	function Character.lock(model: Model, pivot: CFrame)
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart")
		if (not humanoid or not root) then return false end
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
		humanoid:Move(Vector3.zero)
		root.Anchored = true
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		for _, object in model:GetDescendants() do Character.preparePart(object) end
		model:PivotTo(pivot)
		return true;
	end
end return Character;
