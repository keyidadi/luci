--[[
LuCI RPC for AmazeBee 

Copyright 2016 Asura Liu <keyidadi@gmail.com>

]]--

local ipairs,pairs,type,print,table = ipairs,pairs,type,print,table
local require = require

local sys   = require "luci.sys"
local fs     = require "nixio.fs"
local uci = require "luci.model.uci".cursor()
local mounts = luci.sys.mounts()

module "luci.jsonrpcbind.stats"
_M, _PACKAGE, _NAME = nil, nil, nil

function ssid(...)
    return sys.wifi.getiwinfo_item(..., "ssid")
end

function assoclist(...)
    return sys.wifi.getiwinfo_item(..., "assoclist")
end

--[[
---Original scanlist
function scanlist(...)
    return sys.wifi.getiwinfo_item(..., "scanlist")
end
]]--
function scanlist(...)
    local list = sys.wifi.getiwinfo_item(..., "scanlist")

    uci:foreach("sta", "sta-profile", function ( s )
        for i, v in ipairs(list) do
            if v.ssid == s.ssid then
                if s.state then
                    if s.state ~= 'disconnected' then
                        list[i].state = s.state
                    elseif s.last_connected == '0' then
                        list[i].state = 'failed'
                    else
                        list[i].state = 'saved'
                    end
                else
                    list[i].state = 'saved'
                end
                return true
            end
        end
    end)
    return list
end

function arplist()                                                     
    local arp = {}
    local ret = {}                                           
    local function arp_callback(x)                                     
        if x["Flags"] ~= "0x0" then                                
            arp[#arp+1] = x                                        
        end                                                        
    end

    local function hints_callback(mac, name)
        for k, v in pairs(arp) do
            if mac:lower() == v["HW address"] then
                ret[#ret+1] = v
                if name ~= v["IP address"] then
                    v["Host Name"] = name
                end
            end
        end
    end

    sys.net.arptable(arp_callback)                                    
    sys.net.mac_hints(hints_callback)
    return ret                                                    
end

-- sysinfo = sys.sysinfo

function version()
    local sw_info = fs.readfile("/etc/openwrt_release")
    local hw_info = fs.readfile("/etc/device_info")

    local sw = {}
    sw.id = sw_info:match("DISTRIB_ID=\"(.-)\"")
    sw.revision = sw_info:match("DISTRIB_RELEASE=\"(.-)\"") .. "." .. sw_info:match("DISTRIB_REVISION=\"(.-)\"")


    local hw = {}
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
    local wifi = {}
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
                    "ap",                   -- 10
                    "bridge"                -- 11
                }

    if ret["mode"] == nil then
        local flag = mflag[1]+mflag[2]*2+mflag[3]*4+mflag[4]*8
        if flag > 11 then 
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
--            wan["password"] = proto:get("password")
        end
        
        wan["ipaddr"] = proto:ipaddr() or ""
        wan["netmask"] = proto:netmask() or ""
        wan["gwaddr"] = proto:gwaddr() or ""
        wan["dnsaddrs"] = proto:dnsaddrs() or ""

        ret["wan"] = wan
    end

    for k, v in ipairs(lan) do            
        if v["wif"] then
            wifi["ssid"] = v["wif"]:ssid()
            wifi["encryption"] = v["wif"]["iwdata"]["encryption"]
            wifi["hidden"] = v["wif"]["iwdata"]["hidden"]
            wifi["channel"] = v["wif"]:channel()
            ret["wifi"] = wifi
        end
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

function disks()
    local disks = {}                            
    uci.foreach("samba", "sambashare", function(s)      
        for k,v in ipairs(mounts) do
            if v.mountpoint == s.path then                 
                used = v.used                           
                available = v.available
                percent = v.percent
            end                       
        end
        disks[#disks+1] = {
            name=s.name,
            path=s.path,
            used=used,                                         
            available=available,
            percent=percent
        }                               
    end);                    
    return disks                         
end
