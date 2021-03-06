local class = require "class"
local UIWidgetParticle = class:derive("UIWidgetParticle")

local Vec2 = require("Essentials/Vector2")
local ParticleManager = require("Particle/Manager")

function UIWidgetParticle:new(parent, path)
	self.type = "particle"
	
	self.parent = parent
	self.path = path
	
	self.manager = ParticleManager()
end

function UIWidgetParticle:update(dt)
	self.manager:update(dt)
end

function UIWidgetParticle:spawn()
	self.manager:useSpawnerData(self.path, self.parent:getPos())
end



function UIWidgetParticle:draw()
	self.manager:draw()
end

return UIWidgetParticle