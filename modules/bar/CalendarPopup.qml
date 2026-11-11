pragma ComponentBehavior: Bound
import QtQuick
import "../../theme"
import "../../components"
import "../../services"

// Calendario desplegable bajo el reloj.
//
// - Encabezado con una "hoja" de calendario (día de hoy) y el resumen de la
//   semana y el año.
// - Barra de mes: flechas o rueda para cambiar de mes (la cuadrícula se
//   desliza en esa dirección) y "Hoy" para volver.
// - Clic en un día lo selecciona: el marco se desliza hasta él y el pie
//   cuenta cuánto falta o cuánto pasó.
// - Números de semana, fines de semana sombreados y anillo de avance del año.
AnimatedPopup {
    id: root

    property int monthOffset: 0
    property int slideDirection: 1
    property date selected: today

    readonly property date today: Time.date
    readonly property date viewDate: new Date(today.getFullYear(), today.getMonth() + monthOffset, 1)
    readonly property int weekColumn: 24
    readonly property int cellHeight: 36
    readonly property real cellWidth: (gridPanel.width - gridPanel.inset * 2 - weekColumn) / 7

    cardWidth: 348
    padding: 18

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
    readonly property real yearProgress: dayOfYear / daysInYear

    // Resplandor de acento en la esquina superior izquierda: profundidad.
    decoration: [
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(Theme.primary, 0.16) }
                GradientStop { position: 0.3; color: Qt.alpha(Theme.primary, 0.03) }
                GradientStop { position: 0.6; color: "transparent" }
            }
        },
        Rectangle {
            x: -width * 0.35
            y: -height * 0.45
            width: 220
            height: 220
            radius: 110
            color: Qt.alpha(Theme.secondary, 0.07)
        }
    ]

    Column {
        id: column

        width: parent.width
        spacing: 14

        // ── Encabezado ────────────────────────────────────────────────────
        Row {
            width: parent.width
            spacing: 14

            // Hoja de calendario con el día de hoy
            Rectangle {
                id: sheet

                width: 58
                height: 62
                radius: 16
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.lighter(Theme.primary, 1.1) }
                    GradientStop { position: 1; color: Qt.darker(Theme.primary, 1.15) }
                }

                // Brillo superior, como el filo de una hoja
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: parent.radius - 1
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.alpha("white", 0.18)
                }

                Column {
                    anchors.centerIn: parent
                    spacing: -2

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.locale().dayName(root.today.getDay(), Locale.ShortFormat).replace(".", "").toUpperCase()
                        color: Qt.alpha(Theme.textOnPrimary, 0.75)
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 1.4
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.today.getDate()
                        color: Theme.textOnPrimary
                        font.pixelSize: 28
                        font.weight: Font.Bold
                        font.features: { "tnum": 1 }
                    }
                }
            }

            Column {
                anchors.verticalCenter: sheet.verticalCenter
                width: parent.width - sheet.width - parent.spacing
                spacing: 3

                StyledText {
                    text: root.capitalize(Qt.locale().dayName(root.today.getDay()))
                    font.pixelSize: 19
                    font.weight: Font.Bold
                }

                StyledText {
                    text: `${root.today.getDate()} de ${Qt.locale().monthName(root.today.getMonth())} de ${root.today.getFullYear()}`
                    color: Qt.alpha(Theme.text, 0.72)
                    font.weight: Font.Medium
                }

                Row {
                    spacing: 6

                    Chip { text: `Semana ${root.isoWeek(root.today)}` }
                    Chip { text: `Día ${root.dayOfYear}` }
                }
            }
        }

        // ── Barra de mes ──────────────────────────────────────────────────
        Rectangle {
            width: parent.width
            height: 38
            radius: 19
            color: Qt.alpha(Theme.text, 0.045)
            border.width: 1
            border.color: Qt.alpha(Theme.text, 0.05)

            NavButton {
                id: prevButton
                anchors.left: parent.left
                anchors.leftMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                icon: "chevron_left"
                onClicked: root.changeMonth(-1)
            }

            // Mes que se está viendo
            Item {
                anchors.left: prevButton.right
                anchors.right: todayButton.left
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                height: parent.height
                clip: true

                StyledText {
                    id: viewMonth
                    anchors.verticalCenter: parent.verticalCenter
                    transform: Translate { id: monthShift }
                    text: root.capitalize(Qt.locale().monthName(root.viewDate.getMonth()))
                    font.pixelSize: Theme.font.large
                    font.weight: Font.Bold

                    StyledText {
                        anchors.left: parent.right
                        anchors.leftMargin: 6
                        anchors.baseline: parent.baseline
                        text: root.viewDate.getFullYear()
                        color: root.viewDate.getFullYear() === root.today.getFullYear() ? Theme.textMuted : Theme.primary
                        font.pixelSize: Theme.font.normal
                        font.weight: Font.Medium
                        font.features: { "tnum": 1 }
                    }
                }
            }

            // "Hoy": solo cuando no se está viendo el mes actual o el día elegido no es hoy
            Rectangle {
                id: todayButton
                readonly property bool needed: root.monthOffset !== 0 || !root.sameDay(root.selected, root.today)

                anchors.right: nextButton.left
                anchors.rightMargin: needed ? 4 : 0
                anchors.verticalCenter: parent.verticalCenter
                width: needed ? todayRow.implicitWidth + 18 : 0
                height: 28
                radius: 14
                color: Qt.alpha(Theme.primary, 0.18)
                opacity: needed ? 1 : 0
                clip: true

                Behavior on width { Anim { easing.bezierCurve: Theme.anim.expressive } }
                Behavior on opacity { Anim { duration: Theme.anim.fast } }

                Row {
                    id: todayRow
                    anchors.centerIn: parent
                    spacing: 4

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "today"
                        font.pixelSize: 14
                        color: Theme.primary
                        animateChange: false
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Hoy"
                        color: Theme.primary
                        font.pixelSize: Theme.font.small
                        font.weight: Font.Bold
                    }
                }

                StateLayer {
                    radius: 14
                    color: Theme.primary
                    onClicked: root.goToday()
                }
            }

            NavButton {
                id: nextButton
                anchors.right: parent.right
                anchors.rightMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                icon: "chevron_right"
                onClicked: root.changeMonth(1)
            }
        }

        // ── Cuadrícula ────────────────────────────────────────────────────
        Rectangle {
            id: gridPanel

            readonly property int inset: 6

            width: parent.width
            height: inset * 2 + dayNames.height + 4 + root.cellHeight * 6
            radius: Theme.radius.large + 2
            color: Qt.alpha(Theme.text, 0.03)
            border.width: 1
            border.color: Qt.alpha(Theme.text, 0.045)

            // Columnas del fin de semana sombreadas
            Rectangle {
                x: gridPanel.inset + root.weekColumn + root.cellWidth * 5 + 2
                y: gridPanel.inset
                width: root.cellWidth * 2 - 4
                height: parent.height - gridPanel.inset * 2
                radius: Theme.radius.normal + 2
                color: Qt.alpha(Theme.secondary, 0.055)
            }

            // Días de la semana
            Row {
                id: dayNames
                x: gridPanel.inset
                y: gridPanel.inset + 4
                height: 18

                StyledText {
                    width: root.weekColumn
                    height: parent.height
                    horizontalAlignment: Text.AlignHCenter
                    text: "#"
                    color: Qt.alpha(Theme.textMuted, 0.45)
                    font.pixelSize: 10
                    font.weight: Font.Bold
                }

                Repeater {
                    model: [1, 2, 3, 4, 5, 6, 0]

                    StyledText {
                        required property int modelData
                        required property int index
                        width: root.cellWidth
                        height: dayNames.height
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.locale().dayName(modelData, Locale.ShortFormat).replace(".", "").slice(0, 2).toUpperCase()
                        color: index >= 5 ? Theme.secondary : Theme.textMuted
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 0.8
                    }
                }
            }

            Item {
                x: gridPanel.inset
                y: dayNames.y + dayNames.height + 2
                width: parent.width - gridPanel.inset * 2
                height: root.cellHeight * 6
                clip: true

                Item {
                    id: grid

                    readonly property date firstCell: {
                        const first = root.viewDate;
                        const weekday = (first.getDay() + 6) % 7; // lunes = 0
                        return new Date(first.getFullYear(), first.getMonth(), 1 - weekday);
                    }
                    readonly property int todayIndex: root.daysBetween(firstCell, root.today)

                    width: parent.width
                    height: parent.height

                    // Fila de la semana actual, apenas resaltada
                    Rectangle {
                        visible: grid.todayIndex >= 0 && grid.todayIndex < 42
                        x: 0
                        y: Math.floor(grid.todayIndex / 7) * root.cellHeight + 2
                        width: parent.width
                        height: root.cellHeight - 4
                        radius: Theme.radius.normal + 2
                        color: Qt.alpha(Theme.primary, 0.06)
                    }

                    // Números de semana
                    Column {
                        Repeater {
                            model: 6

                            StyledText {
                                required property int index
                                width: root.weekColumn
                                height: root.cellHeight
                                horizontalAlignment: Text.AlignHCenter
                                text: root.isoWeek(new Date(grid.firstCell.getFullYear(), grid.firstCell.getMonth(), grid.firstCell.getDate() + index * 7))
                                color: Qt.alpha(Theme.textMuted, 0.45)
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                font.features: { "tnum": 1 }
                            }
                        }
                    }

                    // Marco de selección: se desliza hasta el día elegido
                    Rectangle {
                        id: selection

                        readonly property int cellIndex: root.daysBetween(grid.firstCell, root.selected)
                        readonly property bool inView: cellIndex >= 0 && cellIndex < 42

                        x: root.weekColumn + (cellIndex % 7) * root.cellWidth + (root.cellWidth - width) / 2
                        y: Math.floor(cellIndex / 7) * root.cellHeight + (root.cellHeight - height) / 2
                        width: Math.min(36, root.cellWidth - 4)
                        height: 30
                        radius: 10
                        color: Qt.alpha(Theme.primary, 0.14)
                        border.width: 1.5
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
                                readonly property bool isToday: index === grid.todayIndex
                                readonly property bool weekend: index % 7 >= 5

                                width: root.cellWidth
                                height: root.cellHeight

                                // Hoy: halo suave fijo (sin animación continua)
                                Rectangle {
                                    visible: day.isToday
                                    anchors.centerIn: parent
                                    width: cell.width + 8
                                    height: cell.height + 8
                                    radius: 14
                                    color: Qt.alpha(Theme.primary, 0.2)
                                }

                                Rectangle {
                                    id: cell

                                    anchors.centerIn: parent
                                    width: Math.min(36, root.cellWidth - 4)
                                    height: 30
                                    radius: 10
                                    color: "transparent"
                                    gradient: day.isToday ? todayGradient : null

                                    Gradient {
                                        id: todayGradient
                                        GradientStop { position: 0; color: Qt.lighter(Theme.primary, 1.15) }
                                        GradientStop { position: 1; color: Theme.primary }
                                    }

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: day.date.getDate()
                                        font.weight: day.isToday ? Font.Bold : day.inMonth ? Font.Medium : Font.Normal
                                        font.features: { "tnum": 1 }
                                        color: day.isToday ? Theme.textOnPrimary
                                            : !day.inMonth ? Qt.alpha(Theme.textMuted, 0.3)
                                            : day.weekend ? Theme.secondary
                                            : Theme.text
                                    }

                                    StateLayer {
                                        radius: 10
                                        color: day.isToday ? Theme.textOnPrimary : Theme.text
                                        onClicked: {
                                            root.selected = day.date;
                                            if (!day.inMonth) root.changeMonth(day.index < 7 ? -1 : 1);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Pie: día elegido + avance del año ─────────────────────────────
        Item {
            width: parent.width
            height: 44

            Rectangle {
                id: footIcon
                anchors.verticalCenter: parent.verticalCenter
                width: 38
                height: 38
                radius: 12
                color: Qt.alpha(Theme.primary, 0.15)

                MaterialIcon {
                    anchors.centerIn: parent
                    text: root.sameDay(root.selected, root.today) ? "event_available"
                        : root.daysBetween(root.today, root.selected) > 0 ? "event_upcoming" : "history"
                    color: Theme.primary
                    font.pixelSize: 19
                }
            }

            Column {
                anchors.left: footIcon.right
                anchors.leftMargin: 10
                anchors.right: yearRing.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                StyledText {
                    text: root.relative(root.selected)
                    font.weight: Font.Bold
                    color: root.sameDay(root.selected, root.today) ? Theme.primary : Theme.text
                    animate: true
                }
                StyledText {
                    width: parent.width
                    text: root.capitalize(Qt.locale().toString(root.selected, "dddd d 'de' MMMM yyyy"))
                    color: Theme.textMuted
                    font.pixelSize: Theme.font.small
                    elide: Text.ElideRight
                    animate: true
                }
            }

            // Avance del año
            Ring {
                id: yearRing
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 42
                height: 42
                thickness: 3.5
                value: root.visible ? root.yearProgress : 0
                color: Theme.primary
                trackColor: Qt.alpha(Theme.text, 0.1)

                Column {
                    anchors.centerIn: parent
                    spacing: -3

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Math.round(root.yearProgress * 100) + "%"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.features: { "tnum": 1 }
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.today.getFullYear()
                        color: Theme.textMuted
                        font.pixelSize: 7
                        font.weight: Font.Medium
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
        Anim { target: grid; property: "x"; from: 40 * root.slideDirection; to: 0; duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.expressive }
        Anim { target: grid; property: "opacity"; from: 0; to: 1 }
        Anim { target: monthShift; property: "x"; from: 24 * root.slideDirection; to: 0; duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.expressive }
        Anim { target: viewMonth; property: "opacity"; from: 0; to: 1 }
    }

    component NavButton: Rectangle {
        id: nav

        property string icon
        signal clicked()

        width: 28
        height: 28
        radius: 14
        color: Qt.alpha(Theme.text, 0.06)

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

    component Chip: Rectangle {
        id: chip

        property alias text: chipLabel.text

        width: chipLabel.implicitWidth + 14
        height: 20
        radius: 10
        color: Qt.alpha(Theme.text, 0.06)

        StyledText {
            id: chipLabel
            anchors.centerIn: parent
            color: Theme.textMuted
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
    }
}
