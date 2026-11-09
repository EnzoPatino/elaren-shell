# Elaren

Shell de escritorio para **KDE Plasma 6** (Wayland) escrita en QML con
[Quickshell](https://quickshell.org).

## Desarrollo

```bash
./scripts/run.sh    # arranca la shell; se recarga sola al guardar
./scripts/lint.sh   # qmllint sobre todos los .qml
```

## Estructura

- `shell.qml` — punto de entrada
- `modules/` — piezas visibles (barra, dock, menús…)
- `services/` — lógica sin UI (D-Bus, procesos, estado)
- `components/` — controles reutilizables
- `theme/` — colores y tipografía (singleton `Theme`)
