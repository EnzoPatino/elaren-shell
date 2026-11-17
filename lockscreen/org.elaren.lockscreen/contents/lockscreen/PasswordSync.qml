pragma Singleton

import QtQuick

// Con varias pantallas, cada una tiene su propia vista: esto mantiene la
// misma contraseña escrita en todas.
QtObject {
    property string password
}
