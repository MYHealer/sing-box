#!/usr/bin/lua
-- switch_node.lua: modify sing-box outbound server without touching DNS
-- Usage: lua switch_node.lua <ip> <port>

local jsonc = require "luci.jsonc"
local ip = arg[1]
local port = tonumber(arg[2])

if not ip or not port then
    io.stderr:write("Usage: switch_node.lua <ip> <port>\n")
    os.exit(1)
end

local cfg_path = "/etc/sing-box/config.json"

local f = io.open(cfg_path, "r")
if not f then
    io.stderr:write("Cannot open " .. cfg_path .. "\n")
    os.exit(1)
end
local content = f:read("*a")
f:close()

local cfg = jsonc.parse(content)
if not cfg then
    io.stderr:write("Failed to parse config.json\n")
    os.exit(1)
end

if cfg.outbounds and cfg.outbounds[1] then
    cfg.outbounds[1].server = ip
    cfg.outbounds[1].server_port = port
else
    io.stderr:write("No outbounds found in config\n")
    os.exit(1)
end

f = io.open(cfg_path, "w")
if not f then
    io.stderr:write("Cannot write " .. cfg_path .. "\n")
    os.exit(1)
end
f:write(jsonc.stringify(cfg, 2))
f:close()
