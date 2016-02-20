-----------------------------------------------------------------------------------------
--
-- level1.lua
--
-----------------------------------------------------------------------------------------

local composer = require( "composer" )
local scene = composer.newScene()

local helpers = require ("helpers.helpers")

-- include Corona's "physics" library
-- TODO: Take out if not using
local physics = require "physics"

physics.start()
physics.pause()

--------------------------------------------

-- forward declarations and other locals
local screenW, screenH, halfW = display.contentWidth, display.contentHeight, display.contentWidth*0.5

-- Size of bombs/slots for them
local slotWidth = screenW / 5
local halfSlotWidth = slotWidth / 2

local bombs = {}
local grid = {}

local bg = {}
local mask = {}

local ship = {}

function scene:create( event )

	-- Called when the scene's view does not exist.
	-- 
	-- INSERT code here to initialize the scene
	-- e.g. add display objects to 'sceneGroup', add touch listeners, etc.

	local sceneGroup = self.view

	-- create background
	bg = display.newImageRect( "img/deck.jpg", screenW, screenH )
	bg.x = display.contentCenterX
	bg.y = display.contentCenterY

	-- create mask to detect touches
	mask = display.newRect( display.contentCenterX, display.contentCenterY, screenW, screenH )
	mask.alpha = 0
	mask.isHitTestable = true

	-- build ship
 	ship = display.newImageRect( "img/ship.png", slotWidth * 3, slotWidth )
	ship.x = slotWidth * 2
	ship.y = slotWidth

	local collisionFilter = { groupIndex = -2 }
	physics.addBody( ship, {filter = collisionFilter} )
	ship.gravityScale = 0


	-- Grid to lock bombs into grid
	buildGrid()


	for i, slot in ipairs(grid) do

		local slotRect = display.newRect( slot[1] + slotWidth / 2, screenH - slot[2] - slotWidth / 2, slotWidth, slotWidth )
		slotRect:setFillColor(.5)

		sceneGroup:insert( slotRect )

	end

	
	-- all display objects must be inserted into group
	sceneGroup:insert( bg )

	bg:toBack()

	createBombs(sceneGroup)
	slideBombs(sceneGroup)

	sceneGroup:insert( mask )



	-- TODO: Put this in separate game manager class
	Runtime:addEventListener( "enterFrame", test )

	mask:addEventListener("touch",backgroundTouched)

end

function buildGrid() 
	-- Build 8x8 grid
	local j
	for i = 1, 16 do

		j = math.floor((i - 1) / 4)

		local newObject = {
			(i * slotWidth) - (j * slotWidth * 4) - halfSlotWidth,
			j * slotWidth + halfSlotWidth
		}

		table.insert(grid, newObject)

	end

end

function test()
	-- Should really be somewhere else
end


function scene:show( event )
	local sceneGroup = self.view
	local phase = event.phase
	
	if phase == "will" then
		-- Called when the scene is still off screen and is about to move on screen
	elseif phase == "did" then
		-- Called when the scene is now on screen
		-- 

		-- INSERT code here to make the scene come alive
		-- e.g. start timers, begin animation, play audio, etc.
		physics.start()
	end
end

-- touch listener function
-- Need to store which one was touched because others will still have "moved" called when dragging over
local tBomb
function objectTouch( e )
	local target = e.target

	if (e.phase=="began") then

		tBomb = target
		
		if (tBomb.isMovingToSlot) then
			return
		end

		tBomb.movedBackToSlot = false

		tBomb.originalY = tBomb.y;
	elseif (e.phase == "cancelled" or e.phase == "ended") then
		if (not tBomb.isFiring) then
			moveBombToSlot(tBomb)
		end
	end
    
    return true
end

function backgroundTouched(e)

	if (e.phase=="moved" and tBomb ~= nil and not tBomb.isFiring and not tBomb.isMovingToSlot and not tBomb.movedBackToSlot) then
	    tBomb.y = e.y
	    checkBombToFire(tBomb)
	end
end

function checkBombToFire(bomb) 
	if (bomb.y < bomb.originalY - slotWidth) then

		fireBomb(bomb)

	elseif (bomb.y > bomb.originalY + slotWidth) then

		moveBombToSlot(bomb)

	end
end

function fireBomb(bomb) 
	bomb.isFiring = true

	transition.to(bomb, {
		y = 0 - slotWidth,
		onComplete = function()
				bomb:removeSelf()
			end
	})
end


function moveBombToSlot(bomb) 
	bomb.isMovingToSlot = true
	transition.to(bomb, {
		y = bomb.originalY,
		time = 200,
		onComplete = function()
				bomb.isMovingToSlot = false
				bomb.movedBackToSlot = true
			end
	})
end


function createBombs(sceneGroup)

	for i=1,16 do 
		local bomb = display.newImageRect( "img/bomb.png", slotWidth, slotWidth )
		table.insert(bombs, bomb)

		local row = math.floor((i - 1) / 4)
		bomb.x = halfSlotWidth + row * slotWidth + screenW
		bomb.y = screenH - halfSlotWidth - slotWidth * row
		
		bomb:addEventListener( "touch", objectTouch )

		-- Add physics
		local collisionFilter = { groupIndex = -1 }
		physics.addBody( bomb, {filter = collisionFilter} )
		bomb.gravityScale = 0

		sceneGroup:insert( bomb )
		
	end

end


function slideBombs(sceneGroup)
	
	slideEntireRow(1)
	slideEntireRow(2)
	slideEntireRow(3)
	slideEntireRow(4)

end

function slideOneBomb(bomb, slot, callBack)
	transition.to(bomb, {
		x= slot[1] + halfSlotWidth,
		y= screenH - slot[2] - halfSlotWidth,
		rotation = -360,
		onComplete = callBack
	})
end

-- rowNum = which row
-- position = which column
function slideEntireRow(rowNum, columnNum)

	if not columnNum then columnNum = 1 end

	local count = (rowNum - 1) * 4 + columnNum

	slideOneBomb(bombs[count], grid[count], function()

		if (columnNum ~= 4) then
			slideEntireRow(rowNum, columnNum + 1)
		end

	end)
end


function scene:hide( event )
	local sceneGroup = self.view
	
	local phase = event.phase
	
	if event.phase == "will" then
		-- Called when the scene is on screen and is about to move off screen
		--
		-- INSERT code here to pause the scene
		-- e.g. stop timers, stop animation, unload sounds, etc.)
		physics.stop()
	elseif phase == "did" then
		-- Called when the scene is now off screen
	end	
	
end

function scene:destroy( event )

	-- Called prior to the removal of scene's "view" (sceneGroup)
	-- 
	-- INSERT code here to cleanup the scene
	-- e.g. remove display objects, remove touch listeners, save state, etc.
	local sceneGroup = self.view
	
	package.loaded[physics] = nil
	physics = nil
end

---------------------------------------------------------------------------------

-- Listener setup
scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

-----------------------------------------------------------------------------------------

return scene