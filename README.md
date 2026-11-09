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
| Izquierda | Lanzador              | Clic: abre KRunner                                       |
|           | Escritorios virtuales | Clic: cambiar · Rueda: siguiente/anterior                |
| Centro    | Reloj                 | Clic: calendario (rueda: cambiar de mes)                 |
| Derecha   | Multimedia (MPRIS)    | Hover: controles anterior / pausa / siguiente            |
|           | Bandeja del sistema   | Clic: activar · Derecho: menú · Medio: acción secundaria |
|           | Volumen y batería     | Rueda: ±5 % · Clic en icono: silenciar · Arrastrar: fijar|

Los escritorios usan el protocolo `ext-workspace-v1` de KWin; si el
compositor no lo expone, el módulo se oculta.

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
- **Botones**: hover suave y onda (ripple) desde el punto de clic.

## Estructura

- `shell.qml` — punto de entrada
- `modules/` — piezas visibles (barra, calendario…)
- `services/` — lógica sin UI: hora, audio (PipeWire), batería (UPower),
  multimedia (MPRIS), escritorios
- `components/` — controles reutilizables y animaciones base
  (`Anim`, `CAnim`, `StateLayer`, `Reveal`, `RollingText`, `MaterialIcon`…)
- `theme/` — colores, tipografía, formas y curvas de movimiento (singleton `Theme`)

Requiere la fuente **Material Symbols Rounded** para los iconos.
