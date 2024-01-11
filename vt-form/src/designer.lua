--------------------------
-- component moving
--------------------------
local mvObject 
local origObject
local isMoving
local orgX, orgY

function MoveComponent(cmp, callBack)
	if mvObject then 
		mvObject:Free()
		mvObject = nil
		origObject.visible = true
	end
	origObject = cmp
	mvObject = VCL.Shape(cmp.parent,"move_"..cmp.name, {
		brush = {
			style = 'bsClear'
		},
		pen = { 
			color = 'clRed',
			style = 'psDot'
		},
		left = origObject.left,
		top = origObject.top,
		width = origObject.width,
		height = origObject.height,
		onMouseDown = function(mvComp,Button,Shift,X,Y)
			if Button ~= 'mbLeft' then return end
			isMoving = true
			orgX = X
			orgY = Y
		end,
		onMouseUp = function (mvComp,Button,Shift,X,Y)
		  isMoving = false
		  origObject.Left = mvObject.Left + X - orgX
		  origObject.Top  = mvObject.Top  + Y - orgY
		  mvObject:Free()
		  mvObject = nil
		  origObject.visible = true
		  if type(callBack)=="function" then
			callBack()
		  end
		end,
		onMouseMove = function (mvComp,Shift,X,Y)
			if isMoving then
			  mvObject.Left = mvObject.Left + X - orgX
			  mvObject.Top  = mvObject.Top  + Y - orgY
			end
		end
	})
	origObject.visible = false	
end
