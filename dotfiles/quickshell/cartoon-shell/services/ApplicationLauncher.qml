pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    readonly property var categories: ["All", "Work", "Internet", "Office", "Sound & Video", "System", "Preferences", "Study"]
    readonly property var categoryOverrides: ({
        "hermes": "Work",
        "orca-ide": "Work",
        "penpot-mcp-start": "Work",
        "penpot-mcp-stop": "Work",
        "blueman-adapters": "System",
        "blueman-manager": "System",
        "org.gnome.Nautilus": "System",
        "org.gnome.Loupe": "System",
        "debian13-lab": "Study",
        "virt-manager": "Study",
        "draw": "Office",
        "dev.deedles.Trayscale": "Internet",
        "trayscale": "Internet"
    })

    function categoryFor(entry) {
        if (!entry)
            return "Study";
        const override = categoryOverrides[entry.id];
        if (override)
            return override;
        const cats = entry.categories || [];
        if (cats.includes("Development"))
            return "Work";
        if (cats.includes("Network"))
            return "Internet";
        if (cats.includes("Office"))
            return "Office";
        if (cats.includes("AudioVideo") || cats.includes("Audio") || cats.includes("Video"))
            return "Sound & Video";
        if (cats.includes("System"))
            return "System";
        if (cats.includes("Settings"))
            return "Preferences";
        if (cats.includes("Graphics"))
            return "System";
        return "Study";
    }

    function applicationPath() {
        const home = Quickshell.env("HOME");
        const user = Quickshell.env("USER");
        const paths = [];
        if (home) {
            paths.push(home + "/.local/bin", home + "/.nix-profile/bin");
            paths.push((Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/nix/profile/bin");
        }
        if (user)
            paths.push("/etc/profiles/per-user/" + user + "/bin");
        const inherited = Quickshell.env("PATH");
        if (inherited)
            paths.push(inherited);
        return paths.join(":");
    }

    function launch(arguments) {
        const path = applicationPath();
        Quickshell.execDetached({
            command: ["app2unit", "-t", "service", "-C", "-p", "Environment=PATH=" + path].concat(arguments),
            environment: { PATH: path }
        });
    }

    function launchDesktopEntry(desktopId) {
        if (!desktopId || typeof desktopId !== "string")
            return;

        launch(["--", desktopId + ".desktop"]);
    }

    function openUrl(url) {
        if (!url)
            return;

        launch(["-O", "--", url]);
    }
}
