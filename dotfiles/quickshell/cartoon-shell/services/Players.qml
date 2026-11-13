pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.commons

Singleton {
  id: root

  readonly property var mprisPlayer: {
    let selected = null;
    let highestPriority = -1;
    for (const player of Mpris.players.values) {
      const state = player.playbackState;
      const priority = state === MprisPlaybackState.Playing ? 2 : state === MprisPlaybackState.Paused ? 1 : 0;
      if (priority > highestPriority) {
        selected = player;
        highestPriority = priority;
      }
    }
    return selected;
  }

  readonly property string artUrl: getRemoteArtUrl(mprisPlayer)
  property string artSource: ""
  property string requestedArtUrl: ""
  property bool artBusy: false
  property bool artReady: false

  onArtUrlChanged: {
    root.artSource = "";
    artRetry.stop();
    if (root.artReady)
      root.loadArt();
  }

  function getRemoteArtUrl(player: MprisPlayer): string {
    if (!player)
      return "";
    if (player.trackArtUrl)
      return player.trackArtUrl;
    const url = player.metadata["xesam:url"] ?? "";
    if (url.startsWith("https://www.youtube.com/watch")) {
      const id = url.match(/[?&]v=([\w-]{11})/)?.[1];
      return id ? `https://img.youtube.com/vi/${id}/hqdefault.jpg` : "";
    }
    return "";
  }

  function getArtUrl(player: MprisPlayer): string {
    return player === root.mprisPlayer ? root.artSource : "";
  }

  function loadArt() {
    if (root.artBusy)
      return;
    if (!/^https?:\/\//i.test(root.artUrl)) {
      root.artSource = /^(file:|image:|qrc:|\/)/.test(root.artUrl) ? root.artUrl : "";
      return;
    }
    root.requestedArtUrl = root.artUrl;
    root.artBusy = true;
    artProcess.stdinEnabled = true;
    artProcess.running = true;
  }

  Process {
    id: artProcess
    command: ["python3", Directories.scriptsPath + "/album-art.py", Directories.shellCacheImagesDir + "/album-art"]
    onStarted: {
      write(root.requestedArtUrl + "\n");
      stdinEnabled = false;
    }
    onRunningChanged: {
      if (!running && root.artBusy && stdinEnabled) {
        root.artBusy = false;
        artRetry.restart();
      }
    }
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: (exitCode, exitStatus) => {
      root.artBusy = false;
      if (root.requestedArtUrl !== root.artUrl) {
        root.loadArt();
        return;
      }
      let source = "";
      if (exitCode === 0 && exitStatus === 0) {
        try {
          source = JSON.parse(artProcess.stdout.text).source || "";
        } catch (e) {}
      }
      root.artSource = source;
      if (!source)
        artRetry.restart();
    }
  }

  Timer {
    id: artRetry
    interval: 60000
    onTriggered: root.loadArt()
  }

  Component.onCompleted: {
    root.artReady = true;
    root.loadArt();
  }
  function getProgress() {
    if (!root.mprisPlayer)
    return 0

    var pos = root.mprisPlayer.position ?? 0
    var len = root.mprisPlayer.length ?? 0

    if (len <= 0 || pos < 0)
    return 0

    var progress = pos / len

    return Math.max(0, Math.min(1, progress))
  }

  function formatTime(seconds) {
    if (isNaN(seconds) || seconds < 0)
    return "00:00"

    var totalSeconds = Math.floor(seconds)
    var minutes = Math.floor(totalSeconds / 60)
    var secs = totalSeconds % 60

    function pad(n) {
      return n < 10 ? "0" + n : n
    }

    return pad(minutes) + ":" + pad(secs)
  }

  function getActive(prop: string): string {
    const active = root.active;
    return active ? active[prop] ?? "Invalid property" : "No active player";
  }

  function list(): string {
    return root.list.map(p => root.getIdentity(p)).join("\n");
  }

  function play(): void {
    const active = root.active;
    if (active?.canPlay)
    active.play();
  }

  function pause(): void {
    const active = root.active;
    if (active?.canPause)
    active.pause();
  }

  function playPause(): void {
    const active = root.mprisPlayer;
    if (active?.canTogglePlaying)
    active.togglePlaying();
  }

  function previous(): void {
    const active = root.mprisPlayer;
    if (active?.canGoPrevious)
    active.previous();
  }

  function next(): void {
    const active = root.mprisPlayer;
    if (!active) {
      console.warn("Cannot go next: no active player");
      return;
    }
    if (active.canGoNext === true) {
      active.next();
    } else {
      console.warn("Cannot go next: canGoNext is false");
    }
  }

  function stop(): void {
    root.active?.stop();
  }

}
