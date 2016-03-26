-- ObjectFactory for creating bombs

local Bomb = {}

-- Set random seed
math.randomseed( os.time() )

function Bomb:new(index)

	local row = math.floor((index - 1) / 4 + 1)
	local column = index - (row - 1) * 4

	local imagePath;

	-- For now, randomize which bomb icon to use
	local random = math.random( 1, 5 )

	print("random is " .. random)

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

Bomb.bombHit = function( self, event )

    if ( event.phase == "began" ) then

        createExplosionSprite(self.x, self.y)

        -- Set bomb to invisible, it will go off screen as if it were a miss and remove itself
        --self.alpha = 0
        
        print("interesteing")

        display.remove(self)
        self = nil

    elseif ( event.phase == "ended" ) then

    	print("ended phase")
        
    end
end

return Bomb