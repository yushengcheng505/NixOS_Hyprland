{ pkgs }:

let
  msdosRevision = "2d04cacc5322951f187bb17e017c12920ac8ebe2";
  fetchDosTool = name: hash: pkgs.fetchurl {
    inherit name hash;
    url = "https://raw.githubusercontent.com/microsoft/MS-DOS/${msdosRevision}/v4.0/src/TOOLS/${name}";
  };
  masm = fetchDosTool "MASM.EXE" "sha256-HGKGxpthYWC4R1rRdFPuhycCosmAdcIVnseSocdFJ18=";
  link = fetchDosTool "LINK.EXE" "sha256-Eko8gA7cFrYPaW01qd/seYtot4/iypDFmI6na96rGoo=";
  exe2bin = fetchDosTool "EXE2BIN.EXE" "sha256-pmo4ddfzENlTEmUfONC0MkbTus+nIPKMSURfzBC7+o8=";
  msdosLicense = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/microsoft/MS-DOS/${msdosRevision}/LICENSE";
    hash = "sha256-tRefeA7CEqQ078yYmiKVoUDesL2xcYLSv5xfbx8aAcQ=";
  };
  debugArchive = pkgs.fetchurl {
    url = "https://github.com/Baron-von-Riedesel/DOS-debug/releases/download/v2.51/DEBUGb.zip";
    hash = "sha256-CNMr5txDuccsm3FN4DaiQR8PlCy/RwPrFVC0f8aHpIE=";
  };
  debugSource = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/Baron-von-Riedesel/DOS-debug/v2.51/src/DEBUG.ASM";
    hash = "sha256-KRcUSCEsL7R56D0zjFtrwDPjUQ09L5edSvl/esauvUI=";
  };
  buildBatch = pkgs.writeText "BUILD.BAT" ''
    @echo off
    if "%1"=="" goto usage
    if exist %1.OBJ del %1.OBJ
    if exist %1.EXE del %1.EXE
    if exist %1.LST del %1.LST
    if exist %1.MAP del %1.MAP
    masm %1.ASM,%1.OBJ,%1.LST;
    if errorlevel 1 goto asmerror
    if not exist %1.OBJ goto asmerror
    loadfix -64 link %1.OBJ,%1.EXE,%1.MAP;
    if errorlevel 1 goto linkerror
    if not exist %1.EXE goto linkerror
    echo Built %1.EXE, %1.OBJ, %1.LST, %1.MAP
    goto end
    :asmerror
    echo Assembly failed. Check %1.LST.
    goto end
    :linkerror
    echo Linking failed.
    goto end
    :usage
    echo Usage: BUILD name_without_extension
    echo Example: BUILD HELLO
    :end
  '';
  helpBatch = pkgs.writeText "LABHELP.BAT" ''
    @echo off
    echo OSiS - Assembly laboratories 6, 7, 8
    echo.
    echo C: working files. T: read-only tools. ANSI.SYS enabled.
    echo CD \LAB6, CD \LAB7, CD \LAB8 - laboratory folders
    echo CD \EXAMPLE - installation example, not a lab solution
    echo EDIT HELLO.ASM - edit source
    echo BUILD HELLO - assemble, link and create listing
    echo HELLO - run program
    echo DEBUG HELLO.EXE - debug: R, T, G, D, U, Q
    echo MASM HELLO,HELLO,HELLO; - assemble manually
    echo LOADFIX -64 LINK HELLO,HELLO,HELLO; - link manually
    echo EXIT - close DOSBox-X
    echo LABHELP - show this help again
    echo.
  '';
  hello = pkgs.writeText "HELLO.ASM" ''
    title Installation check
    stack segment para stack 'stack'
        db 128 dup(?)
    stack ends
    dseg segment para public 'data'
        message db 'MASM + LINK + DOS interrupts: OK',13,10,'$'
        source db 10,20,30,40
        dest db 4 dup(0)
        screen db 27,'[2J',27,'[5;7H',27,'[1;34;47m','ANSI screen: OK',27,'[0m',13,10,'$'
    dseg ends
    cseg segment para public 'code'
    assume cs:cseg,ds:dseg,ss:stack
    start:
        mov ax,dseg
        mov ds,ax
        mov al,source
        mov dest+3,al
        mov al,source+1
        mov dest+2,al
        mov al,source+2
        mov dest+1,al
        mov al,source+3
        mov dest,al
        mov dx,offset screen
        mov ah,9
        int 21h
        mov dx,offset message
        mov ah,9
        int 21h
        mov ax,4c00h
        int 21h
    cseg ends
    end start
  '';
  tools = pkgs.runCommand "osis-dos-tools-1" { nativeBuildInputs = [ pkgs.unzip ]; } ''
    mkdir -p "$out/licenses"
    install -m444 ${masm} "$out/MASM.EXE"
    install -m444 ${link} "$out/LINK.EXE"
    install -m444 ${exe2bin} "$out/EXE2BIN.EXE"
    unzip -j ${debugArchive} DEBUG.COM DEBUG.TXT README.TXT -d "$out"
    install -m444 ${msdosLicense} "$out/licenses/MS-DOS-LICENSE.txt"
    install -m444 ${debugSource} "$out/licenses/DEBUG.ASM"
    ${pkgs.python3}/bin/python - "$out" ${buildBatch} ${helpBatch} <<'PY'
    import pathlib
    import sys
    for source, name in zip(sys.argv[2:], ("BUILD.BAT", "LABHELP.BAT")):
        pathlib.Path(sys.argv[1], name).write_bytes(pathlib.Path(source).read_bytes().replace(b"\n", b"\r\n"))
    PY
  '';
  config = pkgs.writeText "osis-dosbox-x.conf" ''
    [sdl]
    fullscreen = false
    output = openglnb
    windowresolution = 1280x960
    autolock = false
    waitonerror = false
    priority = normal,normal
    titlebar = OSiS - Labs 6, 7, 8

    [dosbox]
    machine = svga_s3
    memsize = 16
    captures = captures
    working directory option = default

    [render]
    aspect = true

    [cpu]
    core = normal
    cputype = 386
    cycles = fixed 12000

    [mixer]
    nosound = true

    [dos]
    ansi.sys = true
    keyboardlayout = us
    ver = 5.0
    lfn = false

    [autoexec]
    @echo off
    mount c "drive_c"
    mount t "${tools}" -ro
    c:
    set PATH=T:\;Z:\;Z:\DOS;Z:\BIN;Z:\SYSTEM;Z:\TEXTUTIL
    chcp 866
    cls
    call T:\LABHELP.BAT
  '';
  launcher = pkgs.writeShellApplication {
    name = "osis-asm";
    runtimeInputs = [ pkgs.coreutils pkgs.dosbox-x ];
    text = ''
      work="''${OSIS_ASM_HOME:-$HOME/Labs OS/dos-labs}"
      mkdir -p "$work/drive_c/LAB6" "$work/drive_c/LAB7" "$work/drive_c/LAB8" \
        "$work/drive_c/EXAMPLE" "$work/captures"
      if [[ ! -e "$work/drive_c/EXAMPLE/HELLO.ASM" ]]; then
        install -m644 ${hello} "$work/drive_c/EXAMPLE/HELLO.ASM"
      fi
      cd "$work"
      exec dosbox-x -defaultconf -conf ${config} -nopromptfolder -fastlaunch "$@"
    '';
  };
  desktop = pkgs.makeDesktopItem {
    name = "osis-asm";
    desktopName = "OSiS - Assembly Labs";
    genericName = "MASM, LINK and DEBUG for DOS";
    comment = "DOS environment for operating systems laboratories 6, 7 and 8";
    exec = "${launcher}/bin/osis-asm";
    icon = "dosbox-x";
    terminal = false;
    categories = [ "Education" "ComputerScience" ];
    keywords = [ "OSiS" "DOS" "MASM" "Assembler" "DEBUG" ];
    extraConfig = {
      "Name[ru]" = "ОСиС — Ассемблер (ЛР 6–8)";
      "Comment[ru]" = "DOSBox-X, MASM, LINK и DEBUG для лабораторных работ";
    };
  };
in
pkgs.symlinkJoin {
  name = "osis-asm-1.0";
  paths = [ launcher desktop ];
  postBuild = ''
    mkdir -p "$out/share/icons/hicolor/scalable/apps" "$out/share/osis-asm"
    ln -s ${pkgs.dosbox-x}/share/icons/hicolor/scalable/apps/dosbox-x.svg \
      "$out/share/icons/hicolor/scalable/apps/dosbox-x.svg"
    ln -s ${tools} "$out/share/osis-asm/tools"
    ln -s ${config} "$out/share/osis-asm/dosbox-x.conf"
  '';
  meta = {
    description = "DOSBox-X with MASM, LINK and DEBUG for OSiS assembly laboratories";
    license = pkgs.lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "osis-asm";
  };
}
