--[[
	
3D2D VGUI Wrapper
Copyright (c) 2013 Alexander Overvoorde, Matt Stevens

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

]]--

if SERVER then
	AddCSLuaFile()
	return
end

local origin = Vector(0, 0, 0)
local angle = Vector(0, 0, 0)
local normal = Vector(0, 0, 0)
local scale = 0

-- Helper functions

local function planeLineIntersect( lineStart, lineEnd, planeNormal, planePoint )
	local t = planeNormal:Dot( planePoint - lineStart ) / planeNormal:Dot( lineEnd - lineStart )
	return lineStart + t * ( lineEnd - lineStart )
end

--[[
local gx,gy=0,0
local function testdraw(x,y)
	surface.SetDrawColor(255,255,255,255)
	surface.DrawLine( x, y-8, x, y+8 )
	surface.DrawLine( x-8, y, x+8, y )
end
hook.Add("HUDPaint", "bleh", function()
	testdraw(gx,gy)
end)
]]--

local function getCursorPos()
	local p = planeLineIntersect( LocalPlayer():EyePos(), LocalPlayer():EyePos() + LocalPlayer():GetAimVector() * 16000, normal, origin )
	local offset = origin - p
	
	local angle2 = angle:Angle()
	angle2:RotateAroundAxis( normal, -90 )
	angle2 = angle2:Forward()
	
	local x = Vector( offset.x * angle.x, offset.y * angle.y, offset.z * angle.z ):Length()
	local y = Vector( offset.x * angle2.x, offset.y * angle2.y, offset.z * angle2.z ):Length()
	return x, y
end

local function getParents( pnl )
	local parents = {}
	local parent = pnl.Parent
	while ( parent ) do
		table.insert( parents, parent )
		parent = parent.Parent
	end
	return parents
end

local function absolutePanelPos( pnl )
	local x, y = pnl:GetPos()
	local parents = getParents( pnl )
	
	for _, parent in ipairs( parents ) do
		local px, py = parent:GetPos()
		x = x + px
		y = y + py
	end
	return x, y
end

local function pointInsidePanel( pnl, x, y )
	local px, py = absolutePanelPos( pnl )
	local sx, sy = pnl:GetSize()

	x = x / scale
	y = y / scale
	
	return x >= px and y >= py and x <= px + sx and y <= py + sy
end

-- Input

local inputWindows = {}

--[[ Breaks context menu and other stuff probably, also doesn't seem to do much
if not guiMouseX then guiMouseX = gui.MouseX end
if not guiMouseY then guiMouseY = gui.MouseY end
function gui.MouseX()
	local x, y = getCursorPos()
	return x
end
function gui.MouseY()	
	local x, y = getCursorPos()
	return y
end
]]--

local function isMouseOver( pnl )
	return pointInsidePanel( pnl, getCursorPos() )
end

local curpnl={}
local function postPanelEvent( pnl, event, ... )
	if ( not pnl:IsValid() or not isMouseOver( pnl ) or not pnl:IsVisible() ) then return false end	
	local handled = false
	for i,child in ipairs( pnl.Childs or {} ) do
		if ( postPanelEvent( child, event, ... ) ) then
			handled = true
			break
		end
	end
	
	if ( not handled and pnl[ event ] ) then
		pnl[ event ]( pnl, ... )
		if event=="OnMousePressed" and not curpnl[pnl] then
			curpnl[pnl]=true
		end
		return true
	else
		return false
	end
end

local function checkHover( pnl )
	pnl.WasHovered = pnl.Hovered
	pnl.Hovered = isMouseOver( pnl )
	
	if not pnl.WasHovered and pnl.Hovered then
		if pnl.OnCursorEntered then pnl:OnCursorEntered() end
	elseif pnl.WasHovered and not pnl.Hovered then
		if pnl.OnCursorExited then pnl:OnCursorExited() end
	end

	for i, child in ipairs( pnl.Childs or {} ) do
		if ( child:IsValid() ) then checkHover( child ) end
	end
end

local function facingPanel( pnl )
	local vec = GetViewEntity():GetPos() - pnl.Origin

	if pnl.Normal:Dot( vec ) > 0 then
		return true
	end
end

-- Mouse input

hook.Add( "KeyPress", "VGUI3D2DMousePress", function( _, key )
	if ( key == IN_USE ) then
		for pnl in pairs( inputWindows ) do
			if ( pnl:IsValid() and facingPanel( pnl ) ) then
				origin = pnl.Origin
				scale = pnl.Scale
				angle = pnl.Angle
				normal = pnl.Normal
				
				postPanelEvent( pnl, "OnMousePressed", MOUSE_LEFT )
			end
		end
	end
end )

hook.Add( "KeyRelease", "VGUI3D2DMouseRelease", function( _, key )
	if ( key == IN_USE ) then
		local fnd=false
		for pnl in pairs( inputWindows ) do
			if ( pnl:IsValid() and facingPanel( pnl ) ) then
				origin = pnl.Origin
				scale = pnl.Scale
				angle = pnl.Angle
				normal = pnl.Normal
				
				postPanelEvent( pnl, "OnMouseReleased", MOUSE_LEFT )
			end
		end
		if not fnd then
			for k,v in pairs(curpnl) do
				if k:IsValid() and k.OnMouseReleased then
					k:OnMouseReleased( MOUSE_LEFT )
				end
				curpnl={}
			end
		end
	end
end )

-- Key input

-- TODO, OH DEAR.
-- Drawing:

function vgui.Start3D2D( pos, ang, res )
	origin = pos
	scale = res
	angle = ang:Forward()
	
	normal = Angle( ang.p, ang.y, ang.r )
	normal:RotateAroundAxis( ang:Forward(), -90 )
	normal:RotateAroundAxis( ang:Right(), 90 )
	normal = normal:Forward()
	
	cam.Start3D2D( pos, ang, res )
end

local _R = debug.getregistry()
function _R.Panel:Paint3D2D()
	if not self:IsValid() then return end
	
	-- Add it to the list of windows to receive input
	inputWindows[ self ] = true
	
	-- Override think of DFrame's to correct the mouse pos by changing the active orientation
	if self.Think then
		if not self.OThink then
			self.OThink = self.Think
			
			self.Think = function()
				origin = self.Origin
				scale = self.Scale
				angle = self.Angle
				normal = self.Normal
				
				self:OThink()
			end
		end
	end
	
	-- Update the hover state of controls
	checkHover( self )
	
	-- Store the orientation of the window to calculate the position outside the render loop
	self.Origin = origin
	self.Scale = scale
	self.Angle = angle
	self.Normal = normal
	
	-- Draw it manually
	self:SetPaintedManually( false )
		self:PaintManual()
	self:SetPaintedManually( true )
end

function vgui.End3D2D()
	cam.End3D2D()
end

-- Keep track of child controls

if not vguiCreate then vguiCreate = vgui.Create end
function vgui.Create( class, parent )
	local pnl = vguiCreate( class, parent )
	if not pnl then return end
	
	pnl.Parent = parent
	pnl.Class = class
	
	if parent then
		if not parent.Childs then parent.Childs = {} end
		table.insert(parent.Childs,1,pnl)
	end
	
	return pnl
end