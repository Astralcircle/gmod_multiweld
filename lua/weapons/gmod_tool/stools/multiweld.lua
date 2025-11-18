TOOL.Category = "Constraints"
TOOL.Name = "MultiWeld"
TOOL.Information = {
	{name = "left"},
	{name = "right"},
	{name = "reload"}
}

TOOL.ClientConVar["weld"] = "1"
TOOL.ClientConVar["forcelimit"] = "0"
TOOL.ClientConVar["nocollide"] = "0"
TOOL.ClientConVar["scale"] = "2"

if SERVER then
	function TOOL:ClearObjects()
		for ent, oldcolor in pairs(self.Objects) do
			if ent:IsValid() then
				ent:SetColor(oldcolor)
			end
		end

		self.Objects = {}
	end

	function TOOL:CheckObjects()
		for ent, oldcolor in pairs(self.Objects) do
			if not ent:IsValid() then
				self.Objects[ent] = nil
			end
		end
	end
else
	language.Add("tool.multiweld.name", "MultiWeld")
	language.Add("tool.multiweld.desc", "Finds the best welding structure to reduce constraints and improve performance")
	language.Add("tool.multiweld.left", "Add/remove object (hold for fast select)")
	language.Add("tool.multiweld.right", "Weld selected objects")
	language.Add("tool.multiweld.reload", "Clear selection")
end

function TOOL:LeftClick(trace)
	local ent = trace.Entity
	if not ent:IsValid() or ent:IsPlayer() then return false end

	if SERVER then
		if self.Objects[ent] then
			self:GetOwner():SendLua("surface.PlaySound(\"buttons/button22.wav\")")
			ent:SetColor(self.Objects[ent])
			self.Objects[ent] = nil
		else
			if util.IsValidPhysicsObject(ent, 0) then
				self:GetOwner():SendLua("surface.PlaySound(\"buttons/button22.wav\")")
				self.Objects[ent] = ent:GetColor()
				ent:SetColor(Color(0, 255, 0))
			else
				return false
			end
		end
	end

	return false
end

function TOOL:Think()
	local owner = self:GetOwner()

	if not owner:KeyDown(IN_ATTACK) then
		self.FastMode = nil
	else
		if self.FastMode then
			if self.FastMode <= CurTime() then
				local trace = owner:GetEyeTrace()
				if self.Objects[trace.Entity] or not gamemode.Call("CanTool", owner, trace, "multiweld", self, 1) then return end

				self:LeftClick(trace)
			end
		else
			self.FastMode = CurTime() + 0.5
		end
	end
end

function TOOL:RightClick()
	if CLIENT then return false end

	local weld = self:GetClientBool("weld", true)
	local nocollide = self:GetClientBool("nocollide", false)
	if not weld and not nocollide then self:ClearObjects() return false end

	local forcelimit = self:GetClientNumber("forcelimit", 0)
	local scale = self:GetClientNumber("scale", 2)
	local owner = self:GetOwner()
	local limithit = nil
	local created = nil

	for ent, color in pairs(self.Objects) do
		if limithit then break end

		local entaabb1, entaabb2 = ent:GetRotatedAABB(ent:OBBMins(), ent:OBBMaxs())
		entaabb1:Mul(scale)
		entaabb2:Mul(scale)

		local entpos = ent:GetPos()
		entaabb1:Add(entpos)
		entaabb2:Add(entpos)

		for subent, subcolor in pairs(self.Objects) do
			if ent ~= subent then
				if not owner:CheckLimit("constraints") then
					self:ClearObjects()
					limithit = true
					break
				end

				if not created then
					created = {}
				end

				if scale ~= 0 then
					local subentaabb1, subentaabb2 = subent:GetRotatedAABB(subent:OBBMins(), subent:OBBMaxs())
					subentaabb1:Mul(scale)
					subentaabb2:Mul(scale)

					local subentpos = subent:GetPos()
					subentaabb1:Add(subentpos)
					subentaabb2:Add(subentpos)

					if entaabb1.X > subentaabb2.X or entaabb2.X < subentaabb1.X or
						entaabb1.Y > subentaabb2.Y or entaabb2.Y < subentaabb1.Y or
						entaabb1.Z > subentaabb2.Z or entaabb2.Z < subentaabb1.Z then
						continue
				 	end
				end

				local constr

				if weld then
					constr = constraint.Weld(ent, subent, 0, 0, forcelimit, nocollide)
				else
					constr = constraint.NoCollide(ent, subent, 0, 0, true)
				end

				if IsValid(constr) then
					owner:AddCount("constraints", constr)
					owner:AddCleanup("constraints", constr)
					table.insert(created, constr)
				end
			end
		end
	end

	if created then
		if #created > 0 then
			undo.Create("MultiWeld")
				for _, ent in ipairs(created) do
					undo.AddEntity(ent)
				end

				undo.SetPlayer(owner)
			undo.Finish("#tool.multiweld.name")
		end

		owner:SendLua(string.format("notification.AddLegacy(\"Created %i constraints\", NOTIFY_GENERIC, 3) surface.PlaySound(\"buttons/button22.wav\")", #created))
		self:ClearObjects()
	end

	return false
end

function TOOL:Reload()
	if SERVER and not table.IsEmpty(self.Objects) then
		self:GetOwner():SendLua("notification.AddLegacy(\"Cleared all objects\", NOTIFY_GENERIC, 2) surface.PlaySound(\"buttons/button22.wav\")")
		self:ClearObjects()
	end

	return false
end

function TOOL:Holster()
	self:ClearObjects()
end

local default_convars = TOOL:BuildConVarList()

function TOOL.BuildCPanel(panel)
	panel:Help("#tool.multiweld.desc")
	panel:ToolPresets("multiweld", default_convars)
	panel:NumSlider("Scale:", "multiweld_scale", 0, 10)
	panel:ControlHelp("Scales the AABB bounds for intersection checks. Higher value = more constraints, 0 = weld all (performance intensive)")
	panel:NumSlider("#tool.forcelimit", "multiweld_forcelimit", 0, 1000)
	panel:ControlHelp("#tool.forcelimit.help")
	panel:CheckBox("#tool.weld.name", "multiweld_weld")
	panel:ControlHelp("#tool.weld.desc")
	panel:CheckBox("#tool.nocollide", "multiweld_nocollide")
	panel:ControlHelp("#tool.nocollide.help")
end
