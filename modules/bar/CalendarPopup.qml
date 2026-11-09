pragma ComponentBehavior: Bound
import QtQuick
import "../../theme"
import "../../components"
import "../../services"

// Calendario desplegable bajo el reloj.
//
// - Encabezado con el día de hoy; flechas o rueda para cambiar de mes (la
//   cuadrícula se desliza en esa dirección) y "Hoy" para volver.
// - Clic en un día lo selecciona: un anillo se desliza hasta él y el pie
//   cuenta cuánto falta o cuánto pasó.
// - Números de semana, fines de semana en otro tono y avance del año.
AnimatedPopup {
    id: root

    property int monthOffset: 0
    property int slideDirection: 1
    property date selected: today

    readonly property date today: Time.date
    readonly property date viewDate: new Date(today.getFullYear(), today.getMonth() + monthOffset, 1)
    readonly property real cellWidth: (column.width - weekColumn) / 7
    readonly property int cellHeight: 36
    readonly property int weekColumn: 26

    cardWidth: 340
    padding: 20

    onOpenChanged: {
        if (open) {
            monthOffset = 0;
            selected = today;
        }
    }

    function changeMonth(step: int): void {
        slideDirection = step;
        monthOffset += step;
        slide.restart();
    }

    function goToday(): void {
        if (monthOffset !== 0) changeMonth(-monthOffset);
        selected = today;
    }

    function sameDay(a: date, b: date): bool {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    function capitalize(s: string): string {
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    // Semana ISO 8601
    function isoWeek(d: date): int {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        const day = t.getUTCDay() || 7;
        t.setUTCDate(t.getUTCDate() + 4 - day);
        const yearStart = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
        return Math.ceil(((t - yearStart) / 86400000 + 1) / 7);
    }

    function daysBetween(a: date, b: date): int {
        const ua = Date.UTC(a.getFullYear(), a.getMonth(), a.getDate());
        const ub = Date.UTC(b.getFullYear(), b.getMonth(), b.getDate());
        return Math.round((ub - ua) / 86400000);
    }

    function relative(d: date): string {
        const n = daysBetween(today, d);
        if (n === 0) return "Hoy";
        if (n === 1) return "Mañana";
        if (n === -1) return "Ayer";
        return n > 0 ? `Faltan ${n} días` : `Hace ${-n} días`;
    }

    readonly property int dayOfYear: daysBetween(new Date(today.getFullYear(), 0, 1), today) + 1
    readonly property int daysInYear: daysBetween(new Date(today.getFullYear(), 0, 1), new Date(today.getFullYear() + 1, 0, 1))

    // Resplandor de color en la esquina superior: da profundidad a la tarjeta.
    decoration: Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(Theme.primary, 0.13) }
            GradientStop { position: 0.35; color: "transparent" }
        }
    }

    Column {
        id: column

        width: parent.width
        spacing: 14

        // ── Encabezado ────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: heading.height

            Column {
                id: heading
                spacing: 2

                StyledText {
                    text: root.capitalize(Qt.locale().dayName(root.today.getDay())).toUpperCase()
                    color: Theme.primary
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.letterSpacing: 1.6
                }

                Row {
                    spacing: 8

                    StyledText {
                        anchors.baseline: monthLabel.baseline
                        text: root.today.getDate()
                        font.pixelSize: 34
                        font.weight: Font.Bold
                    }

                    StyledText {
                        id: monthLabel
                        text: root.capitalize(Qt.locale().monthName(root.today.getMonth()))
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                        color: Qt.alpha(Theme.text, 0.85)
                    }
                }
            }

            // Navegación
            Row {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: 4

                NavButton {
                    icon: "chevron_left"
                    onClicked: root.changeMonth(-1)
                }

                // "Hoy": solo cuando no se está viendo el mes actual o el día elegido no es hoy
                Rectangle {
                    id: todayButton
                    readonly property bool needed: root.monthOffset !== 0 || !root.sameDay(root.selected, root.today)

                    anchors.verticalCenter: parent.verticalCenter
                    width: needed ? todayLabel.implicitWidth + 18 : 0
                    height: 28
                    radius: 14
                    color: Qt.alpha(Theme.primary, 0.16)
                    opacity: needed ? 1 : 0
                    clip: true

                    Behavior on width { Anim { easing.bezierCurve: Theme.anim.expressive } }
                    Behavior on opacity { Anim { duration: Theme.anim.fast } }

                    StyledText {
                        id: todayLabel
                        anchors.centerIn: parent
                        text: "Hoy"
                        color: Theme.primary
                        font.pixelSize: Theme.font.small
                        font.weight: Font.Bold
                    }

                    StateLayer {
                        radius: 14
                        color: Theme.primary
                        onClicked: root.goToday()
                    }
                }

                NavButton {
                    icon: "chevron_right"
                    onClicked: root.changeMonth(1)
                }
            }
        }

        // Mes que se está viendo
        Item {
            width: parent.width
            height: viewMonth.height
            clip: true

            StyledText {
                id: viewMonth
                text: root.capitalize(Qt.formatDate(root.viewDate, "MMMM yyyy"))
                color: Theme.textMuted
                font.pixelSize: Theme.font.small + 1
                font.weight: Font.DemiBold
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.alpha(Theme.text, 0.08)
        }

        // ── Días de la semana ─────────────────────────────────────────────
        Row {
            Item { width: root.weekColumn; height: 1 }

            Repeater {
                model: [1, 2, 3, 4, 5, 6, 0]

                StyledText {
                    required property int modelData
                    required property int index
                    width: root.cellWidth
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.locale().dayName(modelData, Locale.ShortFormat).slice(0, 2)
                    color: index >= 5 ? Qt.alpha(Theme.secondary, 0.8) : Theme.textMuted
                    font.pixelSize: Theme.font.small
                    font.weight: Font.Bold
                }
            }
        }

        // ── Cuadrícula ────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: root.cellHeight * 6
            clip: true

            Item {
                id: grid

                readonly property date firstCell: {
                    const first = root.viewDate;
                    const weekday = (first.getDay() + 6) % 7; // lunes = 0
                    return new Date(first.getFullYear(), first.getMonth(), 1 - weekday);
                }

                width: parent.width
                height: parent.height

                // Números de semana
                Column {
                    Repeater {
                        model: 6

                        StyledText {
                            required property int index
                            width: root.weekColumn
                            height: root.cellHeight
                            horizontalAlignment: Text.AlignLeft
                            text: root.isoWeek(new Date(grid.firstCell.getFullYear(), grid.firstCell.getMonth(), grid.firstCell.getDate() + index * 7))
                            color: Qt.alpha(Theme.textMuted, 0.5)
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            font.features: { "tnum": 1 }
                        }
                    }
                }

                // Anillo de selección: se desliza hasta el día elegido
                Rectangle {
                    id: selection

                    readonly property int cellIndex: root.daysBetween(grid.firstCell, root.selected)
                    readonly property bool inView: cellIndex >= 0 && cellIndex < 42

                    x: root.weekColumn + (cellIndex % 7) * root.cellWidth + (root.cellWidth - width) / 2
                    y: Math.floor(cellIndex / 7) * root.cellHeight + (root.cellHeight - height) / 2
                    width: 32
                    height: 32
                    radius: 16
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.primary
                    opacity: inView && !root.sameDay(root.selected, root.today) ? 1 : 0
                    scale: opacity > 0.5 ? 1 : 0.6

                    Behavior on x { Anim { easing.bezierCurve: Theme.anim.expressive } }
                    Behavior on y { Anim { easing.bezierCurve: Theme.anim.expressive } }
                    Behavior on opacity { Anim { duration: Theme.anim.fast } }
                    Behavior on scale { Anim { easing.bezierCurve: Theme.anim.expressiveFast } }
                }

                Grid {
                    x: root.weekColumn
                    columns: 7

                    Repeater {
                        model: 42

                        Item {
                            id: day

                            required property int index
                            readonly property date date: new Date(grid.firstCell.getFullYear(), grid.firstCell.getMonth(), grid.firstCell.getDate() + index)
                            readonly property bool inMonth: date.getMonth() === root.viewDate.getMonth()
                            readonly property bool isToday: root.sameDay(date, root.today)
                            readonly property bool weekend: index % 7 >= 5

                            width: root.cellWidth
                            height: root.cellHeight

                            // Hoy: círculo de acento con halo que respira
                            Rectangle {
                                visible: day.isToday
                                anchors.centerIn: parent
                                width: 40
                                height: 40
                                radius: 20
                                color: Qt.alpha(Theme.primary, 0.18)

                                SequentialAnimation on scale {
                                    running: day.isToday && root.visible && Theme.anim.scale > 0
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 0.8; to: 1; duration: 1400; easing.type: Easing.InOutSine }
                                    NumberAnimation { from: 1; to: 0.8; duration: 1400; easing.type: Easing.InOutSine }
                                }
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: 32
                                height: 32
                                radius: 16
                                color: day.isToday ? Theme.primary : "transparent"
                                gradient: day.isToday ? todayGradient : null

                                Gradient {
                                    id: todayGradient
                                    GradientStop { position: 0; color: Qt.lighter(Theme.primary, 1.12) }
                                    GradientStop { position: 1; color: Theme.primary }
                                }

                                StyledText {
                                    anchors.centerIn: parent
                                    text: day.date.getDate()
                                    font.weight: day.isToday ? Font.Bold : day.inMonth ? Font.Medium : Font.Normal
                                    font.features: { "tnum": 1 }
                                    color: day.isToday ? Theme.textOnPrimary
                                        : !day.inMonth ? Qt.alpha(Theme.textMuted, 0.35)
                                        : day.weekend ? Qt.alpha(Theme.secondary, 0.9)
                                        : Theme.text
                                }

                                StateLayer {
                                    radius: 16
                                    onClicked: {
                                        root.selected = day.date;
                                        if (!day.inMonth) root.changeMonth(day.index < 7 ? -1 : 1);
                                    }
                                }
                            }

                            // Puntito bajo hoy
                            Rectangle {
                                visible: day.isToday
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: -1
                                width: 4
                                height: 4
                                radius: 2
                                color: Theme.primary
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.alpha(Theme.text, 0.08)
        }

        // ── Pie: día elegido + avance del año ─────────────────────────────
        Item {
            width: parent.width
            height: 40

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                StyledText {
                    text: root.relative(root.selected)
                    font.weight: Font.Bold
                    color: root.sameDay(root.selected, root.today) ? Theme.primary : Theme.text
                    animate: true
                }
                StyledText {
                    text: root.capitalize(Qt.locale().toString(root.selected, "dddd d MMMM yyyy"))
                    color: Theme.textMuted
                    font.pixelSize: Theme.font.small
                    animate: true
                }
            }

            Column {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                StyledText {
                    anchors.right: parent.right
                    text: `Día ${root.dayOfYear} de ${root.daysInYear}`
                    color: Theme.textMuted
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    font.features: { "tnum": 1 }
                }

                Rectangle {
                    anchors.right: parent.right
                    width: 96
                    height: 4
                    radius: 2
                    color: Qt.alpha(Theme.text, 0.1)

                    Rectangle {
                        width: parent.width * root.dayOfYear / root.daysInYear * (root.visible ? 1 : 0)
                        height: parent.height
                        radius: 2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Theme.secondary }
                            GradientStop { position: 1; color: Theme.primary }
                        }

                        Behavior on width { Anim { duration: Theme.anim.extraSlow; easing.bezierCurve: Theme.anim.emphasizedDecel } }
                    }
                }
            }
        }
    }

    WheelHandler {
        onWheel: event => root.changeMonth(event.angleDelta.y > 0 ? -1 : 1)
    }

    ParallelAnimation {
        id: slide
        Anim { target: grid; property: "x"; from: 50 * root.slideDirection; to: 0; duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.expressive }
        Anim { target: grid; property: "opacity"; from: 0; to: 1 }
        Anim { target: viewMonth; property: "y"; from: 14 * root.slideDirection; to: 0; duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.expressive }
        Anim { target: viewMonth; property: "opacity"; from: 0; to: 1 }
    }

    component NavButton: Rectangle {
        id: nav

        property string icon
        signal clicked()

        width: 28
        height: 28
        radius: 14
        color: Qt.alpha(Theme.text, 0.05)

        MaterialIcon {
            anchors.centerIn: parent
            text: nav.icon
            color: Theme.text
            animateChange: false
        }

        StateLayer {
            radius: 14
            onClicked: nav.clicked()
        }
    }
}
