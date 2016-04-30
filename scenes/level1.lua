-----------------------------------------------------------------------------------------
--
-- level1.lua
--
-----------------------------------------------------------------------------------------

local composer = require( "composer" )
local scene = composer.newScene()

local helpers = require ("helpers.helpers")

-- For things like slot width/screen size
require("globals.globals")

-- include Corona's "physics" library
-- TODO: Take out if not using
local physics = require "physics"

physics.start()
physics.pause()

-- Object Factories
local Bomb = require("objects.Bomb")

--------------------------------------------

local bombs = {}
local grid = {}

local bg = {}
local mask = {}

local ship = {}

local sceneGroup;
local bombGroup;

function scene:create( event )

	-- Called when the scene's view does not exist.
	-- 
	-- INSERT code here to initialize the scene
	-- e.g. add display objects to 'sceneGroup', add touch listeners, etc.

	sceneGroup = self.view

	-- Use separate group for bombs so they're always behind touch mask
	bombGroup = display.newGroup()

	-- create background
	bg = display.newImageRect( "img/deck.jpg", screenW, screenH )
	bg.x = display.contentCenterX
	bg.y = display.contentCenterY

	-- create mask to detect touches
	mask = display.newRect( display.contentCenterX, display.contentCenterY, screenW, screenH )
	mask.alpha = 0
	mask.isHitTestable = true

	-- build ship
 	ship = display.newImageRect( "img/ship.png", slotWidth * 2, slotWidth )
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

		bombGroup:insert( slotRect )

	end

	
	-- all display objects must be inserted into group

	sceneGroup:insert( bg )

	bg:toBack()

	createBombs()
	slideBombs()


	sceneGroup:insert(bombGroup)
	sceneGroup:insert( mask )

	-- TODO: Put this in separate game manager class
	Runtime:addEventListener( "enterFrame", test )

	mask:addEventListener("touch",backgroundTouched)

end

function createExplosionSprite(x, y) 
	-- debug
	local sheetOptions =
	{
	    width = 124,
	    height = 118,
	    numFrames = 8
	}
	local sheet = graphics.newImageSheet( "img/explosions.png", sheetOptions )
	local sequences = {
    -- consecutive frames sequence
	    {
	        name = "normalRun",
	        start = 1,
	        count = 8,
	        time = 800,
	        loopCount = 1,
	        loopDirection = "forward"
	    }
	}
	local explosion = display.newSprite( sheet, sequences )

	explosion.x = x
	explosion.y = y

	explosion:play()

	local function mySpriteListener( event )

         if ( event.phase == "ended" ) then
              explosion:removeSelf()
              explosion = nil
         end
      end

       explosion:addEventListener( "sprite", mySpriteListener )  

end

function buildGrid() 
	-- Build 5x5 grid
	local j
	for i = 1, 25 do

		j = math.floor((i - 1) / 5)

		local newObject = {
			(i * slotWidth) - (j * slotWidth * 5) - halfSlotWidth,
			j * slotWidth + halfSlotWidth
		}

		table.insert(grid, newObject)

	end

end

function test()
	-- Should really be somewhere else
end


function scene:show( event )
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

-- Touch listener function
-- Need to store which bomb was touched because others will still have "moved" called when dragging over
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

		-- Don't allow to move down
		if e.y > tBomb.originalY then
			return
		end

		-- Go back to slot if touch goes off bomb 
		if (e.x > (tBomb.x + (slotWidth / 2)) or e.x < (tBomb.x - (slotWidth / 2))) then
			moveBombToSlot(tBomb)
		end

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
		y = 0 - slotWidth
	})

	slideNewBomb(bomb)

end

-- Slide new bomb into row that was occupied by old 'bomb' after it's fired (or explodes)
function slideNewBomb(oldBomb)

	-- Slide all bombs to the right over one, then slide new bomb in on right hand side
	local numBombsToSlide = 5 - oldBomb.column
	-- Keep track of bombs to update their indices
	local bombsToSlide = {}

	-- Slide bombs to the right of old one
	for i = 1, numBombsToSlide do
		local index = oldBomb.column + ((oldBomb.row - 1) * 5)
		local bombToSlide = bombs[index + i]
		table.insert(bombsToSlide, bombToSlide)
		slideOneBomb(bombToSlide, grid[index + i - 1])
	end

	-- TODO: Set indices correctly and make sure new bombs can be fired
	for j, bombToSlide in ipairs(bombsToSlide) do

		local newIndex = bombToSlide.index - 1
		bombToSlide.column = bombToSlide.column - 1
		bombToSlide.index = newIndex
		bombs[newIndex] = bombToSlide

	end


	-- Slide new bomb
	local newBombIndex = oldBomb.row * 5
	local newBomb = createBomb(newBombIndex)
	slideOneBomb(newBomb, grid[newBombIndex])

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

function createBomb(index)

	local bomb = Bomb:new(index)

	-- Add new bomb to our bombs array, and insert it into scene
	bombs[index] = bomb

	bombGroup:insert( bomb )

	return bomb
end


function createBombs()

	for i=1, 25 do 

		createBomb(i)
		
	end

end


function slideBombs()

	slideEntireRow(1)
	slideEntireRow(2)
	slideEntireRow(3)
	slideEntireRow(4)
	slideEntireRow(5)

end

function slideOneBomb(bomb, slot, callBack)

	-- Callback is optional
	if not callBack then
		callBack = function()
		end
	end

	-- We can slide mid-rotation, so find next interval of 360 to rotate to. 
	-- Firing before slide is completed could still be improved
	local rotationAmount = math.abs(math.ceil(bomb.rotation / 360)) + 1
	rotationAmount = rotationAmount * 360;

	transition.to(bomb, {
		x= slot[1] + halfSlotWidth,
		y= screenH - slot[2] - halfSlotWidth,
		rotation = 0 - rotationAmount,
		onComplete = callBack
	})
end

function slideEntireRow(rowNum, columnNum)

	if not columnNum then columnNum = 1 end

	local count = (rowNum - 1) * 5 + columnNum

	slideOneBomb(bombs[count], grid[count], function()

		if (columnNum ~= 5) then
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