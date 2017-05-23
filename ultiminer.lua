-- Consts
local ARGS = {...}
local DOWN_SQUARE = 0
local UP_SQUARE = 1
local SQUARE_HEIGHT = 3
local LIGHT_RIGHT = 0
local LIGHT_LEFT = 1
local TURTLE_INV_SIZE = 16

-- Config
local CLEAN_INV_ENABLE = true
local CLEAN_INV_AFTER_DISTANCE = 9
local CHEST_SUBSTRINGS = {"chest"}
local LIQUID_BLOCKS = {"water", "flowing_water", "lava", "flowing_lava"}
local GRAVITY_BLOCKS = {"sand", "gravel"}
local LIGHT_BLOCKS = {"torch", "glowstone", "lit_pumpkin"}
local PLACE_SUBSTRINGS = {"stone", "dirt", "ore"}
local DROP_BLOCKS = {"cobblestone", "stone", "dirt", "sand", "gravel"}
local LIGHT_ENABLE = true
local LIGHT_DISTANCE = 6
local LIGHT_ALTERNATE = false
-- End Config

-- MinerTurtle class
local MinerTurtle = {}
	MinerTurtle.__index = MinerTurtle
	setmetatable(MinerTurtle, {
		__call = function(cls, ...)
			return cls.init(...)
		end,
	})

	-- Utility functions
	-- Get name from inspect()'s data table
	function MinerTurtle.getBlockName(self, data)
		if(not data) then
			return nil
		elseif(not data.name) then
			return nil
		end

		return data.name:match(":(.+)"):lower()
	end

	-- Check if any of a str table's indeces are substrings of a given string
	function MinerTurtle.isTableSubstring(self, string, strTable)
		if(type(strTable) ~= "table" or not string) then
			return false
		end

		for index, str in pairs(strTable) do
			if(string:find(str)) then
				return true
			end
		end
		return false
	end

	-- Check if any of a str table's indeces match the given string
	function MinerTurtle.isTableMatch(self, string, strTable)
		if(type(strTable) ~= "table" or not string) then
			return false
		end

		for index, str in pairs(strTable) do
			if(str == string) then
				return true
			end
		end
		return false
	end
	-- End Utility functions

	-- Drops non-fuel, non-light inventory items into a chest
	function MinerTurtle.depositInv(self)
		-- Determine if the front block is a chest
		local function isChest(chestSubstrings)
			local status, data = turtle.inspect()

			if(not self:isTableSubstring(self:getBlockName(data), chestSubstrings)) then
				print("No chest available")
				return false
			end

			return true
		end

		-- Dont empty items into a non-chest
		if(not isChest(self.chestSubstrings)) then
			return false
		end

		-- Dump non-fuel and non-light items into the chest
		for index=1, self.invSize do
			turtle.select(index)
			local item = turtle.getItemDetail()
			if(not turtle.refuel(0) and not self:isTableMatch(self:getBlockName(item), self.lightBlocks)) then
				turtle.drop()
			end
		end
	end

	-- Drops inventory items found in DROP_BLOCKS
	function MinerTurtle.cleanInv(self)
		for index=1, self.invSize do
			turtle.select(index)
			local item = turtle.getItemDetail()
			if(self:isTableMatch(self:getBlockName(item), self.dropBlocks)) then
				turtle.drop()
			end
		end
	end

	-- Refuel the turtle
	-- Return true if refuel successful or already fuelled / false if unsuccessful
	function MinerTurtle.refuel(self, amount)
		-- Args
		local amount = amount or 1

		-- Don't bother with refuelling if the current fuel level is high enough
		if(turtle.getFuelLevel() >= amount) then
			return true
		end

		local index = 1
		local hasRefueled = false
		while(index <= self.invSize and not hasRefueled) do
			turtle.select(index)
			local isRefueling = true
			while(isRefueling) do
				if(turtle.refuel(0)) then
					if(turtle.getFuelLevel() < amount) then
						turtle.refuel(1)
					else
						isRefueling = false
						hasRefueled = true
					end
				else
					isRefueling = false
				end
			end
			index = index + 1
		end

		return hasRefueled
	end

	-- Place wrapper
	function MinerTurtle.placeBlock(self, direction)
		-- Tries to select placeable blocks in the turtle's inventor (see PLACE_SUBSTRINGS)
		local function selectBlock()
			local index = 1
			local isPlaceable = false
			while(index <= self.invSize and not isPlaceable) do
				turtle.select(index)
				local item = turtle.getItemDetail()
				if(self:isTableSubstring(self:getBlockName(item), self.placeSubstrings)) then
					isPlaceable = true
				end
				index = index + 1
			end

			return isPlaceable
		end

		-- Handle block selection
		local result = selectBlock()
		if(not result) then
			return false		-- Unable to select a block to place
		end

		-- Handle placement
		if(direction == "up") then
			result = turtle.placeUp()
		elseif(direction == "down") then
			result = turtle.placeDown()
		elseif(direction == "forward" or nil) then
			result = turtle.place()
		else
			print("placeBlock(): arg direction", direction, "isn't valid")
			return false
		end

		return result
	end

	-- Turn wrapper
	function MinerTurtle.turn(self, direction, turns)
		-- Args
		local turns = tonumber(turns) or 1

		-- Handle turning
		if(direction == "right") then
			self.orientation = (self.orientation + 1) % 4
			turtle.turnRight()
		elseif(direction == "left") then
			self.orientation = (self.orientation - 1) % 4
			turtle.turnLeft()
		else
			print("turn(): arg direction", direction, "isn't valid")
			return false
		end

		-- Turn multiple times if necessary
		if(turns > 1) then
			return self:turn(direction, turns - 1)
		else
			return true
		end
	end

	-- Dig wrapper
	function MinerTurtle.dig(self, direction)
		-- Handle digging
		local result, status, data
		if(direction == "up") then
			result = turtle.digUp()
			status, data = turtle.inspectUp()
		elseif(direction == "down") then
			result = turtle.digDown()
			status, data = turtle.inspectDown()
		elseif(direction == "forward" or direction == nil) then
			result = turtle.dig()
			status, data = turtle.inspect()
		else
			print("dig(): arg direction", direction, "isn't valid movement")
			return false
		end

		if(status and not self:isTableMatch(self:getBlockName(data), self.liquidBlocks)) then
			return self:dig(direction)
		else
			return true
		end
	end

	-- Move wrapper
	function MinerTurtle.move(self, direction, distance)
		-- Args
		local distance = tonumber(distance) or 1

		self:refuel()

		-- Handle movement (and failure to move)
		local result
		if(direction == "up") then
			result = turtle.up()
			if(result) then
				self.height = self.height + 1
			else
				return self:digMove("up")
			end

		elseif(direction == "down") then
			result = turtle.down()
			if(result) then
				self.height = self.height - 1
			else
				return self:digMove("down")
			end

		elseif(direction == "forward") then
			result = turtle.forward()
			if(result) then
				self.distance = self.distance + 1
			else
				return self:digMove("forward")
			end

		elseif(direction == "back") then
			result = turtle.back()
			if(result) then
				self.distance = self.distance - 1
			else
				self:turn("left", 2)
				self:dig("forward")
				self:turn("left", 2)
				return self:move("back")
			end

		else
			print("move(): arg direction", direction, "isn't valid movement")
			return false
		end

		-- Move multiple times if necessary
		if(distance > 1) then
			return self:move(direction, distance - 1)
		else
			return true
		end
	end

	-- Combine dig and move operations
	function MinerTurtle.digMove(self, direction, distance)
		-- Args
		local distance = tonumber(distance) or 1

		-- Handle digging and movement
		local status
		if(direction == "up") then
			self:dig("up")
			status = self:move("up")
		elseif(direction == "down") then
			self:dig("down")
			status = self:move("down")
		elseif(direction == "forward") then
			self:dig("forward")
			status = self:move("forward")
		else
			print("digMove(): arg direction", direction, "isn't valid movement")
			return false
		end

		-- DigMove multiple times if necessary
		if(distance > 1) then
			return self:digMove(direction, distance - 1)
		else
			return true
		end
	end

	-- Places a torch found in LIGHT_BLOCKS
	function MinerTurtle.placeTorch(self)
		local index = 1
		local hasTorched = false
		while(index <= self.invSize and not hasTorched) do
			turtle.select(index)
			local item = turtle.getItemDetail()
			if(self:isTableMatch(self:getBlockName(item), self.lightBlocks)) then
				hasTorched = turtle.place()
			end
			index = index + 1
		end

		return hasTorched
	end

	-- Orients the turtle then places a torch before returning to top-middle of the square
	-- TODO check for failures and correct (if-chain?)
	function MinerTurtle.orientPlaceTorch(self)
		-- Get to top of square
		if(self.squareType == DOWN_SQUARE) then
			self:move("up", 2)
		end

		-- Approach torch position
		if(self.lightSide == LIGHT_RIGHT) then
			self:turn("right")
		else
			self:turn("left")
		end

		-- Make sure the torch has a block to be placed on
		self:move("forward")
		if(not turtle.inspect()) then
			self:placeBlock("forward")
		end
		self:move("back")

		self:placeTorch()

		-- Face forward
		if(self.lightSide == LIGHT_RIGHT) then
			self:turn("left")
		else
			self:turn("right")
		end

		-- Change lightSide if necessary
		if(self.lightAlternate) then
			if(self.lightSide == LIGHT_RIGHT) then
				self.lightSide = LIGHT_LEFT
			else
				self.lightSide = LIGHT_RIGHT
			end
		end

		-- Change to UP_SQUARE to avoid extra movements
		self.squareType = UP_SQUARE

		return result
	end

	-- Tunnel out a 3x3 vertical square over a distance
	function MinerTurtle.tunnel3x3(self, distance)
		-- Tries to stop liquid blocks in front of and above the turtle
		local function attemptStopLiquid()
			local status, data = turtle.inspectUp()	-- above
			if(self:isTableMatch(self:getBlockName(data), self.liquidBlocks)) then
				self:placeBlock("up")
			end

			status, data = turtle.inspectDown() -- below
			if(self:isTableMatch(self:getBlockName(data), self.liquidBlocks)) then
				self:placeBlock("down")
			end

			status, data = turtle.inspect()	-- forward
			if(self:isTableMatch(self:getBlockName(data), self.liquidBlocks)) then
				-- Try to patch forward and above blocks if they're liquid as well
				self:move("forward")

				status, data = turtle.inspectDown() -- below
				if(self:isTableMatch(self:getBlockName(data), self.liquidBlocks)) then
					self:placeBlock("down")
				end

				status, data = turtle.inspect() -- forward-most
				if(self:isTableMatch(self:getBlockName(data), self.liquidBlocks)) then
					self:placeBlock("forward")
				end

				status, data = turtle.inspectUp() -- above
				if(self:isTableMatch(self:getBlockName(data), self.liquidBlocks)) then
					self:placeBlock("up")
				end

				self:move("back")
			end
		end

		-- Digs out the adjacent left and right blocks
		local function digAdjacentLR()
			self:turn("left")
			self:dig()
			attemptStopLiquid()

			self:turn("left", 2)
			self:dig()
			attemptStopLiquid()

			self:turn("left")
		end

		-- Args
		local distance = tonumber(distance) or 0

		-- Make sure theres a distance to traverse
		if(distance < 1) then
			return false
		end

		self:digMove("forward")

		-- Make sure there isn't any gravel or sand above
		if(self.squareType == UP_SQUARE) then
			local status, data = turtle.inspectUp()
			if(self:isTableMatch(self:getBlockName(data), self.gravityBlocks)) then
				self:dig("up")
			end
		end

		-- Start digging it out
		for row=1, SQUARE_HEIGHT do
			digAdjacentLR()
			if(row < SQUARE_HEIGHT) then
				if(self.squareType == DOWN_SQUARE) then
					self:digMove("up")
				else
					self:digMove("down")
				end
			end
		end

		-- Swap square types
		if(self.squareType == DOWN_SQUARE) then
			self.squareType = UP_SQUARE
		else
			self.squareType = DOWN_SQUARE
		end

		-- Place torch if necessary
		if(self.lightEnable and (self.distance % self.lightDistance) == 0) then
			self:orientPlaceTorch()
		end

		-- Clear out unneeded blocks from the inventory
		if(self.cleanInvEnable and (self.distance % self.cleanInvAfterDistance) == 0) then
			self:cleanInv()
		end

		-- Continue tunnelling
		self:tunnel3x3(distance - 1)
	end

	-- Init the MinerTurtle class
	function MinerTurtle.init()
		local self = setmetatable({}, MinerTurtle)

		self.height = 0					-- Height relative turtle's starting position.
		self.distance = 0				-- Distance travelled so far (in all orientations)
		self.orientation = 0			-- 0 refers to forward when placed, 1, 2, 3 refer to right, back, left.
		self.squareType = DOWN_SQUARE
		self.cleanInvEnable = CLEAN_INV_ENABLE
		self.cleanInvAfterDistance = CLEAN_INV_AFTER_DISTANCE
		self.chestSubstrings = CHEST_SUBSTRINGS
		self.placeSubstrings = PLACE_SUBSTRINGS
		self.gravityBlocks = GRAVITY_BLOCKS
		self.dropBlocks = DROP_BLOCKS
		self.liquidBlocks = LIQUID_BLOCKS
		self.invSize = TURTLE_INV_SIZE
		self.lightEnable = LIGHT_ENABLE
		self.lightBlocks = LIGHT_BLOCKS
		self.lightDistance = LIGHT_DISTANCE
		self.lightAlternate = LIGHT_ALTERNATE
		self.lightSide = LIGHT_RIGHT

		if(not self:refuel()) then
			print("No fuel available")
			return false
		end

		return self
	end
-- End MinerTurtle Class

-- Main
local function main(distance, skipDistance)
	-- Args
	local distance = tonumber(distance) or 0
	local skipDistance = tonumber(skipDistance) or 0

	-- Start mining
	local minerTurtle = MinerTurtle()
	if(not minerTurtle) then
		return
	end

	if(skipDistance > 0) then
		minerTurtle:move("forward", skipDistance)
	end

	minerTurtle:tunnel3x3(distance)
	minerTurtle:turn("left", 2)
	minerTurtle:move("forward", distance + skipDistance)

	if(minerTurtle.height > 1) then
		minerTurtle:move("down", minerTurtle.height)
	end

	minerTurtle:turn("left")
	minerTurtle:depositInv()
	minerTurtle:turn("left")
end

main(unpack(ARGS))