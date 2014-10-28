include('shared.lua')

function ENT:Draw()
	if self.DoDraw then
		local int=self:GetNetEnt("interior")
		local ext=self:GetNetEnt("exterior")
		if int:CallHook("ShouldDraw") or (ext:DoorOpen() and self.ClientThinkOverride and LocalPlayer():GetPos():Distance(ext:GetPos())<500) then -- TODO: Improve
			self:DoDraw()
		end
	end
end

function ENT:DoDraw()
	self:DrawModel()
end

function ENT:Initialize()
	net.Start("TARDIS-SetupPart")
		net.WriteEntity(self)
	net.SendToServer()
	if self.DoInitialize then
		self:DoInitialize()
	end
end

function ENT:Think()
	if self.DoThink then
		local int=self:GetNetEnt("interior")
		local ext=self:GetNetEnt("exterior")
		if int:CallHook("ShouldThink") or (ext:DoorOpen() and self.ClientThinkOverride and LocalPlayer():GetPos():Distance(ext:GetPos())<500) then -- TODO: Improve
			self:DoThink()
		end
	end
end