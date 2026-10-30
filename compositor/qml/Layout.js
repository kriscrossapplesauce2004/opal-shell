.pragma library

// Master-stack tiling: the first client takes the left side, the rest stack on the right.
function tile(count, area) {
    var gap = 8
    var rects = []
    if (count <= 0)
        return rects
    var x0 = area.x + gap
    var y0 = area.y + gap
    var w = Math.max(0, area.width - 2 * gap)
    var h = Math.max(0, area.height - 2 * gap)
    if (count === 1) {
        rects.push({ x: x0, y: y0, width: w, height: h })
        return rects
    }
    var masterW = Math.round((w - gap) * 0.55)
    var stackN = count - 1
    var stackW = w - masterW - gap
    var cellH = (h - gap * (stackN - 1)) / stackN
    rects.push({ x: x0, y: y0, width: masterW, height: h })
    for (var i = 0; i < stackN; ++i)
        rects.push({ x: x0 + masterW + gap, y: y0 + i * (cellH + gap), width: stackW, height: cellH })
    return rects
}
