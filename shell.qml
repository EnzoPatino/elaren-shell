//@ pragma UseQApplication
pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import "modules/background"
import "modules/bar"
import "modules/dock"
import "config"
import "services"

// Elaren — punto de entrada. Fondo, barra y dock en cada pantalla.
ShellRoot {
    Variants {
        model: Quickshell.screens

        Scope {
            id: perScreen

            required property var modelData

            LazyLoader {
                active: Wallpaper.drawsOwn

                Background {
                    screen: perScreen.modelData
                }
            }

            Bar {
                screen: perScreen.modelData
            }

            LazyLoader {
                active: Config.dockEnabled

                Dock {
                    screen: perScreen.modelData
                }
            }
        }
    }
}
