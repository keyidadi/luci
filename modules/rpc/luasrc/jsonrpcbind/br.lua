--[[
LuCI RPC for AmazeBee

Copyright 2016 Asura Liu <keyidadi@gmail.com>

]]--

--local luci = {}
local sys  = require "luci.sys"

local type, pairs = type, pairs
local uci = require "luci.model.uci".cursor()

module "luci.jsonrpcbind.br"
_M, _PACKAGE, _NAME = nil, nil, nil


function set(section, option, value)
	if option == 'enabled' then
		local cmd = value == '1' and "enable" or "disable"
--	Let firmware do this below
--[[
		uci:revert("sta")
		local stat = uci:foreach("sta", "sta", function ( s )
			uci:set("sta", s[".name"], option, value)
		end) and uci:save("sta")
		return stat and uci:commit("sta") and sys.call("/usr/sbin/sta %s" % cmd) or "Internal Error on uci"
]]--
		return sys.call("/usr/sbin/sta %s" % cmd)

	elseif option == 'poll_interval' or option == 'max_retry' then
		uci:revert("sta")
		local stat = uci:foreach("sta", "sta", function ( s )
			uci:set("sta", s[".name"], option, value)
		end) and uci:save("sta")
		return stat and uci:commit("sta") or "Internal Error in UCI"

	elseif option == 'key' then
		uci:revert("sta")
		local stat = false
		local section_name = nil

		stat = uci:foreach("sta", "sta-profile", function ( s )
			if s.ssid == section then
				section_name = s[".name"]
				return true
			end
		end)

		if stat and section_name then
			stat = uci:set("sta", section_name, "key", value)
			and uci:reorder("sta", section_name, 1)
		else
			stat = uci:add("sta", "sta-profile")
			if stat then
				stat =  uci:set("sta", stat, "ssid", section)
				and uci:set("sta", stat, "key", value) and uci:reorder("sta", stat, 1)
			end
		end
		return stat and uci:commit("sta") and sys.call("/usr/sbin/sta &") or "Internal Error in UCI"
	else
		return "Parameter invalid"
	end
end
	
function get( )
	return uci:get_all("sta") or "Internal Error in UCI"
end

function start( ssid )
	uci:revert("sta")
	local section_name = nil
	local stat = uci:foreach("sta", "sta-profile", function ( s )
			if s.ssid == ssid then
				section_name = s[".name"]
				return true
			end
		end)

	if stat and section_name then
		stat = uci:reorder("sta", section_name, 1) and uci:commit("sta")
		return stat and sys.call("/usr/sbin/sta &") or "Internal Error in UCI"
	else
		return "Selected Profile Not Found"
	end
end

function delete( ssid )
	uci:revert("sta")
	local stat = uci:delete_all("sta", "sta-profile", function ( s )
		if s[".name"] == ssid then
			return true
		end
	end)
	return stat and uci:commit("sta") or "Internal Error in UCI"
end