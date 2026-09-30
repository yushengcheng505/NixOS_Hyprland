{
  lib,
  stdenv,
  autoPatchelfHook,
  coreutils,
  fetchurl,
  glibc,
  gnugrep,
  gnutar,
  patchelf,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  gdk-pixbuf,
  glib,
  gtk3,
  libX11,
  libXcomposite,
  libXcursor,
  libXdamage,
  libXext,
  libXfixes,
  libXinerama,
  libXrandr,
  libxcb,
  libxkbcommon,
  libxscrnsaver,
  libxtst,
  libsoup_3,
  pango,
  webkitgtk_4_1,
  wayland,
  hyprland,
  gst_all_1,
}:

let
  inherit (gst_all_1) gstreamer gst-plugins-base;
in

stdenv.mkDerivation rec {
  pname = "easycliproxyapi";
  version = "0.2.96";

  src = fetchurl {
    url = "https://github.com/router-for-me/EasyCLIProxyAPI/releases/download/v${version}/EasyCLIProxyAPI-v${version}-Linux-amd64.tar.gz";
    hash = "sha256-u0Oi4WEEW/YhHJfhBKsG2qkBB3DcEtS+Q3xRJ49rbfY=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    gnutar
    patchelf
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    gtk3
    libX11
    libXcomposite
    libXcursor
    libXdamage
    libXext
    libXfixes
    libXinerama
    libXrandr
    libxcb
    libxkbcommon
    libxscrnsaver
    libxtst
    libsoup_3
    pango
    webkitgtk_4_1
    wayland
    gstreamer
    gst-plugins-base
  ];

  sourceRoot = "EasyCLIProxyAPI-v${version}-Linux-amd64";
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 EasyCLIProxyAPI $out/lib/easycliproxyapi/EasyCLIProxyAPI
    install -Dm644 core-version.txt $out/lib/easycliproxyapi/core-version.txt
    install -Dm644 portable-app.json $out/lib/easycliproxyapi/portable-app.json
    mkdir -p $out/lib/easycliproxyapi/cpa-core
    mkdir -p cpa-core/patched
    ${gnutar}/bin/tar -xzf cpa-core/CLIProxyAPI_7.3.3_linux_amd64.tar.gz -C cpa-core/patched
    ${patchelf}/bin/patchelf \
      --set-interpreter ${glibc}/lib/ld-linux-x86-64.so.2 \
      --set-rpath ${glibc}/lib \
      cpa-core/patched/cli-proxy-api
    ${gnutar}/bin/tar -czf cpa-core/CLIProxyAPI_7.3.3_linux_amd64.tar.gz \
      -C cpa-core/patched cli-proxy-api LICENSE README.md README_CN.md config.example.yaml
    rm -rf cpa-core/patched
    cp -a cpa-core/. $out/lib/easycliproxyapi/cpa-core/

    install -Dm755 /dev/stdin $out/bin/easycliproxyapi <<'EOF'
    #!${stdenv.shell}
    set -eu

    data_dir="''${XDG_DATA_HOME:-''${HOME}/.local/share}/easycliproxyapi"
    payload_dir="''${data_dir}/payload"

    if [ ! -x "''${payload_dir}/EasyCLIProxyAPI" ]; then
      ${coreutils}/bin/rm -rf "''${payload_dir}.new"
      ${coreutils}/bin/mkdir -p "''${payload_dir}.new/cpa-core"
      ${coreutils}/bin/cp "${placeholder "out"}/lib/easycliproxyapi/EasyCLIProxyAPI" "''${payload_dir}.new/EasyCLIProxyAPI"
      ${coreutils}/bin/cp "${placeholder "out"}/lib/easycliproxyapi/core-version.txt" "''${payload_dir}.new/core-version.txt"
      ${coreutils}/bin/cp "${placeholder "out"}/lib/easycliproxyapi/portable-app.json" "''${payload_dir}.new/portable-app.json"
      ${coreutils}/bin/cp -a "${placeholder "out"}/lib/easycliproxyapi/cpa-core/." "''${payload_dir}.new/cpa-core/"
      ${coreutils}/bin/chmod -R u+rwX "''${payload_dir}.new"
      ${coreutils}/bin/mkdir -p "''${data_dir}"
      ${coreutils}/bin/rm -rf "''${payload_dir}"
      ${coreutils}/bin/mv "''${payload_dir}.new" "''${payload_dir}"
    fi

    # WebKitGTK 4.1 under native Wayland on a fractional-scale (1.733) Hyprland
    # output miscomputes the webview size: the page renders shrunk into the
    # top-left corner on a black window. GDK_BACKEND=x11 (XWayland) lays the
    # UI out correctly; with xwayland.force_zero_scaling the buffer is sharp,
    # and GDK_DPI_SCALE=1.5 enlarges the webview text/layout to a readable size.
    export GTK_CSD=0
    export GDK_BACKEND=x11
    export GDK_DPI_SCALE=1.5
    export GST_PLUGIN_SYSTEM_PATH_1_0="${gstreamer}/lib/gstreamer-1.0:${gst-plugins-base}/lib/gstreamer-1.0"
    exec "''${payload_dir}/EasyCLIProxyAPI" "''$@"
    EOF

    install -Dm644 /dev/stdin $out/share/applications/easycliproxyapi.desktop <<EOF
    [Desktop Entry]
    Name=EasyCLIProxyAPI
    Comment=Desktop GUI for CLIProxyAPI
    Exec=$out/bin/easycliproxyapi
    Terminal=false
    Type=Application
    Categories=Development;Network;
    EOF

    runHook postInstall
  '';

  meta = {
    description = "Desktop GUI for CLIProxyAPI";
    homepage = "https://github.com/router-for-me/EasyCLIProxyAPI";
    license = lib.licenses.mit;
    mainProgram = "easycliproxyapi";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
