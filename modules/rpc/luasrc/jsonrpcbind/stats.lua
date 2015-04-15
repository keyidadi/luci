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

local sys   = require "luci.sys"
local table = require "table"


module "luci.jsonrpcbind.stats"
_M, _PACKAGE, _NAME = nil, nil, nil

function abc(...)
	return sys.exec(...)
end

