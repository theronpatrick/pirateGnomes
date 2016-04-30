-- ObjectFactory for creating bombs

local Bomb = {}

-- Set random seed
math.randomseed( os.time() )

function Bomb:new(index)

	local row = math.floor((index - 1) / 5 + 1)
	local column = index - (row - 1) * 5

	local imagePath;

	-- For now, randomize which bomb icon to use
	local random = math.random( 1, 5 )

	if random == 1 then
		imagePath = "img/bomb.png"
	elseif random == 2 then
		imagePath = "img/bomb-red.png"
	elseif random == 3 then
		imagePath = "img/bomb-green.png"
	elseif random == 4 then
		imagePath = "img/bomb-blue.png"
	elseif random == 5 then
		imagePath = "img/bomb-white.png"
	end

	local bomb = display.newImageRect( imagePath, slotWidth, slotWidth )

	bomb.x = halfSlotWidth + screenW
	bomb.y = screenH - slotWidth * row

	bomb.row = row
	bomb.column = column
	bomb.index = index
	
	bomb:addEventListener( "touch", objectTouch )

	-- Add physics
	local collisionFilter = { groupIndex = -1 }
	physics.addBody( bomb, {filter = collisionFilter} )
	bomb.gravityScale = 0

	bomb.collision = Bomb.bombHit
	bomb:addEventListener( "collision", bomb )

	return bomb
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
	if (bomb.y < bomb.originalY - slotWidth / 2) then

		fireBomb(bomb)

	elseif (bomb.y > bomb.originalY + slotWidth) then

		-- TODO: moveBombToSlot and slideNewBomb out of level1.lua and into own grid manager
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

Bomb.bombHit = function( self, event )

    if ( event.phase == "began" ) then

        createExplosionSprite(self.x, self.y)

        -- Set bomb to invisible, it will go off screen as if it were a miss and remove itself
        --self.alpha = 0
        
        display.remove(self)
        self = nil

    elseif ( event.phase == "ended" ) then

    	print("ended phase")
        
    end
end

return Bomb