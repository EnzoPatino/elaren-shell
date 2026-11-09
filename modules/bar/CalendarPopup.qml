pragma ComponentBehavior: Bound
import QtQuick
import "../../theme"
import "../../components"
import "../../services"

// Calendario desplegable bajo el reloj. Se abre con rebote, cambia de mes
// deslizando la cuadrícula y se cierra solo al sacar el ratón.
AnimatedPopup {
    id: root

    property int monthOffset: 0
    property int slideDirection: 1

    readonly property date today: Time.date
    readonly property date viewDate: new Date(today.getFullYear(), today.getMonth() + monthOffset, 1)

    cardWidth: 276

    onOpenChanged: if (open) monthOffset = 0

    function changeMonth(step: int): void {
        slideDirection = step;
        monthOffset += step;
        slide.restart();
    }

    Column {
        id: column

        width: parent.width
        spacing: Theme.spacing.normal

        // Cabecera: mes y flechas
        Item {
            width: parent.width
            height: 32

            StyledText {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacing.small
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    const s = Qt.formatDate(root.viewDate, "MMMM yyyy");
                    return s.charAt(0).toUpperCase() + s.slice(1);
                }
                font.pixelSize: Theme.font.large
                font.weight: Font.DemiBold
                animate: true
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacing.small

                Repeater {
                    model: [{ icon: "chevron_left", step: -1 }, { icon: "chevron_right", step: 1 }]

                    Rectangle {
                        id: arrow
                        required property var modelData
                        width: 28
                        height: 28
                        radius: Theme.radius.full
                        color: "transparent"

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: arrow.modelData.icon
                            animateChange: false
                            color: Theme.textMuted
                        }

                        StateLayer { onClicked: root.changeMonth(arrow.modelData.step) }
                    }
                }
            }
        }

        // Nombres de los días según el idioma del sistema (lunes primero)
        Row {
            Repeater {
                model: [1, 2, 3, 4, 5, 6, 0].map(d => Qt.locale().dayName(d, Locale.NarrowFormat).toUpperCase())

                StyledText {
                    required property string modelData
                    width: column.width / 7
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Theme.textMuted
                    font.pixelSize: Theme.font.small
                    font.weight: Font.DemiBold
                }
            }
        }

        // Cuadrícula de 6 semanas
        Item {
            width: parent.width
            height: grid.height
            clip: true

            Grid {
                id: grid

                readonly property date firstCell: {
                    const first = root.viewDate;
                    const weekday = (first.getDay() + 6) % 7; // lunes = 0
                    return new Date(first.getFullYear(), first.getMonth(), 1 - weekday);
                }

                columns: 7

                Repeater {
                    model: 42

                    Item {
                        id: day

                        required property int index
                        readonly property date date: new Date(grid.firstCell.getFullYear(), grid.firstCell.getMonth(), grid.firstCell.getDate() + index)
                        readonly property bool inMonth: date.getMonth() === root.viewDate.getMonth()
                        readonly property bool isToday: date.toDateString() === root.today.toDateString()

                        width: column.width / 7
                        height: 32

                        Rectangle {
                            anchors.centerIn: parent
                            width: 30
                            height: 30
                            radius: Theme.radius.full
                            color: day.isToday ? Theme.primary : "transparent"

                            StyledText {
                                anchors.centerIn: parent
                                text: day.date.getDate()
                                font.weight: day.isToday ? Font.Bold : Font.Normal
                                color: day.isToday ? Theme.textOnPrimary : day.inMonth ? Theme.text : Theme.outline
                            }

                            StateLayer { cursorShape: Qt.ArrowCursor }
                        }
                    }
                }
            }
        }

        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: {
                const s = Time.longDate;
                return s.charAt(0).toUpperCase() + s.slice(1);
            }
            color: Theme.textMuted
            font.pixelSize: Theme.font.small
        }
    }

    WheelHandler {
        onWheel: event => root.changeMonth(event.angleDelta.y > 0 ? -1 : 1)
    }

    ParallelAnimation {
        id: slide
        Anim { target: grid; property: "x"; from: 40 * root.slideDirection; to: 0; duration: Theme.anim.slow; easing.bezierCurve: Theme.anim.expressive }
        Anim { target: grid; property: "opacity"; from: 0; to: 1 }
    }
}
