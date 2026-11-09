import QtQuick
import "../theme"

// Gráfico de área con el historial de un valor. Cada muestra nueva entra
// deslizándose desde la derecha en vez de saltar.
Item {
    id: root

    property list<real> values: []
    property list<real> secondaryValues: []   // opcional (p. ej. subida de red)
    property real maximum: 1                  // 0 = escala automática
    property int capacity: 60
    property color color: Theme.primary
    property color secondaryColor: Theme.secondary

    readonly property real scaleMax: {
        if (maximum > 0) return maximum;
        const all = [...values, ...secondaryValues];
        return Math.max(1, ...all) * 1.15;
    }

    // 1 → 0 tras cada muestra: desplaza el dibujo un paso hacia la izquierda.
    property real shift: 0
    onValuesChanged: {
        shiftAnim.restart();
        canvas.requestPaint();
    }
    onScaleMaxChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()

    NumberAnimation {
        id: shiftAnim
        target: root
        property: "shift"
        from: 1
        to: 0
        duration: Theme.anim.scale > 0 ? 600 : 0
        easing.type: Easing.OutCubic
    }
    onShiftChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative

        function series(ctx, data, color, fill) {
            if (data.length < 2) return;
            const step = width / (root.capacity - 1);
            const offset = width - (data.length - 1) * step + root.shift * step;
            const y = v => height - Math.min(1, v / root.scaleMax) * (height - 2) - 1;

            ctx.beginPath();
            ctx.moveTo(offset, y(data[0]));
            for (let i = 1; i < data.length; i++) {
                const x0 = offset + (i - 1) * step;
                const x1 = offset + i * step;
                const xm = (x0 + x1) / 2;
                ctx.bezierCurveTo(xm, y(data[i - 1]), xm, y(data[i]), x1, y(data[i]));
            }
            ctx.strokeStyle = color;
            ctx.lineWidth = 1.6;
            ctx.stroke();

            if (fill) {
                ctx.lineTo(offset + (data.length - 1) * step, height);
                ctx.lineTo(offset, height);
                ctx.closePath();
                const gradient = ctx.createLinearGradient(0, 0, 0, height);
                gradient.addColorStop(0, Qt.alpha(color, 0.35));
                gradient.addColorStop(1, Qt.alpha(color, 0.02));
                ctx.fillStyle = gradient;
                ctx.fill();
            }
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            series(ctx, root.secondaryValues, root.secondaryColor, false);
            series(ctx, root.values, root.color, true);
        }
    }
}
