#!/usr/bin/env python3
"""Puente entre KWin y Elaren.

KWin (Wayland) no expone a clientes externos la lista de ventanas ni los
escritorios virtuales por protocolos que Quickshell entienda. Este helper:

1. Registra el nombre D-Bus `dev.elaren.Bridge` en el bus de sesión.
2. Carga en KWin un script (kwin/bridge.js) que, ante cada cambio, llama a
   `dev.elaren.Bridge.Push(json)` con el estado completo.
3. Escribe cada estado recibido como una línea JSON en stdout (lo lee Quickshell).
4. Lee órdenes JSON por stdin (activar ventana, minimizar, cambiar de
   escritorio…) y las ejecuta cargando en KWin un script de un solo uso.

Al terminar (stdin cerrado, SIGTERM o SIGINT) descarga sus scripts de KWin.
"""

import json
import os
import signal
import sys
import tempfile

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

BUS_NAME = "dev.elaren.Bridge"
OBJECT_PATH = "/dev/elaren/Bridge"
PLUGIN = "elaren-bridge"
HERE = os.path.dirname(os.path.abspath(__file__))
BRIDGE_JS = os.path.join(HERE, "..", "kwin", "bridge.js")

INTROSPECTION = f"""
<node>
  <interface name="{BUS_NAME}">
    <method name="Push"><arg type="s" name="state" direction="in"/></method>
  </interface>
</node>
"""

bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
loop = GLib.MainLoop()
oneshot_counter = 0


def log(*args):
    print("[kwin-bridge]", *args, file=sys.stderr, flush=True)


def scripting(method, signature, *args):
    return bus.call_sync(
        "org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting", method,
        GLib.Variant(signature, args) if signature else None,
        None, Gio.DBusCallFlags.NONE, 3000, None,
    )


def run_script(path, plugin):
    """Carga y ejecuta un script en KWin. Devuelve su id."""
    try:
        scripting("unloadScript", "(s)", plugin)
    except GLib.Error:
        pass
    script_id = scripting("loadScript", "(ss)", path, plugin).unpack()[0]
    if script_id < 0:
        raise RuntimeError(f"KWin rechazó el script {path}")
    bus.call_sync(
        "org.kde.KWin", f"/Scripting/Script{script_id}", "org.kde.kwin.Script", "run",
        None, None, Gio.DBusCallFlags.NONE, 3000, None,
    )
    return script_id


def unload(plugin):
    try:
        scripting("unloadScript", "(s)", plugin)
    except GLib.Error:
        pass


# ── Órdenes de un solo uso ──────────────────────────────────────────────────

def js_window(uuid, body):
    return (
        "(function(){const w = workspace.windowList().find(w => w.internalId.toString() === "
        + json.dumps(uuid) + "); if (!w) return; " + body + "})();"
    )


def build_command(cmd):
    kind = cmd.get("cmd")
    if kind == "activate":
        return js_window(cmd["id"], "if (w.minimized) w.minimized = false; workspace.activeWindow = w;")
    if kind == "toggle":
        # Si ya está activa la minimiza; si no, la trae al frente.
        return js_window(
            cmd["id"],
            "if (workspace.activeWindow === w && !w.minimized) { w.minimized = true; }"
            " else { w.minimized = false; workspace.activeWindow = w; }",
        )
    if kind == "minimize":
        return js_window(cmd["id"], "w.minimized = true;")
    if kind == "close":
        return js_window(cmd["id"], "w.closeWindow();")
    if kind == "desktop":
        return (
            "(function(){const d = workspace.desktops.find(d => d.id === "
            + json.dumps(cmd["id"]) + "); if (d) workspace.currentDesktop = d;})();"
        )
    if kind == "desktopStep":
        step = int(cmd.get("step", 1))
        return (
            "(function(){const ds = workspace.desktops; const i = ds.indexOf(workspace.currentDesktop);"
            f" workspace.currentDesktop = ds[(i + ({step}) + ds.length) % ds.length];}})();"
        )
    return None


def run_oneshot(source):
    global oneshot_counter
    oneshot_counter += 1
    plugin = f"{PLUGIN}-cmd-{oneshot_counter % 4}"
    fd, path = tempfile.mkstemp(prefix="elaren-kwin-", suffix=".js")
    with os.fdopen(fd, "w") as f:
        f.write(source)
    try:
        run_script(path, plugin)
    finally:
        unload(plugin)
        os.unlink(path)


def on_stdin(channel, condition):
    if condition & (GLib.IO_HUP | GLib.IO_ERR):
        loop.quit()
        return False
    line = channel.readline()
    if not line:
        loop.quit()
        return False
    try:
        source = build_command(json.loads(line))
        if source:
            run_oneshot(source)
    except Exception as e:  # una orden mal formada no debe tumbar el puente
        log("orden fallida:", e)
    return True


# ── Servidor D-Bus ──────────────────────────────────────────────────────────

def on_method_call(_conn, _sender, _path, _iface, method, params, invocation):
    if method == "Push":
        state = params.unpack()[0]
        sys.stdout.write(state.replace("\n", " ") + "\n")
        sys.stdout.flush()
    invocation.return_value(None)


def main():
    node = Gio.DBusNodeInfo.new_for_xml(INTROSPECTION)
    bus.register_object(OBJECT_PATH, node.interfaces[0], on_method_call, None, None)

    owned = {"ok": False}

    def acquired(*_):
        owned["ok"] = True
        try:
            run_script(os.path.abspath(BRIDGE_JS), PLUGIN)
        except Exception as e:
            log("no se pudo cargar el script de KWin:", e)
            loop.quit()

    def lost(*_):
        if not owned["ok"]:
            log(f"{BUS_NAME} ya está en uso (¿otra instancia de Elaren?)")
        loop.quit()

    owner_id = Gio.bus_own_name_on_connection(
        bus, BUS_NAME, Gio.BusNameOwnerFlags.REPLACE | Gio.BusNameOwnerFlags.ALLOW_REPLACEMENT,
        acquired, lost,
    )

    stdin = GLib.IOChannel.unix_new(sys.stdin.fileno())
    GLib.io_add_watch(stdin, GLib.PRIORITY_DEFAULT, GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, on_stdin)

    try:
        gi.require_version("GLibUnix", "2.0")
        from gi.repository import GLibUnix
        signal_add = GLibUnix.signal_add
    except (ImportError, ValueError):
        signal_add = GLib.unix_signal_add
    for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        signal_add(GLib.PRIORITY_HIGH, sig, loop.quit)

    try:
        loop.run()
    finally:
        unload(PLUGIN)
        Gio.bus_unown_name(owner_id)


if __name__ == "__main__":
    main()
