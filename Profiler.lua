local class = require "class"
local Profiler = class:derive("Profiler")

local Vec2 = require("Essentials/Vector2")

function Profiler:new(name)
	self.name = name
	self.times = {}
	self.t = nil
	self.totalLags = 0
end

function Profiler:start()
	self.t = love.timer.getTime()
end

function Profiler:stop()
	if not self.t then return end
	
	if #self.times == 300 then table.remove(self.times, 1) end
	local t = love.timer.getTime() - self.t
	if t > 1 / 15 then self.totalLags = self.totalLags + 1 end
	table.insert(self.times, t)
	
	self.t = nil
end

function Profiler:draw(pos)
	-- Counting
	local total = 0
	local max = nil
	local min = nil
	
	-- Background
	love.graphics.setColor(0, 0, 0, 0.5)
	love.graphics.rectangle("fill", pos.x, pos.y - 240, 300, 240)
	
	-- Graph
	for i, t in ipairs(self.times) do
		total = total + t
		if not max or max < t then max = t end
		if not min or min > t then min = t end
		
		local h = t * 30 * 100
		if h > 200 then
			h = 200
			love.graphics.setColor(1, 0, 0)
		else
			love.graphics.setColor(0, 1, 1)
		end
		local p = pos + Vec2(i, -h)
		love.graphics.rectangle("fill", p.x, p.y, 1, h)
	end
	
	-- Text
	local p = pos + Vec2(0, -232)
	love.graphics.setColor(1, 1, 1)
	love.graphics.print(self.name .. " [" .. tostring(self.totalLags) .. "]", p.x, p.y)
	if #self.times > 0 then
		local p = pos + Vec2(0, -216)
		love.graphics.setColor(1, 1, 1)
		love.graphics.print("average: " .. tostring(math.floor(total / #self.times * 1000)) .. " ms", p.x, p.y)
	end
	if min then
		local p = pos + Vec2(100, -216)
		love.graphics.setColor(1, 1, 1)
		love.graphics.print("min: " .. tostring(math.floor(min * 1000)) .. " ms", p.x, p.y)
	end
	if max then
		local p = pos + Vec2(200, -216)
		love.graphics.setColor(1, 1, 1)
		love.graphics.print("max: " .. tostring(math.floor(max * 1000)) .. " ms", p.x, p.y)
	end
	
	-- Lines
	love.graphics.setLineWidth(1)
	local p1 = pos + Vec2(0, -200)
	local p2 = pos + Vec2(300, -200)
	love.graphics.setColor(1, 0, 0)
	love.graphics.line(p1.x, p1.y, p2.x, p2.y)
	love.graphics.print("0.067 (1/15)", p1.x, p1.y - 16)
	local p1 = pos + Vec2(0, -150)
	local p2 = pos + Vec2(300, -150)
	love.graphics.setColor(1, 0.5, 0)
	love.graphics.line(p1.x, p1.y, p2.x, p2.y)
	love.graphics.print("0.050 (1/20)", p1.x, p1.y - 16)
	local p1 = pos + Vec2(0, -100)
	local p2 = pos + Vec2(300, -100)
	love.graphics.setColor(1, 1, 0)
	love.graphics.line(p1.x, p1.y, p2.x, p2.y)
	love.graphics.print("0.033 (1/30)", p1.x, p1.y - 16)
	local p1 = pos + Vec2(0, -50)
	local p2 = pos + Vec2(300, -50)
	love.graphics.setColor(0, 1, 0)
	love.graphics.line(p1.x, p1.y, p2.x, p2.y)
	love.graphics.print("0.016 (1/60)", p1.x, p1.y - 16)
	local p1 = pos + Vec2(0, 0)
	local p2 = pos + Vec2(300, 0)
	love.graphics.setColor(1, 1, 1)
	love.graphics.line(p1.x, p1.y, p2.x, p2.y)
end

return Profiler