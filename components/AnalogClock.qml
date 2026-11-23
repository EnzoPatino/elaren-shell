pragma ComponentBehavior: Bound
import QtQuick
import "../theme"

// Esfera analógica: marcas de las horas, agujas y segundero con "tic" de
// cuarzo. No lleva reloj propio: recibe `now`, así quien la usa decide la
// precisión (sin segundero alcanza con un SystemClock por minuto, y la
// esfera se redibuja una vez por minuto).
// La usan el reloj de escritorio y la pantalla de bloqueo de Hyprland.
Item {
    id: root

    property date now: new Date()
    property bool showSeconds: true
    property color faceColor: Qt.alpha(Theme.surface, 0.55)
    property color accent: Theme.primary
    // Escala de animación: la del tema, o la de la persona (bloqueo).
    property real animScale: Theme.anim.scale

    readonly property real size: Math.min(width, height)

    // Ángulo acumulado: el segundero no "rebobina" al pasar de 59 a 0.
    property real secondAngle: 0
    property int lastSecond: -1

    function update(): void {
        const s = now.getSeconds();
        if (lastSecond < 0) secondAngle = s * 6;
        else secondAngle += ((s - lastSecond + 60) % 60) * 6;
        lastSecond = s;
    }
    onNowChanged: update()
    Component.onCompleted: update()

    // Aguja: un Item del tamaño de la esfera que gira sobre su centro.
    component Hand: Item {
        property real angle: 0
        property real length: 60
        property real thickness: 4
        property color handColor: Theme.text

        anchors.fill: parent
        rotation: angle

        Rectangle {
            x: parent.width / 2 - width / 2
            y: parent.height / 2 - parent.length
            width: parent.thickness
            height: parent.length + parent.thickness * 1.7
            radius: width / 2
            color: parent.handColor
        }
    }

    Rectangle {
        id: dial
        anchors.centerIn: parent
        width: root.size
        height: root.size
        radius: width / 2
        color: root.faceColor
        border.width: Math.max(1, root.size / 105)
        border.color: Qt.alpha(root.accent, 0.35)

        // Marcas de las horas
        Repeater {
            model: 12

            Item {
                required property int index
                anchors.fill: parent
                rotation: index * 30

                Rectangle {
                    readonly property bool major: parent.index % 3 === 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.size * 0.048
                    width: Math.max(1, root.size * (major ? 0.019 : 0.0095))
                    height: root.size * (major ? 0.076 : 0.043)
                    radius: width / 2
                    color: major ? root.accent : Qt.alpha(Theme.text, 0.5)
                }
            }
        }

        Hand {
            thickness: root.size * 0.033
            length: root.size * 0.26
            angle: (root.now.getHours() % 12) * 30 + root.now.getMinutes() * 0.5
        }
        Hand {
            thickness: root.size * 0.024
            length: root.size * 0.37
            angle: root.now.getMinutes() * 6 + (root.showSeconds ? root.now.getSeconds() * 0.1 : 0)
        }
        Hand {
            visible: root.showSeconds
            thickness: Math.max(1, root.size * 0.0095)
            length: root.size * 0.41
            handColor: root.accent
            angle: root.secondAngle

            // Tic de cuarzo: pequeño rebote al avanzar
            Behavior on angle { NumberAnimation { duration: 220 * root.animScale; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
        }

        Rectangle {
            anchors.centerIn: parent
            width: root.size * 0.057
            height: width
            radius: width / 2
            color: root.accent
            border.width: Math.max(1, root.size / 105)
            border.color: Theme.surface
        }
    }
}
