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

function push() {
    const active = workspace.activeWindow;
    const state = {
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
}

workspace.windowList().forEach(watch);
workspace.windowAdded.connect(w => { watch(w); push(); });
workspace.windowRemoved.connect(push);
workspace.windowActivated.connect(push);
workspace.currentDesktopChanged.connect(push);
workspace.desktopsChanged.connect(push);

push();
