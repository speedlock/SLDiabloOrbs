--Minimap stuff - will reorganize at a later time.
SL32FramesUnlocked = false
SL32MiniMapButtonPosition = {
	locationAngle = 45, --deg
	x = 52-(80*cos(45)),
	y = ((80*sin(45))-52)
}

-- Call this in a mod's initialization to move the minimap button to its saved position (also used in its movement)
-- ** do not call from the mod's OnLoad, VARIABLES_LOADED or later is fine. **
function SL32MiniMapButton_Reposition()
	SL32MiniMapButtonPosition.x = 52-(80*cos(SL32MiniMapButtonPosition.locationAngle))
	SL32MiniMapButtonPosition.y = ((80*sin(SL32MiniMapButtonPosition.locationAngle))-52)
	SL32MiniMapButton:SetPoint("TOPLEFT","Minimap","TOPLEFT",SL32MiniMapButtonPosition.x,SL32MiniMapButtonPosition.y)
end

function SL32MiniMapButtonPosition_LoadFromDefaults()
	SL32MiniMapButton:SetPoint("TOPLEFT","Minimap","TOPLEFT",SL32MiniMapButtonPosition.x,SL32MiniMapButtonPosition.y)
end
-- Only while the button is dragged this is called every frame
function SL32_Minimap_Update()

	local xpos,ypos = GetCursorPosition()
	local xmin,ymin = Minimap:GetLeft(), Minimap:GetBottom()

	xpos = xmin-xpos/UIParent:GetScale()+70 -- get coordinates as differences from the center of the minimap
	ypos = ypos/UIParent:GetScale()-ymin-70

	SL32MiniMapButtonPosition.locationAngle = math.deg(math.atan2(ypos,xpos)) -- save the degrees we are relative to the minimap center
	SL32MiniMapButton_Reposition() -- move the button
end

-- Put your code that you want on a minimap button click here.  arg1="LeftButton", "RightButton", etc
function SL32MiniMapButton_OnClick()
	Handle_SL32GUI()
end

function Handle_SL32GUI()
	if SL32GUI:IsVisible() then
		SL32GUI:Hide()
		PlaySound(830);  -- SPELLBOOKCLOSE
	else
		SL32GUI:Show()
		PlaySound(829);  -- SPELLBOOKOPEN
	end
end

