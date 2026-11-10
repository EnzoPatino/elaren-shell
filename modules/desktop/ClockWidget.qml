pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../theme"
import "../../config"
import "../../components"
import "../../services"

// Reloj de escritorio. Estilos (Config.widgetClockStyle):
//   "digital" — hora grande con dígitos que ruedan + fecha
//   "analog"  — agujas con segundero de "tic" elástico
//   "words"   — la hora en palabras ("Son las diez y cuarto")
DesktopWidget {
    id: root

    key: "Clock"

    readonly property string style: Config.widgetClockStyle
    readonly property bool needSeconds: style === "analog" || (style === "digital" && Config.widgetClockSeconds)

    SystemClock {
        id: clock
        precision: root.needSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    readonly property date now: clock.date

    function capitalize(s: string): string {
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    // ── Hora en palabras (español rioplatense) ────────────────────────────
    readonly property var words: {
        const names = ["doce", "una", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve", "diez", "once"];
        const h = now.getHours();
        const m = Math.round(now.getMinutes() / 5) * 5;
        let hour = h % 12;
        let middle;
        if (m === 0 || m === 60) {
            if (m === 60) hour = (hour + 1) % 12;
            middle = `${names[hour]} en punto`;
        } else if (m <= 30) {
            const parts = { 5: "y cinco", 10: "y diez", 15: "y cuarto", 20: "y veinte", 25: "y veinticinco", 30: "y media" };
            middle = `${names[hour]} ${parts[m]}`;
        } else {
            hour = (hour + 1) % 12;
            const parts = { 35: "menos veinticinco", 40: "menos veinte", 45: "menos cuarto", 50: "menos diez", 55: "menos cinco" };
            middle = `${names[hour]} ${parts[m]}`;
        }
        const effectiveHour = m > 30 ? (h + 1) % 24 : h;
        const period = effectiveHour < 6 ? "de la madrugada" : effectiveHour < 13 ? "de la mañana" : effectiveHour < 20 ? "de la tarde" : "de la noche";
        return { prefix: hour === 1 ? "Es la" : "Son las", middle, period };
    }

    // Aguja: un Item del tamaño del dial que gira sobre su centro.
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
            height: parent.length + 12
            radius: width / 2
            color: parent.handColor
        }
    }

    Loader {
        sourceComponent: root.style === "analog" ? analog : root.style === "words" ? wordsView : digital
    }

    // ── Digital ───────────────────────────────────────────────────────────
    Component {
        id: digital

        Column {
            spacing: 2

            Row {
                spacing: 4

                RollingText {
                    text: Qt.formatTime(root.now, "HH:mm")
                    color: Theme.text
                    font.family: Theme.font.family
                    font.pixelSize: 96
                    font.weight: Font.Bold
                    font.features: { "tnum": 1 }
                }

                RollingText {
                    visible: Config.widgetClockSeconds
                    anchors.baseline: parent.children[0].bottom
                    anchors.baselineOffset: -18
                    text: Qt.formatTime(root.now, "ss")
                    color: Theme.primary
                    font.family: Theme.font.family
                    font.pixelSize: 32
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
            }

            StyledText {
                leftPadding: 6
                text: root.capitalize(Qt.locale().toString(root.now, "dddd d MMMM"))
                color: Theme.primary
                font.pixelSize: 22
                font.weight: Font.DemiBold
                animate: true
            }
        }
    }

    // ── Analógico ─────────────────────────────────────────────────────────
    Component {
        id: analog

        Item {
            id: face

            readonly property real size: 210
            // Ángulos acumulados: el segundero no "rebobina" al pasar de 59 a 0.
            property real secondAngle: 0
            property int lastSecond: -1

            implicitWidth: size
            implicitHeight: size + 34

            function update(): void {
                const s = root.now.getSeconds();
                if (lastSecond < 0) secondAngle = s * 6;
                else secondAngle += ((s - lastSecond + 60) % 60) * 6;
                lastSecond = s;
            }
            Component.onCompleted: update()
            Connections {
                target: root
                function onNowChanged() { face.update(); }
            }

            Rectangle {
                id: dial
                width: face.size
                height: face.size
                radius: width / 2
                color: Qt.alpha(Theme.surface, root.card ? 0.4 : 0.55)
                border.width: 2
                border.color: Qt.alpha(Theme.primary, 0.35)

                // Marcas de las horas
                Repeater {
                    model: 12

                    Item {
                        required property int index
                        anchors.fill: parent
                        rotation: index * 30

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 10
                            width: parent.index % 3 === 0 ? 4 : 2
                            height: parent.index % 3 === 0 ? 16 : 9
                            radius: 2
                            color: parent.index % 3 === 0 ? Theme.primary : Qt.alpha(Theme.text, 0.5)
                        }
                    }
                }

                Hand {
                    thickness: 7
                    length: face.size * 0.26
                    handColor: Theme.text
                    angle: (root.now.getHours() % 12) * 30 + root.now.getMinutes() * 0.5
                }
                Hand {
                    thickness: 5
                    length: face.size * 0.37
                    handColor: Theme.text
                    angle: root.now.getMinutes() * 6 + root.now.getSeconds() * 0.1
                }
                Hand {
                    id: secondHand
                    thickness: 2
                    length: face.size * 0.41
                    handColor: Theme.primary
                    angle: face.secondAngle

                    // Tic de cuarzo: pequeño rebote al avanzar
                    Behavior on angle { NumberAnimation { duration: 220 * Theme.anim.scale; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 12
                    height: 12
                    radius: 6
                    color: Theme.primary
                    border.width: 2
                    border.color: Theme.surface
                }
            }

            StyledText {
                anchors.top: dial.bottom
                anchors.topMargin: 10
                anchors.horizontalCenter: dial.horizontalCenter
                text: root.capitalize(Qt.locale().toString(root.now, "ddd d MMM"))
                color: Theme.primary
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }
        }
    }

    // ── En palabras ───────────────────────────────────────────────────────
    Component {
        id: wordsView

        Column {
            spacing: 0

            StyledText {
                text: root.words.prefix
                color: Theme.textMuted
                font.pixelSize: 30
                font.weight: Font.Medium
                animate: true
            }
            StyledText {
                text: root.words.middle
                color: Theme.primary
                font.pixelSize: 58
                font.weight: Font.Bold
                animate: true
            }
            StyledText {
                text: root.words.period
                color: Theme.text
                font.pixelSize: 30
                font.weight: Font.Medium
                animate: true
            }
        }
    }
}
