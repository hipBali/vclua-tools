--------------------------
-- component moving
--------------------------
local mvObject 
local origObject
local orgX, orgY
local width, height

local aligns={alNone=true,alCustom=true}
function MoveComponent(cmp,elem)
	origObject = cmp
	width = origObject.width
	height = origObject.height
	local origin = origObject.ControlOrigin
	mvObject = VCL.Form(nil,"move_"..cmp.name, {
		Color='clRed',
		BorderStyle = 'bsNone',
		AlphaBlend=true,
		AlphaBlendValue=175,
		BoundsRect = {left=origin.x,top=origin.y,right=origin.x+width,bottom=origin.y+height},
		OnMouseDown = function(mvComp,Button,Shift,X,Y)
			if Button ~= 'mbLeft' then
				orgX = nil
				mvComp:Close()
				return
			end
			orgX = X
			orgY = Y
			mvComp.OnMouseMove = function(mvComp,Shift,X,Y) mvComp:SetBounds(mvComp.Left+X-orgX,mvComp.Top+Y-orgY,width,height) end
		end,
		OnMouseUp = function (mvComp,Button,Shift,X,Y)
			if orgX then
				local align = origObject.Align
				origObject:DisableAutoSizing()
				if not aligns[align] then origObject.Align = 'alNone' end
				origObject.Anchors = '[akLeft,akTop]'
				for _,dir in ipairs({"AnchorSideLeft","AnchorSideRight","AnchorSideTop","AnchorSideBottom"}) do
					origObject[dir].Control = nil
					origObject[dir].Side = 'asrTop'
					elem.props[dir] = nil
				end
				local pt = origObject.Parent:ScreenToClient(mvComp.ControlOrigin)
				origObject:SetBounds(pt.x,pt.y,width,height)
				origObject:EnableAutoSizing()
				elem.props['Left'] = origObject.Left
				elem.props['Top'] = origObject.Top
				elem.props['Width'] = width
				elem.props['Height'] = height
				elem.props['Anchors'] = nil
				if not aligns[elem.props['Align']] then elem.props['Align'] = nil end
				setCurElem(elem)
				orgX = nil
				mvComp:Close()
			end
		end,
		OnClose=function(Sender)
			mvObject = nil
			origObject.visible = true
			return 'caFree'
		end
	})
	origObject.visible = false	
	mvObject:ShowModal()
end
