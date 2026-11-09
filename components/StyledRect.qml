import QtQuick

// Rectangle cuyo color cambia con transición.
Rectangle {
    color: "transparent"

    Behavior on color { CAnim {} }
}
