import Quickshell
import Quickshell.Wayland
import QtQuick
import Quickshell.Io

Scope {
  id: root
  property bool showLockscreen: false

  LockContext {
    id: lockContext

    // LockSurface drives teardown timing and calls releaseLock() itself.
    onUnlocked: {
    }

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
      root.showLockscreen = false;
      Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.dpms({ action = "off", monitor = "eDP-1" })']);
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
