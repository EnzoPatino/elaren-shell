//@ pragma UseQApplication
pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import "modules/background"
import "modules/bar"
import "modules/desktop"
import "modules/dock"
import "modules/launcher"
import "modules/settings"
import "config"
import "services"

// Elaren — punto de entrada. Fondo, barra y dock en cada pantalla.
ShellRoot {
    // Un único lanzador; el compositor lo abre en la pantalla enfocada.
    LauncherWindow {}

    // Panel de Configuración (engranaje del lanzador o clic derecho en "Apps")
    SettingsWindow {}

    // Widgets de escritorio (reloj, saludo, música, sistema, clima) en la
    // pantalla principal. Se activan en Configuración → Widgets.
    DesktopWidgets {
        screen: Quickshell.screens[0]
    }

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

            // Barras/ondas sobre el fondo mientras suena música
            LazyLoader {
                active: Config.visualizerEnabled

                AudioVisualizer {
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
