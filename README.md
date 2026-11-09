# Elaren

Shell de escritorio para **KDE Plasma 6** (Wayland) escrita en QML con
[Quickshell](https://quickshell.org).

## Desarrollo

```bash
./scripts/run.sh    # arranca la shell; se recarga sola al guardar
./scripts/lint.sh   # qmllint sobre todos los .qml
```

`ELAREN_ANIM_SCALE` ajusta la velocidad de las animaciones
(`0` las desactiva, `2` las hace el doble de lentas):

```bash
ELAREN_ANIM_SCALE=2 ./scripts/run.sh
```

## La barra

| Zona      | Módulo                | Interacción                                              |
|-----------|-----------------------|----------------------------------------------------------|
| Izquierda | Apps                  | Clic: abre el lanzador de aplicaciones                   |
|           | Ventana activa        | Icono y título de la ventana enfocada                    |
|           | Escritorios virtuales | Clic: cambiar · Rueda: siguiente/anterior                |
| Centro    | Reloj                 | Clic: calendario (rueda: cambiar de mes)                 |
| Derecha   | Sistema               | Hover: red · Clic: panel con gráficos de CPU/RAM/red, GPU, swap |
|           | Multimedia (MPRIS)    | Hover: controles anterior / pausa / siguiente            |
|           | Bandeja del sistema   | Clic: activar · Derecho: menú · Medio: acción secundaria |
|           | Volumen y batería     | Rueda: ±5 % · Clic en icono: silenciar · Arrastrar: fijar|

## Lanzador de aplicaciones

Panel a pantalla completa con buscador, secciones (Todas, Frecuentes, Juegos,
Internet, Multimedia, Gráficos, Desarrollo, Oficina, Sistema, Utilidades) y
botones de bloquear / salir / reiniciar / apagar (los tres últimos piden
confirmación con un segundo clic).

- Escribí para buscar (nombre, descripción, palabras clave, o letras sueltas
  en orden: "ffx" → Firefox). Las apps que más abrís suben en el ranking.
- Flechas para moverse, Enter abre, Tab / Shift+Tab cambia de sección,
  Esc borra la búsqueda o cierra.
- Para abrirlo con un atajo, en Preferencias del sistema → Atajos → Añadir
  comando, usá:
  `qs ipc -p ~/proyectos/elaren-shell/shell.qml call launcher toggle`

Los iconos se resuelven a archivos con `scripts/icon-resolver.py` según el tema
de iconos de KDE (el proveedor `image://icon` de Quickshell dejaba iconos
invisibles en algunas ventanas).

## Fondo y dock

- **Fondo**: Elaren dibuja el wallpaper (sin `plasmashell` nadie lo hace).
  Usa el que tengas configurado en Plasma y lo sigue si lo cambiás; se puede
  forzar otro con `ELAREN_WALLPAPER=/ruta/imagen.jpg`.
- **skwd-wall**: si su daemon (`skwd-walld`) está activo, `scripts/run.sh` lo
  pasa a modo standalone (`SKWD_PLASMA_BACKEND=0`) mientras Elaren corre, así
  dibuja el fondo con skwd-paper (videos, escenas de Wallpaper Engine) en vez
  de mandarlo al plugin de Plasma, que sin `plasmashell` no existe. Elaren lo
  detecta y no dibuja su propio fondo. Al salir se restaura. Se controla con
  `ELAREN_SKWD_STANDALONE=0` y `ELAREN_WALLPAPER_PROVIDER=auto|elaren|skwd`.
- **Dock**: apps fijadas + apps abiertas. Clic abre / alterna / rota entre
  ventanas; clic medio abre otra instancia. Se esconde solo y aparece al tocar
  el borde inferior o si el escritorio está vacío.

Las preferencias (apps fijadas, autoocultar, tamaño de iconos, paralaje) están
en `config/Config.qml`.

## Integración con KWin

KWin no ofrece la lista de ventanas ni los escritorios por protocolos Wayland
que Quickshell entienda (`ext-workspace`, `foreign-toplevel`). Por eso
`scripts/kwin-bridge.py` carga un script en KWin (`kwin/bridge.js`) que envía
el estado por D-Bus, y Elaren lo lee de la salida del helper. Las órdenes
(activar, minimizar, cambiar de escritorio) se ejecutan como scripts de KWin
de un solo uso. Requiere `python3-gi`.

## Animaciones

- **Entrada**: la barra cae desde arriba con rebote y los grupos aparecen
  escalonados (también en cada recarga en caliente).
- **Escritorios**: el indicador se desplaza con efecto "gusano".
- **Reloj**: los dígitos ruedan como un marcador mecánico.
- **Calendario**: se despliega con rebote, desliza la cuadrícula al cambiar de
  mes y se cierra al sacar el ratón.
- **Multimedia**: la carátula gira mientras suena; los controles se despliegan.
- **Volumen**: el deslizador aparece al pasar el ratón o al cambiar el volumen.
- **Batería**: "late" mientras carga y avisa cuando está crítica.
- **Fondo**: zoom-out al arrancar, fundido al cambiar de imagen y paralaje
  al cambiar de escritorio.
- **Dock**: sube con rebote, magnificación estilo macOS, iconos que entran
  escalonados, rebote al abrir una app e indicadores animados de ventanas.
- **Botones**: hover suave y onda (ripple) desde el punto de clic.

## Estructura

- `shell.qml` — punto de entrada
- `config/` — preferencias de usuario (singleton `Config`)
- `modules/` — piezas visibles (fondo, barra, calendario, dock)
- `services/` — lógica sin UI: hora, audio (PipeWire), batería (UPower),
  multimedia (MPRIS), ventanas y escritorios (KWin), apps, wallpaper
- `kwin/` y `scripts/kwin-bridge.py` — puente con KWin
- `components/` — controles reutilizables y animaciones base
  (`Anim`, `CAnim`, `StateLayer`, `Reveal`, `RollingText`, `MaterialIcon`…)
- `theme/` — colores, tipografía, formas y curvas de movimiento (singleton `Theme`)

Requiere la fuente **Material Symbols Rounded** para los iconos.
