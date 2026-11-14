//@ pragma UseQApplication
pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import "modules/background"
import "modules/bar"
import "modules/desktop"
import "modules/dock"
import "modules/launcher"
import "modules/power"
import "modules/settings"
import "config"
import "services"

// Elaren — punto de entrada. Fondo, barra y dock en cada pantalla.
ShellRoot {
    // Un único lanzador; el compositor lo abre en la pantalla enfocada.
    LauncherWindow {}

    // Panel de Configuración (engranaje del lanzador o clic derecho en "Apps")
    SettingsWindow {}

    Variants {
        model: Quickshell.screens

        Scope {
            id: perScreen

            required property var modelData

            // Widgets de escritorio en cada pantalla conectada. Comparten
            // las posiciones relativas guardadas en Configuración → Widgets.
            DesktopWidgets {
                screen: perScreen.modelData
            }

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

            // La barra se dibuja a pantalla completa (para que la isla crezca
            // libre); BarReserve es la que reserva su lugar a las ventanas.
            BarReserve {
                screen: perScreen.modelData
            }

            Bar {
                screen: perScreen.modelData
            }

            // Animaciones de bloquear / suspender / salir / reiniciar / apagar
            PowerOverlay {
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
