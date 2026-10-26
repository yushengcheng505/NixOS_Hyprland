{ pkgs, ... }:

let
  honorDsdt = ../dsdt.global.aml;
  honorDsdtInitrd = pkgs.runCommand "honor-fmbp-dsdt-initrd" {
    nativeBuildInputs = [ pkgs.cpio ];
  } ''
    mkdir -p root/kernel/firmware/acpi
    cp ${honorDsdt} root/kernel/firmware/acpi/dsdt.aml
    (cd root && find kernel -print | cpio -o -H newc --reproducible) > "$out"
  '';
in
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.initrd.prepend = [ "${honorDsdtInitrd}" ];
  boot.kernelParams = [ "i915.enable_psr=0" ];
  boot.kernelModules = [ "i8042" "tun" ];

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 100;
  };

  boot.kernel.sysctl = {
    "vm.swappiness" = 100;
    "vm.page-cluster" = 0;
  };

  services.libinput.enable = true;
  services.udev.extraRules = ''
    SUBSYSTEM=="input", KERNEL=="input*", ATTR{name}=="FTSC1000:00 2808:5662 UNKNOWN", ATTR{inhibited}="1"
    SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="FTSC1000:00 2808:5662 UNKNOWN", ENV{LIBINPUT_IGNORE_DEVICE}="1"
  '';
}
