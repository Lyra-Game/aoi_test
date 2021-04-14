import "./css/index.css"
import { draw_grid, draw_circle, draw_bg, draw_view } from "./draw"

// Prepare canvas
const canvas = document.getElementById('scene')
const ctx = canvas.getContext('2d')
const xOffset = 50
const yOffset = 50
ctx.translate(xOffset, yOffset)

const w = 800
const h = 800
const cell_w = 40
const cell_h = 40

const ws = new WebSocket('ws://localhost:33302')
ws.onopen = () => {
    console.log('connect success!')
    ws.send(JSON.stringify({
        type: "create",
        w: w,
        h: h,
        cell_w: cell_w,
        cell_h: cell_h,
    }))
}
ws.onmessage = (message) => {
    // ws.send('收到' + message.data)
    let data = JSON.parse(message.data)
    console.log("移动列表：", data.move)
    console.log("添加列表：", data.add)
    console.log("删除列表：", data.del)
}


let mouse_type = undefined
let nodes_id = 0
let node_r = 10
let nodes = []
let dirty = true
let mouse_hover = -1
let move_old_pos = undefined
let move_target = -1
let view = undefined

const show_title = () => {
    switch (mouse_type) {
        case "add":
            return '状态：添加实体'
            break
        case "del":
            return '状态：删除实体'
            break
        case "move":
            return '状态：移动实体'
            break
        case "view":
            return '状态：设置视野'
            break
        default:
            return '状态：空'
    }
}

const add_li = (text) => {
    let ul = document.getElementById("log")
    let li = document.createElement("li")
    li.innerHTML = text
    ul.appendChild(li)
}

const draw_node = () => {
    if (!dirty) {
        return
    }
    ctx.clearRect(-xOffset, -yOffset, canvas.width, canvas.height)
    draw_bg(ctx, w, h, "black")
    draw_grid(ctx, cell_w, cell_h, w, h, "black")
    nodes.forEach((node, i) => {
        draw_circle(ctx, node.x, node.y, node.r, node.color, mouse_hover == i, node.id)
    })
    if (view != undefined) {
        draw_view(ctx, view.x, view.y, view.w, view.h, "green")
    }
    dirty = false
}

const check_in_node = (node, x, y) => {
    return Math.pow(x - node.x, 2) + Math.pow(y - node.y, 2) < Math.pow(node.r, 2)
}

const check_hover = (x, y) => {
    let old_hover = mouse_hover
    mouse_hover = -1
    for (let i = nodes.length - 1; i >= 0; i--) {
        if (check_in_node(nodes[i], x, y)) {
            mouse_hover = i
            break
        }
    }
    if (old_hover != mouse_hover) {
        dirty = true
        draw_node()
    }
}

canvas.addEventListener('click', function(e) {
    let x = e.layerX - xOffset
    let y = e.layerY - yOffset
    if (x >= 0 && x < w && y >= 0 && y < h) {
        switch(mouse_type) {
            case "add":
                nodes_id++
                nodes.push({
                    id: nodes_id,
                    x : x,
                    y : y,
                    r : node_r,
                    color: 'red',
                })
                ws.send(JSON.stringify({
                    type: "add",
                    id: nodes_id,
                    x: x,
                    y: y,
                }))
                mouse_hover = nodes.length - 1
                dirty = true
                let text = `添加新实体：${nodes_id}<${x},${y}>`
                document.getElementById('tools_info').innerHTML = text
                add_li("<font color='red'>" + text + "</font>")
                break
            case "del":
                for (let i = nodes.length - 1; i >= 0; i--) {
                    if (check_in_node(nodes[i], x, y)) {
                        ws.send(JSON.stringify({
                            type: "del",
                            id: nodes[i].id,
                            x: nodes[i].x,
                            y: nodes[i].y,
                        }))
                        let text = `删除实体：${nodes[i].id}<${nodes[i].x},${nodes[i].y}>`
                        document.getElementById('tools_info').innerHTML = text
                        add_li("<font color='blue'>" + text + "</font>")
                        nodes.splice(i, 1)
                        break
                    }
                }
                mouse_hover = -1
                dirty = true
                check_hover(x, y)
                break
        }
    }
})

canvas.addEventListener('mousedown', function(e) {
    let x = e.layerX - xOffset
    let y = e.layerY - yOffset
    if (x >= 0 && x < w && y >= 0 && y < h) {
        switch(mouse_type) {
            case "move":
                for (let i = nodes.length - 1; i >= 0; i--) {
                    if (check_in_node(nodes[i], x, y)) {
                        move_target = i
                        move_old_pos = [nodes[i].x, nodes[i].y]
                        document.getElementById('tools_info').innerHTML = `选中移动：${nodes[i].id}<${nodes[i].x},${nodes[i].y}>`
                        break
                    }
                }
                break
            case "view":
                view = {
                    x: x,
                    y: y,
                    w: 0,
                    h: 0,
                    draw: true,
                }
                dirty = true
                draw_node()
                document.getElementById('tools_info').innerHTML = `视野：左上角<${view.x},${view.y}><宽:${view.w},高:${view.h}>`
                break
        }
    }
})

canvas.addEventListener('mouseup', function(e) {
    if (move_target != -1 && mouse_type == "move") {
        add_li(`<font color='mediumvioletred'>移动实体：old<${move_old_pos[0]},${move_old_pos[1]}> new<${nodes[move_target].x},${nodes[move_target].y}>`)
        move_target = -1
    }
    if (view != undefined && mouse_type == "view") {
        view.draw = false
        let text = `<font color='green'>创建视野：左上角<${view.x},${view.y}><宽:${view.w},高:${view.h}></font>`
        add_li(text)
        document.getElementById('view_size').innerText = `视野：左上角<${view.x},${view.y}><宽:${view.w},高:${view.h}>`
    }
})

canvas.addEventListener('mousemove', function(e) {
    let x = e.layerX - xOffset
    let y = e.layerY - yOffset
    if (x >= 0 && x < w && y >= 0 && y < h) {
        document.getElementById('tools_title').innerText = show_title() + ` <x:${x},y:${y}>`
        check_hover(x, y)
        switch(mouse_type) {
            case "move":
                if (move_target != -1) {
                     ws.send(JSON.stringify({
                        type: "move",
                        id: nodes[move_target].id,
                        ox: nodes[move_target].x,
                        oy: nodes[move_target].y,
                        x: x,
                        y: y,
                    }))
                    nodes[move_target].x = x
                    nodes[move_target].y = y
                    document.getElementById('tools_info').innerHTML = `选中移动：${nodes[move_target].id}<${x},${y}>`
                    dirty = true
                    draw_node()
                }
                break
            case "view":
                if (view != undefined && view.draw) {
                    view.w = x - view.x
                    view.h = y - view.y
                    ws.send(JSON.stringify({
                        type: "view",
                        x: view.x + view.w / 2,
                        y: view.y + view.h / 2,
                        w: view.w,
                        h: view.h,
                    }))
                    dirty = true
                    draw_node()
                    document.getElementById('tools_info').innerHTML = `视野：左上角<${view.x},${view.y}><宽:${view.w},高:${view.h}>`
                }
                break
        }
    } else {
        document.getElementById('tools_title').innerText = show_title()
        if (move_target != -1 && mouse_type == "move") {
            add_li(`<font color='mediumvioletred'>移动实体：old<${move_old_pos[0]},${move_old_pos[1]}> new<${nodes[move_target].x},${nodes[move_target].y}>`)
            move_target = -1
        }
    }
})

let last_tick = performance.now()
const run = (frame) => {
    requestAnimationFrame(run)
    let next_tick = last_tick + 50
    if (frame > next_tick) {
        draw_node()
        last_tick = next_tick
    }
}
run(performance.now())

document.getElementById('add').addEventListener('click', function() {
    console.log("add")
    mouse_type = "add"
    document.getElementById('tools_title').innerText = show_title()
})

document.getElementById('view').addEventListener('click', function() {
    console.log("view")
    mouse_type = "view"
    document.getElementById('tools_title').innerText = show_title()
})

document.getElementById('del').addEventListener('click', function() {
    console.log("del")
    mouse_type = "del"
    document.getElementById('tools_title').innerText = show_title()
})

document.getElementById('move').addEventListener('click', function() {
    console.log("move")
    mouse_type = "move"
    document.getElementById('tools_title').innerText = show_title()
})


