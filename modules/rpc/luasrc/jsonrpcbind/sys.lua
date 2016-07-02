--[[
LuCI RPC for AmazeBee

Copyright 2016 Asura Liu <keyidadi@gmail.com>

]]--

local sys   = require "luci.sys"

local type, pairs = type, pairs
local uci = require "luci.model.uci".cursor()

module "luci.jsonrpcbind.sys"
_M, _PACKAGE, _NAME = nil, nil, nil

upgrade = sys.upgrade

halt = sys.halt

reboot = sys.reboot

refactory = sys.refactory

user = {}
user.setpasswd = sys.user.setpasswd

uptime = sys.uptime

local function br_get( section, option )
	return uci:get_first("sta", section, option) or "Internal Error in UCI"
end

local function br_set( section, option, value )
	if option == 'enabled' then
		local cmd = value == '1' and "enable" or "disable"

		uci:revert("sta")
		local stat = uci:foreach("sta", "sta", function ( s )
			uci:set("sta", s[".name"], option, value)
		end) and uci:save("sta")

		return stat and uci:commit("sta") or "Internal Error in UCI"

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
		return stat and uci:commit("sta") and sys.call("/usr/sbin/sta &") == 0 or "Internal Error in UCI"
	else
		return "Parameter invalid"
	end
end

local function br_start( ssid )
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
		return stat and sys.call("/usr/sbin/sta &") == 0
	else
		return "Selected Profile Not Found"
	end
end

local function br_delete( ssid )
	uci:revert("sta")
	local stat = false
	uci:delete_all("sta", "sta-profile", function ( s )
		if s.ssid == ssid then
			stat = true
			return true
		end
	end)
	return stat and uci:commit("sta")
end

function get( config, section, option )
	if config == 'br' then
		return br_get(section, option)
	end
end

function set( config, section, option, value )
	if config == 'br' then
		if option == 'cmd' and value == 'start' then
			return br_start(section)
		else
			return br_set(section, option, value)
		end
	end
end

function delete( config, section )
	if config == 'br' then
		return br_delete(section)
	end
end
