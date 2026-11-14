pragma ComponentBehavior: Bound
import QtQuick
import "../../theme"
import "../../components"
import "../../services"

// Calendario: vista "Calendario" de la isla de la barra.
//
// - A la izquierda, el día de hoy en grande con la semana, el avance del año
//   y cuánto falta (o pasó) para el día elegido.
// - A la derecha, el mes: días redondos, hoy relleno con el acento y el día
//   elegido con un anillo. Flechas o rueda para cambiar de mes (la cuadrícula
//   se desliza en esa dirección); "Hoy" vuelve.
InlineCard {
    id: root

    property int monthOffset: 0
    property int slideDirection: 1
    property date selected: today

    readonly property date today: Time.date
    readonly property date viewDate: new Date(today.getFullYear(), today.getMonth() + monthOffset, 1)
    readonly property int cell: 38

    cardWidth: 600
    padding: 18

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

    // Los 42 días que se muestran (6 semanas, empezando el lunes).
    readonly property var days: {
        const first = viewDate;
        const lead = (first.getDay() + 6) % 7;
        const out = [];
        for (let i = 0; i < 42; i++)
            out.push(new Date(first.getFullYear(), first.getMonth(), 1 - lead + i));
        return out;
    }

    Row {
        width: parent.width
        spacing: 18

        // ── Hoy ───────────────────────────────────────────────────────────
        Rectangle {
            id: hero

            width: 190
            height: month.height
            radius: Theme.radius.large
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(Theme.primary, 0.22) }
                GradientStop { position: 1; color: Qt.alpha(Theme.secondary, 0.08) }
            }
            border.width: 1
            border.color: Qt.alpha(Theme.primary, 0.25)

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 18
                spacing: 0

                StyledText {
                    text: Qt.formatDate(root.today, "dddd").toUpperCase()
                    color: Theme.primary
                    font.pixelSize: Theme.font.small
                    font.weight: Font.Bold
                    font.letterSpacing: 1.6
                }

                StyledText {
                    text: root.today.getDate()
                    font.pixelSize: 72
                    font.weight: Font.Bold
                    font.features: { "tnum": 1 }
                    lineHeight: 0.95
                }

                StyledText {
                    text: root.capitalize(Qt.formatDate(root.today, "MMMM yyyy"))
                    color: Theme.text
                    font.pixelSize: Theme.font.large
                    font.weight: Font.Medium
                }

                StyledText {
                    topPadding: 2
                    text: "Semana " + root.isoWeek(root.today)
                    color: Theme.textMuted
                    font.pixelSize: Theme.font.small + 1
                }
            }

            // Avance del año y día elegido, al pie.
            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 18
                spacing: 6

                Rectangle {
                    width: parent.width
                    height: 34
                    radius: Theme.radius.normal
                    color: Qt.alpha(Theme.text, 0.06)

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "event"
                            font.pixelSize: 15
                            color: Theme.primary
                            animateChange: false
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.sameDay(root.selected, root.today)
                                ? "Hoy"
                                : Qt.formatDate(root.selected, "d MMM") + " · " + root.relative(root.selected)
                            font.pixelSize: Theme.font.small + 1
                            font.weight: Font.DemiBold
                            animate: true
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 14

                    StyledText {
                        text: "Año"
                        color: Theme.textMuted
                        font.pixelSize: Theme.font.small
                    }

                    StyledText {
                        anchors.right: parent.right
                        text: `Día ${root.dayOfYear} · ${Math.round(root.yearProgress * 100)} %`
                        color: Theme.textMuted
                        font.pixelSize: Theme.font.small
                        font.features: { "tnum": 1 }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Qt.alpha(Theme.text, 0.08)

                    Rectangle {
                        width: parent.width * (root.visible ? root.yearProgress : 0)
                        height: parent.height
                        radius: 3
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Theme.primary }
                            GradientStop { position: 1; color: Theme.secondary }
                        }

                        Behavior on width { Anim { duration: Theme.anim.extraSlow; easing.bezierCurve: Theme.anim.emphasizedDecel } }
                    }
                }
            }
        }

        // ── Mes ───────────────────────────────────────────────────────────
        Column {
            id: month

            width: parent.width - hero.width - parent.spacing
            spacing: 10

            // Encabezado: mes y navegación
            Item {
                width: parent.width
                height: 32

                Item {
                    id: monthShift
                    width: viewMonth.width
                    height: parent.height

                    StyledText {
                        id: viewMonth
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.capitalize(Qt.formatDate(root.viewDate, "MMMM")) + " "
                        font.pixelSize: Theme.font.large + 3
                        font.weight: Font.Bold

                        StyledText {
                            anchors.left: parent.right
                            anchors.baseline: parent.baseline
                            text: Qt.formatDate(root.viewDate, "yyyy")
                            color: Theme.textMuted
                            font.pixelSize: Theme.font.large + 3
                            font.weight: Font.Medium
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    NavButton {
                        icon: "chevron_left"
                        onClicked: root.changeMonth(-1)
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: todayLabel.implicitWidth + 20
                        height: 28
                        radius: 14
                        visible: root.monthOffset !== 0 || !root.sameDay(root.selected, root.today)
                        color: Qt.alpha(Theme.primary, 0.18)

                        StyledText {
                            id: todayLabel
                            anchors.centerIn: parent
                            text: "Hoy"
                            color: Theme.primary
                            font.weight: Font.DemiBold
                        }

                        StateLayer {
                            radius: 14
                            onClicked: root.goToday()
                        }
                    }

                    NavButton {
                        icon: "chevron_right"
                        onClicked: root.changeMonth(1)
                    }
                }
            }

            // Días de la semana
            Row {
                anchors.horizontalCenter: parent.horizontalCenter

                Repeater {
                    model: ["L", "M", "M", "J", "V", "S", "D"]

                    StyledText {
                        required property string modelData
                        required property int index
                        width: (month.width) / 7
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: index >= 5 ? Qt.alpha(Theme.secondary, 0.8) : Theme.textMuted
                        font.pixelSize: Theme.font.small
                        font.weight: Font.Bold
                    }
                }
            }

            // Cuadrícula
            Item {
                width: parent.width
                height: 6 * root.cell
                clip: true

                Grid {
                    id: grid
                    columns: 7

                    Repeater {
                        model: root.days

                        Item {
                            id: day

                            required property var modelData
                            required property int index
                            readonly property bool inMonth: modelData.getMonth() === root.viewDate.getMonth()
                            readonly property bool isToday: root.sameDay(modelData, root.today)
                            readonly property bool isSelected: root.sameDay(modelData, root.selected)
                            readonly property bool weekend: index % 7 >= 5

                            width: month.width / 7
                            height: root.cell

                            Rectangle {
                                anchors.centerIn: parent
                                width: root.cell - 4
                                height: width
                                radius: width / 2
                                color: day.isToday ? Theme.primary
                                    : touch.containsMouse ? Qt.alpha(Theme.text, 0.08)
                                    : "transparent"
                                border.width: day.isSelected && !day.isToday ? 2 : 0
                                border.color: Theme.primary
                                scale: touch.pressed ? 0.88 : 1

                                Behavior on color { CAnim { duration: Theme.anim.fast } }
                                Behavior on scale { Anim { duration: Theme.anim.fast; easing.bezierCurve: Theme.anim.expressiveFast } }

                                StyledText {
                                    anchors.centerIn: parent
                                    text: day.modelData.getDate()
                                    color: day.isToday ? Theme.textOnPrimary
                                        : !day.inMonth ? Qt.alpha(Theme.textMuted, 0.4)
                                        : day.weekend ? Qt.alpha(Theme.secondary, 0.9)
                                        : Theme.text
                                    font.weight: day.isToday || day.isSelected ? Font.Bold : Font.Medium
                                    font.features: { "tnum": 1 }
                                }
                            }

                            StateLayer {
                                id: touch
                                radius: Theme.radius.full
                                color: "transparent"
                                onClicked: {
                                    root.selected = day.modelData;
                                    if (!day.inMonth) root.changeMonth(day.modelData < root.viewDate ? -1 : 1);
                                }
                            }
                        }
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

        anchors.verticalCenter: parent?.verticalCenter
        width: 28
        height: 28
        radius: 14
        color: Qt.alpha(Theme.text, 0.06)

        MaterialIcon {
            anchors.centerIn: parent
            text: nav.icon
            font.pixelSize: 18
            color: Theme.text
            animateChange: false
        }

        StateLayer {
            radius: 14
            onClicked: nav.clicked()
        }
    }
}
