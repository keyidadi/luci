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

local ipairs,pairs,type,print,table = ipairs,pairs,type,print,table
local require = require

local sys   = require "luci.sys"
local fs     = require "nixio.fs"

module "luci.jsonrpcbind.stats"
_M, _PACKAGE, _NAME = nil, nil, nil

function getiwlist(...)
    return sys.wifi.getiwinfo_item(..., "assoclist")
end

function arp()                                                     
    local arplist = {}                                                 
    local function callback(x)                                     
        if x["Flags"] ~= "0x0" then                                
            arplist[#arplist+1] = x                                        
        end                                                        
    end                                                            
    sys.net.arptable(callback)                                     
    return arplist                                                     
end 

-- sysinfo = sys.sysinfo

function version()
    local sw_info = fs.readfile("/etc/openwrt_release")
    local hw_info = fs.readfile("/etc/device_info")

    local sw = {}
    sw.id = sw_info:match("DISTRIB_ID=\"(.-)\"")
    sw.release = sw_info:match("DISTRIB_RELEASE=\"(.-)\"")
    sw.revision = sw_info:match("DISTRIB_REVISION=\"(.-)\"")

    local hw = {}
    hw.manufacturer = hw_info:match("DEVICE_MANUFACTURER=\"(.-)\"")
    hw.product = hw_info:match("DEVICE_PRODUCT=\"(.-)\"")
    hw.revision = hw_info:match("DEVICE_REVISION=\"(.-)\"")

    local ret = {}
    ret["sw"] = sw
    ret["hw"] = hw
    return ret
end

function mode()
    local ntm = require "luci.model.network".init()
    local fwm = require "luci.model.firewall".init()
    local ret = {}

    local wan = {}
    local lan = {}
    local mflag = {0,0,0,0} -- wwan 1, wlan 2, ewan 4, elan 8

    -- read wan and lan from firewall zone 
    for _, zone in ipairs(fwm:get_zones()) do
        if zone:name() == "wan" then
            for _, net in ipairs(zone:get_networks()) do
                local proto = ntm:get_network(net)
                if proto and proto:is_bridge() then
                    for _,ifc in ipairs(proto:get_interfaces()) do
                        wan[#wan+1] = ifc
                        if ifc:type() == "wifi" then
                            mflag[1] = 1
                        else
                            mflag[3] = 1
                        end
                    end
                elseif proto then
                    wan[#wan+1] = proto:get_interface()
                    if proto:get_interface():type() == "wifi" then
                        mflag[1] = 1
                    else
                        mflag[3] = 1
                    end
                end
            end
        end
    end

    local proto = ntm:get_network("lan")
    if proto:is_bridge() then
        for _,ifc in pairs(proto:get_interfaces()) do
            lan[#lan+1] = ifc
            if ifc:type() == "wifi" then
                mflag[2] = 1
            else
                mflag[4] = 1
            end
        end
    else
        lan[#lan+1] = proto:get_interface()
        if ifc:type() == "wifi" then
            mflag[2] = 1
        else
            mflag[4] = 1
        end
    end

    local mode_tab = {    
                    "none",                 -- 0
                    "wwan-only",            -- 1
                    "repeater",             -- 2
                    "bridge",               -- 3
                    "wan-only",             -- 4
                    "mix",                  -- 5
                    "router",               -- 6
                    "mix",                  -- 7
                    "lan-only",             -- 8
                    "client",               -- 9
                    "ap"                    -- 10
                }

    if ret["mode"] == nil then
        local flag = mflag[1]+mflag[2]*2+mflag[3]*4+mflag[4]*8
        if flag > 10 then 
            ret["mode"] = "mix"
        elseif mode_tab[flag] then
            ret["mode"] = mode_tab[flag+1]
        end
    end

    if #wan > 0 then
        local proto = wan[1]:get_network()
        wan = {}
        wan["name"] = proto:name()
        wan["proto"] = proto:proto()
        
        if wan["proto"] == "pppoe" then
            wan["username"] = proto:get("username")
            wan["password"] = proto:get("password")
        end
        
        wan["ipaddr"] = proto:ipaddr() or ""
        wan["netmask"] = proto:netmask() or ""
        wan["gwaddr"] = proto:gwaddr() or ""
        wan["dnsaddrs"] = proto:dnsaddrs() or ""

        ret["wan"] = wan
    end

    return ret
end

function print_r(data, depth)
    local depth = depth or 3

    function tableprint(t, local_depth)
        local all = {}

        local function table_len(t) 
            local i = 0 
            for k, v in pairs(t) do 
                i = i + 1 
            end 
            return i 
        end 

        for k,v in pairs(t) do
            if k ~= "__index" then
                if type(v) ~= "table" then
                    all[k] = v
                elseif table_len(v) == 0 then
                    all[k] = ""
                elseif local_depth < depth then
                    all[k] = tableprint(v,local_depth+1)
                else
                    all[k] = "*"
                end
            end
        end
        return all
    end
    return tableprint(data,0)
end
