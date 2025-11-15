
TOOL.Category = "Constraints"
TOOL.Name = "MultiWeld"
TOOL.Information = {
	{name = "left"},
	{name = "right"},
	{name = "reload"}
}

TOOL.ClientConVar["forcelimit"] = "0"
TOOL.ClientConVar["nocollide"] = "0"

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
	language.Add("tool.multiweld.desc", "Weld a bunch of stuff together")
	language.Add("tool.multiweld.left", "Select object")
	language.Add("tool.multiweld.right", "Weld objects")
	language.Add("tool.multiweld.reload", "Clear objects")
end

function TOOL:LeftClick(trace)
	local ent = trace.Entity
	if not ent:IsValid() or ent:IsPlayer() then return false end

	if SERVER then
		if self.Objects[ent] then
			ent:SetColor(self.Objects[ent])
			self.Objects[ent] = nil
		else
			if util.IsValidPhysicsObject(ent, 0) then
				self.Objects[ent] = ent:GetColor()
				ent:SetColor(Color(0, 255, 0))
			else
				return false
			end
		end
	end

	return true
end

function TOOL:RightClick()
	if CLIENT then return false end

	local ply = self:GetOwner()
	local count = nil

	for ent, color in pairs(self.Objects) do
		for subent, subcolor in pairs(self.Objects) do
			if ent ~= subent then
				if not ply:CheckLimit("constraints") then
					self:ClearObjects()
					return false
				end

				local weld = constraint.Weld(ent, subent, 0, 0, self:GetClientNumber("forcelimit"), self:GetClientBool("nocollide"))
				if not count then count = 0 end

				if IsValid(weld) then
					ply:AddCount("constraints", weld)
					ply:AddCleanup("constraints", weld)
					count = count + 1
				end
			end
		end
	end

	if count then
		ply:SendLua(string.format("notification.AddLegacy(\"Created %i constraints\", NOTIFY_GENERIC, 3)", count))
		self:ClearObjects()
	end

	return false
end

function TOOL:Reload()
	if SERVER and not table.IsEmpty(self.Objects) then
		self:GetOwner():SendLua("notification.AddLegacy(\"Cleared all objects\", NOTIFY_GENERIC, 2)")
		self:ClearObjects()
	end

	return false
end

function TOOL:Holster()
	self:ClearObjects()
end

local default_convars = TOOL:BuildConVarList()

function TOOL.BuildCPanel(panel)
	panel:Help("Welds a bunch of objects together")
	panel:ToolPresets("massweld", default_convars)
	panel:NumSlider("#tool.forcelimit", "multiweld_forcelimit", 0, 1000)
	panel:ControlHelp("#tool.forcelimit.help")
	panel:CheckBox("#tool.nocollide", "multiweld_nocollide")
end
