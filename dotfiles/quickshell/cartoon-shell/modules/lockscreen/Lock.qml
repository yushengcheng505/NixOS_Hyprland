import Quickshell
import Quickshell.Wayland
import QtQuick
import Quickshell.Io

Scope {
  id: root
  property bool showLockscreen: false

  LockContext {
    id: lockContext

    // Do NOT release the lock immediately on unlock signal.
    // LockSurface listens to this and plays an exit animation first,
    // then calls root.releaseLock() when the animation is done.
    onUnlocked: {
      // intentionally left empty — LockSurface drives the teardown timing
    }

    // Expose a function so LockSurface can release the lock after animation
    function releaseLock() {
      root.showLockscreen = false
    }
  }

  WlSessionLock {
    id: lock
    locked: root.showLockscreen
    WlSessionLockSurface {
      color: "transparent"
      LockSurface {
        anchors.fill: parent
        context: lockContext
      }
    }
  }

  IpcHandler {
    function lock(): void {
      // Keep the existing IPC name for the shell button and keybind, but use
      // Hyprland DPMS so this action powers off displays without locking the
      // Wayland session or starting PAM authentication.
      root.showLockscreen = false;
      Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.dpms(\"off\")"]);
    }
    function unlock(): void {
      root.showLockscreen = false;
    }
    function isLocked(): bool {
      return root.showLockscreen;
    }
    target: "lock"
  }
}
