local class = require "class"
local SphereGroup = class:derive("SphereGroup")

local Vec2 = require("Essentials/Vector2")
local Image = require("Essentials/Image")
local Color = require("Essentials/Color")

local Sphere = require("Sphere")

function SphereGroup:new(sphereChain)
	self.sphereChain = sphereChain
	-- these two are filled later by the sphere chain object
	self.prevGroup = nil
	self.nextGroup = nil
	
	self.offset = 0
	self.speed = 0
	self.maxSpeed = 0
	self.spheres = {}
	self.matchCheck = true -- this is used ONLY in vise destruction to not trigger a chain reaction
	
	self.sphereShadowImage = game.resourceBank:getImage("img/game/ball_shadow.png")
	
	self.delQueue = false
end

function SphereGroup:update(dt)
	local speedBound = self.sphereChain.path:getSpeed(self:getLastSphereOffset())
	if self:isMagnetizing() then
		self.maxSpeed = -200 * math.max(self.sphereChain.combo, 1)
	else
		self.maxSpeed = 0
		if not self.matchCheck then self.matchCheck = true end
	end
	-- the vise is pushing
	if not self.prevGroup and self.sphereChain.reverseTime == 0 then
		-- normal movement
		self.maxSpeed = speedBound
		-- slow
		if self.sphereChain.slowTime > 0 then self.maxSpeed = self.maxSpeed * 0.3 end
		-- stop
		if self.sphereChain.stopTime > 0 then self.maxSpeed = 0 end
		-- when the level is over
		if game.session.level.lost then self.maxSpeed = 2000 end
	end
	-- if the vise is pulling (reverse)
	if not game.session.level.lost and not self.nextGroup and not self:isMagnetizing() and self.sphereChain.reverseTime > 0 then
		self.maxSpeed = -100
	end
	
	if self.speed > self.maxSpeed then
		if self.sphereChain.reverseTime > 0 then
			self.speed = self.maxSpeed
		elseif self.prevGroup then
			self.speed = math.max(self.speed - 500 * dt, self.maxSpeed)
		elseif self.sphereChain.slowTime > 0 or self.sphereChain.stopTime > 0 then
			self.speed = math.max(self.speed - 200 * dt, self.maxSpeed)
		else
			self.speed = self.maxSpeed
		end
	end
	if self.speed < self.maxSpeed then
		--if game.session.level.lost then
		--	self.speed = math.min(self.speed + 250 * dt, self.maxSpeed)
		--else
			self.speed = math.min(self.speed + 500 * dt, self.maxSpeed)
		--end
	end
	-- anti-slow-catapulting
	if not game.session.level.lost and self.speed > speedBound then self.speed = speedBound end
	
	self:move(self.speed * dt)
	
	-- tick the powerup timers
	-- the vise is pushing
	if not self.prevGroup and self.sphereChain.reverseTime == 0 then
		if self.sphereChain.slowTime > 0 and self.speed == self.maxSpeed then self.sphereChain.slowTime = math.max(self.sphereChain.slowTime - dt, 0) end
		if self.sphereChain.stopTime > 0 and self.speed == self.maxSpeed then self.sphereChain.stopTime = math.max(self.sphereChain.stopTime - dt, 0) end
	end
	-- if the vise is pulling (reverse)
	if not self.nextGroup and not self:isMagnetizing() and self.sphereChain.reverseTime > 0 then
		if self.speed == self.maxSpeed then self.sphereChain.reverseTime = math.max(self.sphereChain.reverseTime - dt, 0) end
		-- if it goes too far, nuke the powerup
		if self:getLastSphereOffset() < 0 then self.sphereChain.reverseTime = 0 end
	end
	
	for i = #self.spheres, 1, -1 do
		if game.session.level.lost and self:getSphereOffset(i) >= self.sphereChain.path.length then self:destroySphere(i) end
	end
	
	for i, sphere in ipairs(self.spheres) do
		if not sphere.delQueue then sphere:update(dt) end
	end
end

function SphereGroup:addSphere(pos, position, color)
	-- pos - position in where was the shot sphere, position - sphere ID (the new sphere will gain the given ID = creation BEHIND the sphere with the given ID)
	local sphere = Sphere(self, color, pos)
	local prevSphere = self.spheres[position - 1]
	local nextSphere = self.spheres[position]
	sphere.prevSphere = prevSphere
	sphere.nextSphere = nextSphere
	if prevSphere then prevSphere.nextSphere = sphere end
	if nextSphere then nextSphere.prevSphere = sphere end
	table.insert(self.spheres, position, sphere)
	-- if it's a first sphere in the group, lower the offset
	if self.prevGroup and position == 1 then
		self.offset = self.offset - 32
		self:updateSphereOffsets()
	end
end

function SphereGroup:addSpherePos(position)
	-- we can't add spheres behind the vise
	if not self.prevGroup and position == 1 then return 2 end
	return position
end

function SphereGroup:destroySphere(position)
	-- no need to divide if it's the first or last sphere in this group
	if position == 1 then
		self.spheres[position]:delete()
		table.remove(self.spheres, position)
		self.offset = self.offset + 32
		self:updateSphereOffsets()
	elseif position == #self.spheres then
		self.spheres[position]:delete()
		table.remove(self.spheres, position)
	else
		self:divide(position)
		self.spheres[position]:delete()
		table.remove(self.spheres, position)
	end
	
	self:checkDeletion()
end

function SphereGroup:destroySpheres(position1, position2)
	-- to avoid more calculation than is needed
	-- example:
	-- before:     oooo[ooo]ooooooo  (p1 = 5, p2 = 7) !BOTH INCLUSIVE!
	-- after:      oooo     ooooooo   gap length: 3
	
	-- check if it's on the beginning or on the end of the group
	if position1 == 1 then
		for i = 1, position2 do
			self.spheres[1]:delete()
			table.remove(self.spheres, 1)
		end
		self.offset = self.offset + position2 * 32
		self:updateSphereOffsets()
	elseif position2 == #self.spheres then -- or maybe on the end?
		for i = position1, position2 do
			self.spheres[#self.spheres]:delete()
			table.remove(self.spheres, #self.spheres)
		end
	else
		-- divide on the end of the broken spheres
		self:divide(position2)
		for i = position1, position2 do
			self.spheres[#self.spheres]:delete()
			table.remove(self.spheres, #self.spheres)
		end
	end
	
	self:checkDeletion()
end

function SphereGroup:updateSphereOffsets()
	for i, sphere in ipairs(self.spheres) do sphere:updateOffset() end
end

function SphereGroup:checkDeletion()
	-- if this group contains no spheres, it gets yeeted
	local shouldDelete = true
	for i, sphere in ipairs(self.spheres) do
		if not sphere.delQueue then shouldDelete = false end
	end
	if shouldDelete then self:delete() end
	-- if there's only a vise in this chain, the whole chain gets yeeted!
	if not self.prevGroup and not self.nextGroup and #self.spheres == 1 and self.spheres[1].color == 0 then
		if not game.session.level.lost then game.session.level:spawnCollectible(self:getSpherePos(1), game.session.level:newGemData()) end
		self.spheres[1]:delete()
		self.sphereChain:delete(false)
	end
end

function SphereGroup:move(offset)
	-- if it's gonna crash into the previous group, move only what is needed
	local crashes = self.prevGroup and offset < -(self:getSphereOffset(1) - self.prevGroup:getLastSphereOffset() - 32 * self.spheres[1].size)
	if crashes then offset = -(self.prevGroup:getLastSphereOffset() - 32 * self.spheres[1].size) end
	self.offset = self.offset + offset
	self:updateSphereOffsets()
	-- join the previous group if this group starts to overlap the previous one
	if crashes then self:join() end
	-- if reached the end of the level, it's over
	if self:getLastSphereOffset() >= self.sphereChain.path.length and not crashes and not self:isMagnetizing() and not self:hasShotSpheres() then
		if not game.session.level.lost then game.session.level:lose() end
	end
end

function SphereGroup:join()
	-- join this group with a previous group
	-- the first group has nothing to join to
	if not self.prevGroup then return end
	-- deploy the value to check for combo and linking later
	local joinPosition = #self.prevGroup.spheres
	-- modify the previous group to contain the joining spheres
	for i, sphere in ipairs(self.spheres) do
		table.insert(self.prevGroup.spheres, sphere)
		sphere.sphereGroup = self.prevGroup
	end
	if self.speed < 0 then self.prevGroup.speed = -200 * math.max(self.sphereChain.combo, 1) end
	-- link the spheres from both groups
	self.prevGroup.spheres[joinPosition].nextSphere = self.spheres[1]
	self.spheres[1].prevSphere = self.prevGroup.spheres[joinPosition]
	-- recalculate sphere positions
	self.prevGroup:updateSphereOffsets()
	-- remove this group
	self:delete()
	-- check for combo
	if not game.session.level.lost and game.session:colorsMatch(self.prevGroup.spheres[joinPosition].color, self.spheres[1].color) and self.matchCheck and self.prevGroup:shouldMatch(joinPosition) then
		self.prevGroup:matchAndDelete(joinPosition)
	end
	game:playSound("sphere_group_join")
end

function SphereGroup:divide(position)
	-- example:
	-- group: ooooooo
	-- position: 3
	-- groups after: ooo | oooo
	-- that means this group will remain with 3 spheres (the break appears AFTER the specified position) and the rest will be given to a new group
	
	-- first, create a new group and give its properties there
	local newGroup = SphereGroup(self.sphereChain)
	newGroup.offset = self:getSphereOffset(position + 1)
	newGroup.speed = self.speed
	for i = position + 1, #self.spheres do
		local sphere = self.spheres[i]
		sphere.sphereGroup = newGroup
		table.insert(newGroup.spheres, sphere)
		self.spheres[i] = nil
	end
	-- break sphere links between two new groups
	self.spheres[position].nextSphere = nil
	newGroup.spheres[1].prevSphere = nil
	-- recalculate sphere positions
	newGroup:updateSphereOffsets()
	-- rearrange group links
	newGroup.prevGroup = self
	newGroup.nextGroup = self.nextGroup
	if self.nextGroup then self.nextGroup.prevGroup = newGroup end
	-- here, the previous group stays the same
	self.nextGroup = newGroup
	
	-- add to the master
	table.insert(self.sphereChain.sphereGroups, self.sphereChain:getSphereGroupID(self), newGroup)
end

function SphereGroup:delete()
	if self.delQueue then return end
	-- do this if this group is empty
	self.delQueue = true
	-- update links !!!
	if self.prevGroup then
		self.prevGroup.nextGroup = self.nextGroup
		self.prevGroup:checkDeletion() -- if the vise might be alone in its own group and last spheres ahead of him are being just destroyed
	end
	if self.nextGroup then self.nextGroup.prevGroup = self.prevGroup end
	table.remove(self.sphereChain.sphereGroups, self.sphereChain:getSphereGroupID(self))
end

function SphereGroup:shouldFit(position)
	return
		self:getSphereInChain(position - 1) and game.session:colorsMatch(self:getSphereInChain(position - 1).color, self.spheres[position].color)
	or
		self:getSphereInChain(position + 1) and game.session:colorsMatch(self:getSphereInChain(position + 1).color, self.spheres[position].color)
end

function SphereGroup:shouldBoostCombo(position)
	return self:getMatchLengthInChain(position) >= 3
end

function SphereGroup:shouldMatch(position)
	local position1, position2 = self:getMatchBounds(position)
	-- if not enough spheres
	if position2 - position1 < 2 then return false end
	-- if is magnetizing with previous group and we want to maximize the count of spheres
	if self.prevGroup and not self.prevGroup.delQueue and game.session:colorsMatch(self.prevGroup:getLastSphere().color, self.spheres[1].color) and position1 == 1 then return false end
	-- same check with the next group
	if self.nextGroup and not self.nextGroup.delQueue and game.session:colorsMatch(self:getLastSphere().color, self.nextGroup.spheres[1].color) and position2 == #self.spheres then return false end
	-- all checks passed?
	return true
end

function SphereGroup:matchAndDelete(position)
	local position1, position2 = self:getMatchBounds(position)
	
	local boostCombo = false
	-- abort if any sphere from the given ones has not joined yet and see if we have to boost the combo
	for i = position1, position2 do
		if self.spheres[i].size < 1 then return end
		boostCombo = boostCombo or self.spheres[i].boostCombo
	end
	
	local pos = self.sphereChain.path:getPos((self:getSphereOffset(position1) + self:getSphereOffset(position2)) / 2)
	local color = self.spheres[position].color
	self:destroySpheres(position1, position2)
	
	local soundID = math.min(math.max(position2 - position1 - 1, 1), 5)
	game:playSound("sphere_destroy_" .. tostring(soundID), 1 + self.sphereChain.combo * 0.05)
	self.sphereChain.combo = self.sphereChain.combo + 1
	if boostCombo then game.session.level.combo = game.session.level.combo + 1 end
	
	local score = (position2 - position1 + 1) * 100
	if boostCombo then score = score + math.max(game.session.level.combo - 3, 0) * 100 end
	score = score * self.sphereChain.combo
	game.session.level:grantScore(score)
	
	local scoreText = numStr(score)
	if boostCombo and game.session.level.combo > 2 then scoreText = scoreText .. "\n COMBO X" .. tostring(game.session.level.combo) end
	if self.sphereChain.combo ~= 1 then scoreText = scoreText .. "\n CHAIN X" .. tostring(self.sphereChain.combo) end
	local scoreTextColor = color > 0 and color or 0
	game.session.level:spawnFloatingText(scoreText, pos, "fonts/score" .. scoreTextColor .. ".json")
	
	local spawnCoin = math.random() < (position2 - position1 - 2) * 0.2
	if spawnCoin then game.session.level:spawnCollectible(pos, {type = "coin"}) end
	
	local spawnPowerup = (self.sphereChain.combo == 1 and boostCombo and game.session.level.combo % 3 == 0) or self.sphereChain.combo % 3 == 0
	if spawnPowerup then game.session.level:spawnCollectible(pos, game.session.level:newPowerupData()) end
	
	game.session.level.maxCombo = math.max(game.session.level.combo, game.session.level.maxCombo)
	game.session.level.maxChain = math.max(self.sphereChain.combo, game.session.level.maxChain)
end

function SphereGroup:isMagnetizing()
	--print("----- " .. (self.prevGroup and self.prevGroup:getDebugText() or "xxx") .. " -> " .. self:getDebugText() .. " -> " .. (self.nextGroup and self.nextGroup:getDebugText() or "xxx"))
	--print("----- " .. tostring(self.sphereChain:getSphereGroupID(self.prevGroup)) .. " -> " .. tostring(self.sphereChain:getSphereGroupID(self)) .. " -> " .. tostring(self.sphereChain:getSphereGroupID(self.nextGroup)))
	if not self.prevGroup or self.prevGroup.delQueue or #self.spheres == 0 then return false end
	return game.session:colorsMatch(self.prevGroup:getLastSphere().color, self.spheres[1].color) or self.prevGroup:getLastSphere().color == 0
end



function SphereGroup:draw(hidden, shadow)
	-- hidden: with that, you can filter the spheres drawn either to the visible ones or to the invisible ones
	-- shadow: to make all shadows rendered before spheres
	--love.graphics.print(self:getDebugText2(), 10, 10 * #self.spheres)
	for i, sphere in ipairs(self.spheres) do
		if self:getSphereHidden(i) == hidden then
			if shadow then
				if sphere.size == 1 then
					self.sphereShadowImage:draw(self:getSpherePos(i) + Vec2(4), Vec2(0.5))
				else
					self.sphereShadowImage:draw(self:getSpherePos(i) * sphere.size + sphere.shootOrigin * (1 - sphere.size) + Vec2(4), Vec2(0.5))
				end
			else
				if sphere.size == 1 then
					game.sphereSprites[sphere.color]:draw(self:getSpherePos(i), {angle = self:getSphereAngle(i), color = self:getSphereColor(i), frame = math.ceil(32 - sphere.frame)})
				else
					game.sphereSprites[sphere.color]:draw(self:getSpherePos(i) * sphere.size + sphere.shootOrigin * (1 - sphere.size), {angle = self:getSphereAngle(i), color = self:getSphereColor(i), frame = 1})
				end
			end
		end
	end
	--self:drawDebug()
end

function SphereGroup:drawDebug()
	love.graphics.setColor(1, 0.5, 0)
	local pos = self.sphereChain.path:getPos(self.offset)
	love.graphics.circle("fill", pos.x, pos.y, 4)
end

function SphereGroup:getMatchPositions(position)
	local positions = {position}
	local color = self.spheres[position].color
	-- seek backwards
	local seekPosition = position
	while true do
		seekPosition = seekPosition - 1
		-- end if no more spheres or found an unmatched sphere
		if not self.spheres[seekPosition] or not game.session:colorsMatch(self.spheres[seekPosition].color, self.spheres[seekPosition + 1].color) then break end
		--if self.spheres[seekPosition].size < 1 then return {position} end -- combinations with not spawned yet balls are forbidden
		table.insert(positions, seekPosition)
	end
	-- seek forwards
	local seekPosition = position
	while true do
		seekPosition = seekPosition + 1
		-- end if no more spheres or found an unmatched sphere
		if not self.spheres[seekPosition] or not game.session:colorsMatch(self.spheres[seekPosition].color, self.spheres[seekPosition - 1].color) then break end
		--if self.spheres[seekPosition].size < 1 then return {position} end -- combinations with not spawned yet balls are forbidden
		table.insert(positions, seekPosition)
	end
	return positions
end

function SphereGroup:getMatchBounds(position)
	local position1 = position
	local position2 = position
	local color = self.spheres[position].color
	-- seek backwards
	while true do
		position1 = position1 - 1
		-- end if no more spheres or found an unmatched sphere
		if not self.spheres[position1] or not game.session:colorsMatch(self.spheres[position1].color, self.spheres[position1 + 1].color) then break end
	end
	-- seek forwards
	while true do
		position2 = position2 + 1
		-- end if no more spheres or found an unmatched sphere
		if not self.spheres[position2] or not game.session:colorsMatch(self.spheres[position2].color, self.spheres[position2 - 1].color) then break end
	end
	return position1 + 1, position2 - 1
end

function SphereGroup:getMatchLengthInChain(position)
	-- special seek for a shouldBoostCombo function
	local position1 = position
	local position2 = position
	local color = self.spheres[position].color
	-- seek backwards
	while true do
		position1 = position1 - 1
		-- end if no more spheres or found an unmatched sphere
		if not self:getSphereInChain(position1) or not game.session:colorsMatch(self:getSphereInChain(position1).color, self:getSphereInChain(position1 + 1).color) then break end
	end
	-- seek forwards
	while true do
		position2 = position2 + 1
		-- end if no more spheres or found an unmatched sphere
		if not self:getSphereInChain(position2) or not game.session:colorsMatch(self:getSphereInChain(position2).color, self:getSphereInChain(position2 - 1).color) then break end
	end
	return position2 - position1 - 1
end

function SphereGroup:getLastSphere()
	return self.spheres[#self.spheres]
end

function SphereGroup:getSphereOffset(sphereID)
	return self.offset + self.spheres[sphereID].offset
end

function SphereGroup:getSphereID(sphere)
	for i, sphereT in ipairs(self.spheres) do if sphereT == sphere then return i end end
end

function SphereGroup:getLastSphereOffset()
	return self:getSphereOffset(#self.spheres)
end

function SphereGroup:getLastGroup()
	local group = self
	while true do if group.nextGroup then group = group.nextGroup else return group end end
end

function SphereGroup:getSpherePos(sphereID)
	return self.sphereChain.path:getPos(self:getSphereOffset(sphereID))
end

function SphereGroup:getSphereAngle(sphereID)
	return self.sphereChain.path:getAngle(self:getSphereOffset(sphereID))
end

function SphereGroup:getSphereHidden(sphereID)
	return self.sphereChain.path:getHidden(self:getSphereOffset(sphereID))
end

function SphereGroup:getSphereColor(sphereID)
	local brightness = self.sphereChain.path:getBrightness(self:getSphereOffset(sphereID))
	return Color(brightness)
end

function SphereGroup:getLastSpherePos()
	return self:getSpherePos(#self.spheres)
end

function SphereGroup:getSphereInChain(sphereID)
	-- values out of bounds are possible, it will seek in neighboring spheres then
	if sphereID < 1 then
		-- previous group
		if not self.prevGroup or self.prevGroup.delQueue then return nil end
		return self.prevGroup:getSphereInChain(sphereID + #self.prevGroup.spheres)
	elseif sphereID > #self.spheres then
		-- next group
		if not self.nextGroup or self.nextGroup.delQueue then return nil end
		return self.nextGroup:getSphereInChain(sphereID - #self.spheres)
	else
		-- this group
		return self.spheres[sphereID]
	end
end

function SphereGroup:hasShotSpheres()
	for i, sphere in ipairs(self.spheres) do
		if sphere.size < 1 then return true end
	end
	return false
end



function SphereGroup:getDebugText()
	local text = ""
	text = text .. "["
	for j, sphere in ipairs(self.spheres) do
		text = text .. tostring(sphere.color)
	end
	text = text .. "]"
	return text
end

function SphereGroup:getDebugText2()
	local text = ""
	for i, sphere in ipairs(self.spheres) do
		if sphere.prevSphere then
			text = text .. tostring(sphere.prevSphere.color)
		else
			text = text .. "xxx"
		end
		text = text .. " -> " .. tostring(sphere.color) .. " -> "
		if sphere.nextSphere then
			text = text .. tostring(sphere.nextSphere.color)
		else
			text = text .. "xxx"
		end
		text = text .. "\n"
	end
	return text
end

return SphereGroup