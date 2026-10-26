{ pkgs }:

pkgs.appimageTools.wrapType2 rec {
  pname = "orca-ide";
  version = "1.4.200";

  src = pkgs.fetchurl {
    url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-linux.AppImage";
    hash = "sha256-yC2d31MkMeDaUexdGJmg4xWqu453/ORezOf61HM/yWo=";
  };

  appimageContents = pkgs.appimageTools.extract { inherit pname version src; };

  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/orca-ide.desktop -t $out/share/applications/
    install -Dm444 ${appimageContents}/orca-ide.png \
      -t $out/share/icons/hicolor/512x512/apps/
    substituteInPlace $out/share/applications/orca-ide.desktop \
      --replace-fail 'Exec=AppRun' "Exec=$out/bin/orca-ide"
  '';

  meta = {
    description = "Agent development environment for parallel coding workflows";
    homepage = "https://www.onorca.dev/";
    license = pkgs.lib.licenses.mit;
    mainProgram = "orca-ide";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ pkgs.lib.sourceTypes.binaryNativeCode ];
  };
}
