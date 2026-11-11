// Script de KWin cargado por scripts/kwin-bridge.py.
// Envía a Elaren el estado de ventanas y escritorios cada vez que cambia.

function windowState(w) {
    return {
        id: w.internalId.toString(),
        caption: w.caption,
        appId: w.desktopFileName || w.resourceClass,
        resourceClass: w.resourceClass,
        minimized: w.minimized,
        onAllDesktops: w.onAllDesktops,
        desktops: w.desktops.map(d => d.id)
    };
}

function isTaskWindow(w) {
    return w.normalWindow && !w.skipTaskbar;
}

// Spectacle mostrando su selector de región / pantalla completa (no la
// ventana del editor). Elaren oculta sus popups mientras tanto: son
// xdg_popup y KWin los pinta por encima de cualquier ventana.
function isScreenshotOverlay(w) {
    const id = (w.desktopFileName || "") + " " + (w.resourceClass || "");
    return /spectacle/i.test(id) && (w.fullScreen || w.skipTaskbar || !w.normalWindow);
}

function push() {
    const active = workspace.activeWindow;
    const state = {
        screenshot: workspace.windowList().some(isScreenshotOverlay),
        desktops: workspace.desktops.map(d => ({ id: d.id, name: d.name })),
        currentDesktop: workspace.currentDesktop ? workspace.currentDesktop.id : "",
        active: active ? active.internalId.toString() : "",
        windows: workspace.windowList().filter(isTaskWindow).map(windowState)
    };
    callDBus("dev.elaren.Bridge", "/dev/elaren/Bridge", "dev.elaren.Bridge", "Push", JSON.stringify(state));
}

function watch(w) {
    w.captionChanged.connect(push);
    w.minimizedChanged.connect(push);
    w.desktopsChanged.connect(push);
    w.skipTaskbarChanged.connect(push);
    w.fullScreenChanged.connect(push);
}

workspace.windowList().forEach(watch);
workspace.windowAdded.connect(w => { watch(w); push(); });
workspace.windowRemoved.connect(push);
workspace.windowActivated.connect(push);
workspace.currentDesktopChanged.connect(push);
workspace.desktopsChanged.connect(push);

push();
