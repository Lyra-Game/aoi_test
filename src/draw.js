export const draw_grid = (ctx, gw, gh, mw, mh, color) => {
    ctx.save()
    ctx.beginPath()
    // 创建垂直格网线路径
    for (let i = gw; i < mw; i += gw) {
        ctx.moveTo(i, 0)
        ctx.lineTo(i, mh)
    }
    // 创建水平格网线路径
    for (let j = gh; j < mh; j += gh){
        ctx.moveTo(0, j)
        ctx.lineTo(mw, j)
    }
    ctx.strokeStyle = color
    ctx.stroke()
    ctx.restore()
}

export const draw_circle = (ctx, x, y, r, color, hover, id) => {
    ctx.save()
    ctx.beginPath()
    ctx.arc(x, y, r, 0, 2 * Math.PI)
    if (hover) {
        ctx.strokeStyle = "blue"
    } else {
        ctx.strokeStyle = color
    }
    ctx.stroke()
    ctx.strokeRect(x, y, 1, 1)
    ctx.fillText(id, x - r/2 , y + r/3)
    ctx.restore()
}

export const draw_bg = (ctx, w, h, color) => {
    ctx.save()
    ctx.strokeStyle = color
    ctx.strokeRect(0, 0, w, h)
    ctx.restore()
}

export const draw_view = (ctx, x, y, w, h, color) => {
    ctx.save()
    ctx.strokeStyle = color
    ctx.strokeRect(x, y, w, h)
    ctx.restore()
}
