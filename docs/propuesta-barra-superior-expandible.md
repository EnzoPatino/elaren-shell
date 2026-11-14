# Propuesta: barra superior expandible

**Estado:** propuesta para implementar
**Diseño interactivo:** [Gestor de presupuesto con alertas en Figma Make](https://www.figma.com/make/JDhi7O4LSW13Toz2hcvijR/Gestor-de-presupuesto-con-alertas?t=OPjXWPXMiFSGb2oD-20&fullscreen=1)
**Boceto original:** `WhatsApp Unknown 2026-11-12 at 3.29.23 PM/`

## Objetivo

Hacer que la barra de Elaren pueda pasar de una franja compacta a un panel más amplio al interactuar, con accesos visuales y una experiencia musical más rica. La idea tiene que sentirse parte de la shell: vidrio, animaciones y tokens ya existentes.

Este documento convierte el boceto en una guía de implementación. El conector de Figma no permitió leer el archivo Make durante su preparación; las decisiones marcadas como **a definir** salen de interpretar el dibujo y conviene confirmarlas mirando el prototipo antes de cerrar el comportamiento.

## Lo que muestra el boceto

- Una barra compacta con avatar/acceso de inicio, controles de música, hora y estado del sistema.
- Al interactuar, la barra se transforma o despliega un panel y aparecen accesos configurables.
- Accesos sugeridos: agregar acceso, música/visualizador, calendario, reloj o temporizador, notificaciones y dibujo animado.
- El reproductor expandido muestra portada, tema, artista, animación y una forma de volver a la barra.
- Una segunda vista presenta la letra sincronizada con una línea que marca el verso actual; se sugiere poder cambiar su tamaño.
- En Configuración → Barra se podría elegir entre una representación compacta y otra más grande.
- Las transiciones deben hacer que la barra se despliegue y vuelva a su estado compacto.

## Comportamiento propuesto

1. La barra mantiene el comportamiento y los módulos actuales mientras está compacta.
2. Una acción explícita (clic en el control de música o en un acceso) abre la superficie correspondiente. El hover puede revelar controles secundarios, pero no debería ser la única forma de abrir o cerrar una vista.
3. El reproductor y la vista de letras se abren como paneles anclados a la barra, con cierre claro y retorno al estado compacto.
4. Solo una superficie de barra queda abierta a la vez. Escape y clic fuera la cierran, respetando la interacción que ya usa cada popup.
5. Los controles que dependen de un servicio se muestran solo cuando ese servicio está disponible. Una vista cerrada no debería mantener búsquedas o animaciones activas.
6. La expansión respeta la posición elegida para la barra (arriba, abajo o lateral) y no intercepta clics fuera de sus controles visibles.

**A definir al contrastar con Figma:** si la expansión reemplaza la barra, crece desde ella o aparece como panel separado; qué gesto la abre; qué hace el avatar; y si el menú de accesos permanece visible mientras está abierto el reproductor.

## Alcance sugerido para la primera implementación

### Incluir

- Pulir la transición compacto ↔ expandido y la navegación entre vistas de música/letras, reutilizando el popup existente.
- Definir un acceso de retorno/cierre visible y consistente.
- Hacer que la barra siga funcionando en sus cuatro posiciones.
- Agregar ajustes solo para opciones acordadas y persistirlos en `config/Config.qml` (alias, `defaults` y `JsonAdapter store`).
- Mantener idioma, tokens, animaciones y componentes existentes.

### Dejar para una etapa posterior o confirmar antes

- Avatar/perfil: no hay una función asociada definida en el boceto.
- Notificaciones: definir si se trata de notificaciones de Plasma, historial o solo un acceso al centro existente.
- “Agregar acceso”: definir qué destinos se pueden agregar y cómo se ordenan/eliminan.
- Reloj/temporizador: confirmar si es una vista informativa o un temporizador con controles y persistencia.
- “Dibujo animado”: confirmar si es decoración, mascota o visualizador; no asumir que es el visualizador de escritorio.
- Cambio entre tamaño compacto/grande: decidir si es preferencia persistente, estado temporal o ambos.

No sumar dependencias ni cambiar protocolos de Quickshell/KDE para resolver estos puntos sin necesidad.

## Reutilizar lo que ya existe

- `modules/bar/Bar.qml`: composición de la barra, popups y `activePopup`.
- `modules/bar/MediaWidget.qml`: reproductor compacto con portada, título, progreso y controles al pasar el puntero.
- `modules/bar/NowPlayingPopup.qml`: reproductor expandido, portada/vinilo, controles, visualizador de audio y modo de letras.
- `services/Media.qml`, `services/Lyrics.qml` y `services/Visualizer.qml`: datos y lógica multimedia.
- `modules/bar/Clock.qml`, `CalendarPopup.qml`, `Tray.qml` y `SystemPopup.qml`: reloj, calendario, bandeja y estado.
- `components/AnimatedPopup.qml`, `Reveal.qml`, `Anim.qml` y `CAnim.qml`: superficies y transiciones.
- `config/Config.qml` y la página de barra de `modules/settings/SettingsWindow.qml`: preferencias.

El repositorio ya contiene gran parte de la experiencia musical dibujada. Antes de crear vistas nuevas, revisar estos componentes y completar los huecos concretos.

## Criterios de aceptación

- Se puede abrir y cerrar cada vista usando mouse y teclado; Escape y clic fuera cierran donde corresponda.
- La barra y los popups funcionan arriba, abajo, a izquierda y derecha.
- La portada, tema, artista, controles y progreso vienen de `Media`; las acciones respetan las capacidades MPRIS disponibles.
- La búsqueda de letras y el visualizador solo trabajan cuando la vista correspondiente está abierta, siguiendo los servicios existentes.
- Sin reproductor activo, no aparece un reproductor vacío ni se inicia trabajo multimedia innecesario.
- La expansión no tapa controles importantes ni captura clics del escritorio fuera de la superficie visible.
- Los ajustes nuevos se restauran correctamente desde Configuración y sobreviven al reinicio.
- El aspecto usa tokens y animaciones de Elaren y mantiene los textos en español rioplatense.

## Handoff para quien implemente

> Implementá la propuesta de `docs/propuesta-barra-superior-expandible.md` en Elaren Shell (QML/Quickshell). Revisá primero `git status` y conservá todos los cambios locales existentes. Contrasta el comportamiento con el prototipo enlazado y los bocetos de `WhatsApp Unknown 2026-11-12 at 3.29.23 PM/`. Reutilizá `Bar.qml`, `MediaWidget.qml`, `NowPlayingPopup.qml` y los servicios multimedia antes de crear componentes o lógica duplicados. Implementá solo el alcance acordado; no inventes comportamiento para avatar, notificaciones, temporizador, accesos configurables ni “dibujo animado” sin validar esas decisiones. Seguí `AGENTS.md`: textos en español rioplatense, tokens y animaciones existentes, preferencias sincronizadas en alias/defaults/JsonAdapter. No edites archivos generados ni `~/.config/elaren/`. No hagas commit ni push.
