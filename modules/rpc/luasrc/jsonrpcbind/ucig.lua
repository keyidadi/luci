--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth <steven@midlink.org>
Copyright 2008 Jo-Philipp Wich <xm@leipzig.freifunk.net>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

$Id$
]]--

local uci   = require "luci.model.uci".cursor()
local ucis  = require "luci.model.uci".cursor_state()
local table = require "table"


module "luci.jsonrpcbind.ucig"
_M, _PACKAGE, _NAME = nil, nil, nil

function changes(...)
	return uci:changes(...)
end

function get(config, ...)
	uci:load(config)
	return uci:get(config, ...)
end

function get_all(config, ...)
	uci:load(config)
	return uci:get_all(config, ...)
end

function get_state(config, ...)
	ucis:load(config)
	return ucis:get(config, ...)
end

