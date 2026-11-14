# Barra compacta con isla — plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Barra centrada del ancho de su contenido con avatar + reloj al centro que despliega una isla fusionada (Inicio / Música / Letra / Calendario).

**Architecture:** `Bar.qml` pasa a ser una ventana de capa a pantalla completa (sin zona exclusiva) que dibuja barra + isla como un único `Shape` en un marco "canónico" (eje X a lo largo de la barra, Y hacia adentro) transformado por matriz según el borde. Una `BarReserve` invisible reserva el espacio. Los popups de música y calendario se convierten en vistas (`InlineCard`) que la isla carga con `Loader`.

**Tech Stack:** QML / Quickshell 0.3.2, Qt 6.10, KWin (layer-shell).

**Spec:** `docs/superpowers/specs/2026-11-14-barra-isla-design.md`

## Global Constraints

- Textos y comentarios en español rioplatense; tokens de `Theme`, `Anim`/`CAnim`.
- Preferencias: alias + `defaults` + `JsonAdapter store` en `config/Config.qml`.
- Ningún `Shape` con `asynchronous: true`.
- Sin dependencias nuevas. Sin commit ni push.
- No hay suite de tests en el repo: la verificación es `./scripts/lint.sh` (sin
  errores nuevos en archivos tocados) + prueba manual con `./scripts/run.sh`.

## Review Focus

- Isla cerrada: la ventana a pantalla completa no debe capturar clics fuera de la barra (máscara = barra).
- Isla abierta con la barra a la izquierda/derecha/abajo: forma y contenido del lado correcto, contenido sin rotar.
- Reproductor que desaparece con la isla en Música/Letra → vuelve a Inicio, sin vista vacía.
- Isla cerrada → `Visualizer.popupActive` y `Lyrics.wanted` en falso (Loaders inactivos).
- Captura de pantalla con la isla abierta → se cierra (como `AnimatedPopup`).

---

### Task 1: Preferencia `barAvatarShape` + control en Configuración → Barra
**Files:** `config/Config.qml`, `modules/settings/SettingsWindow.qml`
- [ ] Alias `barAvatarShape`, default `"squircle"`, `property string barAvatarShape` en store.
- [ ] `ChoiceRow` "Forma del avatar" (círculo / squircle / flor / hexágono) en la tarjeta "Ubicación" → renombrada "Ubicación y aspecto" no; nueva tarjeta "Isla central".

### Task 2: `components/Avatar.qml`
- [ ] Props: `shape: string`, `lookX/lookY: real` (-1..1). Imagen `file://$HOME/.face`, respaldo ícono `person`. Máscara `MultiEffect` (Rectangle para círculo/squircle, `Shape` CurveRenderer síncrono para flor/hexágono). Inclinación ±8° y desplazamiento ±3 px con `Anim`.

### Task 3: Vistas reutilizables
- [ ] `components/InlineCard.qml`: misma API que `AnimatedPopup` (`open`, `cardWidth`, `padding`, `decoration`, contenido por defecto, `cardColor`, `borderColor`, `dismissed()`) pero como `Item`.
- [ ] `NowPlayingPopup.qml` → `NowPlayingView.qml` (raíz `InlineCard`, `lyricsMode` externo, botón de letra emite `lyricsToggled()`).
- [ ] `CalendarPopup.qml` → `CalendarView.qml` (raíz `InlineCard`).

### Task 4: `Clock.qml` compacto con avatar
- [ ] Avatar 22 px + HH:MM (+ segundos al pasar) + chevron; prop `open` en vez de `calendarOpen`; `lookX/lookY` hacia el avatar.

### Task 5: `Bar.qml` + `BarReserve.qml` + `Island.qml` + `HomeView.qml`
- [ ] `BarReserve`: `PanelWindow` invisible anclada al borde, `exclusiveZone` = grosor.
- [ ] `Bar`: anclada a 4 bordes, `ExclusionMode.Ignore`, máscara barra / pantalla completa, `Shape` canónico con path SVG (barra + isla + empalmes cóncavos), blur región barra ∪ isla, foco de teclado exclusivo abierta, Escape, clic afuera, cierre en captura.
- [ ] `Island`: pestañas (Inicio, Música, Letra, Calendario; música/letra solo con `Media.available`), `Loader` por vista activa solo abierta.
- [ ] `shell.qml`: `BarReserve` por pantalla.

### Task 6: README + verificación
- [ ] Describir isla y forma del avatar. `./scripts/lint.sh`; probar en las 4 posiciones.
