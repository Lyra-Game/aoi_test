local skynet = require "skynet"
local socket = require "skynet.socket"
local service = require "skynet.service"
local websocket = require "http.websocket"
local cjson = require "cjson"
local Grid = require("grid")

local encode = cjson.encode
local decode = function(str)
    local ok, ret = pcall(cjson.decode, str)
    if not ok then
        return nil, ret
    end
    return ret
end

local handle = {}
local MODE = ...

if MODE == "agent" then
    local client_fd_map = {}
    function handle.connect(id)
        print("ws connect from: " .. tostring(id))
        client_fd_map[id] = {}
        -- client_fd = id
    end
    function handle.handshake(id, header, url)
        local addr = websocket.addrinfo(id)
        print("ws handshake from: " .. tostring(id), "url", url, "addr:", addr)
        print("----header-----")
        for k, v in pairs(header) do
            print(k, v)
        end
        print("--------------")
    end
    function handle.ping(id)
        print("ws ping from: " .. tostring(id) .. "\n")
    end
    function handle.pong(id)
        print("ws pong from: " .. tostring(id))
    end
    function handle.close(id, code, reason)
        print("ws close from: " .. tostring(id), code, reason)
        client_fd_map[id] = nil
    end
    function handle.error(id)
        print("ws error from: " .. tostring(id))
        client_fd_map[id] = nil
    end


    -- local grid_handle
    -- local view
    -- local all_nodes = {}

    function handle.message(id, msg, msg_type)
        assert(msg_type == "binary" or msg_type == "text")
        -- websocket.write(id, msg)
        -- print("str = ", msg)
        assert(client_fd_map[id])
        local info = decode(msg)
        if info then
            if info.type == "create" then
                if not(client_fd_map[id].grid_handle) then
                    client_fd_map[id].grid_handle = Grid.new({
                        cell_w = info.cell_w,
                        cell_h = info.cell_h,
                        l = 0, t = 0,
                        r = info.w, b = info.h,
                    })
                end
                print("create map")
            elseif info.type == "add" then
                assert(client_fd_map[id].grid_handle)
                client_fd_map[id].grid_handle:insert(info.id, info.x, info.y)
                print("add node", info.id, info.x, info.y)
                if not(client_fd_map[id].all_nodes) then
                    client_fd_map[id].all_nodes = {}
                end
                client_fd_map[id].all_nodes[info.id] = { x = info.x, y = info.y }
            elseif info.type == "del" then
                assert(client_fd_map[id].grid_handle)
                client_fd_map[id].grid_handle:remove(info.id, info.x, info.y)
                print("del node", info.id, info.x, info.y)
                if not(client_fd_map[id].all_nodes) then
                    client_fd_map[id].all_nodes = {}
                end
                client_fd_map[id].all_nodes[info.id] = nil
            elseif info.type == "move" then
                assert(client_fd_map[id].grid_handle)
                client_fd_map[id].grid_handle:move(info.id, info.ox, info.oy, info.x, info.y)
                print("move node", info.id, info.ox, info.oy, info.x, info.y)
                if not(client_fd_map[id].all_nodes) then
                    client_fd_map[id].all_nodes = {}
                end
                client_fd_map[id].all_nodes[info.id] = { x = info.x, y = info.y }
            elseif info.type == "view" then
                assert(client_fd_map[id].grid_handle)
                client_fd_map[id].view = {
                    x = info.x,
                    y = info.y,
                    w = info.w,
                    h = info.h,
                }
                print("set view = ", info.x, info.y, info.w, info.h)
            end
        else
            print("error msg", msg, msg_type)
        end
    end

    local function cmp_snapshot(old, new)
        local add, move, del = {}, {}, {}
        local all = {}
        for k in pairs(old) do
            all[k] = true
        end
        for k in pairs(new) do
            all[k] = true
        end
        for k in pairs(all) do
            local m1 = old[k]
            local m2 = new[k]
            if not m1 and m2 then
                add[#add+1] = {
                    id = k,
                    x = m2.x,
                    y = m2.y,
                }
            end
            if m1 and m2 and (m1.x ~= m2.x or m1.y ~= m2.y) then
                move[#move+1] = {
                    id = k,
                    x1 = m1.x,
                    y1 = m1.y,
                    x2 = m2.x,
                    y2 = m2.y,
                }
            end
            if m1 and not m2 then
                del[#del+1] = {
                    id = k,
                    x = m1.x,
                    y = m1.y,
                }
            end
        end
        return add, move, del
    end
    function timer(interval)
        skynet.timeout(interval, function()   
            for fd, v in pairs(client_fd_map) do
                if v.grid_handle and v.view then
                    local cur = v.grid_handle:query(v.view.x, v.view.y, v.view.w, v.view.h)
                    local new_snapshot = {}
                    for _, id in pairs(cur) do
                        new_snapshot[id] = {
                            x = v.all_nodes[id].x,
                            y = v.all_nodes[id].y,
                        }
                    end
                    local add, move, del = cmp_snapshot(v.snapshot or {}, new_snapshot)
                    v.snapshot = new_snapshot
                    if #add > 0 or #move > 0 or #del > 0 then
                        websocket.write(fd, encode({
                            add = add,
                            move = move,
                            del = del,
                        }))
                    end
                end
            end
            timer(interval)
        end)
    end
    skynet.start(function ()
        skynet.dispatch("lua", function(_, _, id, protocol, addr)
            local ok, err = websocket.accept(id, handle, protocol, addr)
            if not ok then
                print(err)
            end
        end)
        timer(10) -- 100ms 的定时器
    end)
else
    skynet.start(function ()
        local agent = skynet.newservice("aoi_test", "agent")
        local protocol = "ws"
        local id = socket.listen("0.0.0.0", 33302)
        skynet.error(string.format("Listen websocket port 33302 protocol:%s", protocol))
        socket.start(id, function(id, addr)
            print(string.format("accept client socket_id: %s addr:%s", id, addr))
            skynet.send(agent, "lua", id, protocol, addr)
        end)
    end)
end
