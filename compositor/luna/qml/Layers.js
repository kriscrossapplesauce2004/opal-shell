.pragma library

// Layer-shell arrangement: place each surface by anchors (top 1, bottom 2, left 4, right 8) and margins; return the work area.
var TOP = 1, BOTTOM = 2, LEFT = 4, RIGHT = 8

// Returns { places: [{x, y, width, height}], usable: {x, y, width, height} } for entries [{ layer, desired, ... }].
function arrange(entries, out) {
    var usable = { x: out.x, y: out.y, width: out.width, height: out.height }
    var places = []
    // Surfaces with an exclusive zone go first, so the zones exist before the other surfaces are placed.
    var order = entries.map(function (e, i) { return i })
    order.sort(function (a, b) { return (entries[b].exclusiveZone > 0) - (entries[a].exclusiveZone > 0) })
    order.forEach(function (i) {
        var e = entries[i]
        var area = e.exclusiveZone === -1 ? out : usable
        var ax = area.x + e.leftMargin, ay = area.y + e.topMargin
        var aw = Math.max(0, area.width - e.leftMargin - e.rightMargin)
        var ah = Math.max(0, area.height - e.topMargin - e.bottomMargin)
        var w = e.desiredWidth, h = e.desiredHeight
        var a = e.anchor
        var x, y
        if ((a & LEFT) && (a & RIGHT)) { x = ax; w = aw }
        else if (a & LEFT) x = ax
        else if (a & RIGHT) x = ax + aw - w
        else x = ax + (aw - w) / 2
        if ((a & TOP) && (a & BOTTOM)) { y = ay; h = ah }
        else if (a & TOP) y = ay
        else if (a & BOTTOM) y = ay + ah - h
        else y = ay + (ah - h) / 2
        places[i] = { x: x, y: y, width: w, height: h }

        if (e.exclusiveZone > 0) {
            var z = e.exclusiveZone
            var edge = exclusiveEdge(a)
            if (edge === TOP) { var t = e.topMargin + z; usable.y += t; usable.height -= t }
            else if (edge === BOTTOM) usable.height -= e.bottomMargin + z
            else if (edge === LEFT) { var l = e.leftMargin + z; usable.x += l; usable.width -= l }
            else if (edge === RIGHT) usable.width -= e.rightMargin + z
        }
    })
    usable.width = Math.max(0, usable.width)
    usable.height = Math.max(0, usable.height)
    return { places: places, usable: usable }
}

// The edge an exclusive zone applies to: one anchored edge, or the edge of a bar anchored to three sides.
function exclusiveEdge(a) {
    var sides = [TOP, BOTTOM, LEFT, RIGHT].filter(function (s) { return a & s })
    if (sides.length === 1)
        return sides[0]
    if (sides.length === 3) {
        if (!(a & BOTTOM)) return TOP
        if (!(a & TOP)) return BOTTOM
        if (!(a & RIGHT)) return LEFT
        return RIGHT
    }
    return 0
}
