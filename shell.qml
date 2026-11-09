//@ pragma UseQApplication
import Quickshell
import QtQuick
import "modules/bar"

// Elaren — punto de entrada. Una barra por pantalla.
ShellRoot {
    Variants {
        model: Quickshell.screens
        Bar {
            required property var modelData
            screen: modelData
        }
    }
}
