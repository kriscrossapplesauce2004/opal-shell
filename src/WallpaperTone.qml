import QtQuick

// Brightness of the wallpaper, as a small grid. Desktop text asks it whether the area behind it is light, so the text can be dark there.
Canvas {
    id: tone
    property string source: ""
    property string fit: "crop"
    property real dim: 0
    // The size of the surface that the wallpaper fills, in the same units that callers use.
    property real areaWidth: 1920
    property real areaHeight: 1080
    // Luminance from 0 to 1 per grid cell, row by row. Empty means unknown: callers treat it as dark.
    property var grid: []
    readonly property int cols: 64
    readonly property int rows: Math.max(1, Math.round(cols * areaHeight / Math.max(1, areaWidth)))
    visible: false
    width: cols; height: rows
    renderStrategy: Canvas.Immediate
    onSourceChanged: { grid = []; if (source) loadImage(source); }
    onImageLoaded: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onFitChanged: requestPaint()
    onPaint: {
        const c = getContext("2d");
        c.reset();
        if (!source || !isImageLoaded(source)) { grid = []; return; }
        const img = c.createImageData(source);
        const iw = img.width, ih = img.height;
        if (!iw || !ih) return;
        // Draw like the wallpaper: crop fills the area, fit shows the whole image on the base colour.
        c.fillStyle = String(Theme.base);
        c.fillRect(0, 0, width, height);
        const s = fit === "fit" ? Math.min(width / iw, height / ih) : Math.max(width / iw, height / ih);
        c.drawImage(source, (width - iw * s) / 2, (height - ih * s) / 2, iw * s, ih * s);
        const data = c.getImageData(0, 0, width, height).data;
        const out = new Array(width * height);
        for (let i = 0; i < out.length; i++) {
            const r = data[i * 4] / 255, g = data[i * 4 + 1] / 255, b = data[i * 4 + 2] / 255;
            out[i] = (0.2126 * r + 0.7152 * g + 0.0722 * b) * (1 - dim);
        }
        grid = out;
    }
    // Mean luminance under a rectangle given in area units. Returns -1 when the wallpaper is unknown.
    function lumAt(x, y, w, h) {
        if (!grid.length) return -1;
        const x0 = Math.max(0, Math.floor(x / areaWidth * cols)), x1 = Math.min(cols - 1, Math.floor((x + w) / areaWidth * cols));
        const y0 = Math.max(0, Math.floor(y / areaHeight * rows)), y1 = Math.min(rows - 1, Math.floor((y + h) / areaHeight * rows));
        let sum = 0, n = 0;
        for (let yy = y0; yy <= y1; yy++) for (let xx = x0; xx <= x1; xx++) { sum += grid[yy * cols + xx]; n++; }
        return n ? sum / n : -1;
    }
    // True when dark text reads better than white text on that rectangle.
    function lightAt(x, y, w, h) { return lumAt(x, y, w, h) > .58; }
}
