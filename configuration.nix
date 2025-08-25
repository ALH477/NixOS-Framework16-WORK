{ config, pkgs, lib, ... }:

{
  nixpkgs.overlays = [
    (final: prev: {
      unstable = import (fetchTarball {
        url = "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz";
        sha256 = "sha256-K7g9R2x+3O2/eEa5B2Yq1mIw2IpBrxJsTXnVCI4L2A0=";
      }) {
        system = prev.system;
        config.allowUnfree = true;
      };
    })
  ];

  imports = [
    # Add paths to external modules if needed (e.g., for nixos-hardware, fw-fanctrl, determinate)
    # Example: <nixos-hardware/framework/16-inch/7040-amd>
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [ "amdgpu.abmlevel=0" ];

  specialisation.realtime.configuration = {
    boot.kernelPackages = lib.mkOverride 0 pkgs.linuxPackages_rt;
  };

  services.xserver.enable = true;
  services.xserver.displayManager.sddm.enable = true;
  services.xserver.desktopManager.cinnamon.enable = true;
  services.xserver.windowManager.dwm.enable = true;
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };
  systemd.defaultUnit = lib.mkForce "graphical.target";

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk pkgs.xdg-desktop-portal-hyprland ];
  };

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  time.timeZone = "America/Los_Angeles";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  services.libinput.enable = true;
  services.acpid.enable = true;
  services.printing.enable = true;

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    extraConfig = {
      pipewire."90-custom" = {
        "default.clock.quantum" = 1024;
        "default.clock.min-quantum" = 512;
        "default.clock.max-quantum" = 2048;
      };
    };
  };

  services.udisks2.enable = true;
  security.polkit.enable = true;
  services.power-profiles-daemon.enable = true;
  services.fwupd.enable = true;
  hardware.enableRedistributableFirmware = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    package = pkgs.unstable.mesa;
    package32 = pkgs.unstable.pkgsi686Linux.mesa;
    extraPackages = with pkgs.unstable; [
      mesa amdvlk vulkan-loader vulkan-tools vulkan-validation-layers libva libvdpau
    ];
    extraPackages32 = with pkgs.unstable.pkgsi686Linux; [
      mesa amdvlk vulkan-loader vulkan-tools vulkan-validation-layers libva libvdpau
    ];
  };

  services.fprintd.enable = true;
  security.pam.services = {
    login.fprintAuth = true;
    sudo.fprintAuth = true;
  };

  users.users.asher = {
    isNormalUser = true;
    description = "Asher";
    extraGroups = [ "networkmanager" "wheel" "docker" "wireshark" "disk" ];
    shell = pkgs.bash;
    packages = with pkgs; [ ];
  };

  nixpkgs.config.allowUnfree = true;

  systemd.timers.nix-gc-generations = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
  };

  systemd.services.nix-gc-generations = {
    script = ''
      generations_to_delete=$(${pkgs.nix}/bin/nix-env -p /nix/var/nix/profiles/system --list-generations | ${pkgs.gawk}/bin/awk '{print $1}' | ${pkgs.coreutils}/bin/head -n -5 | ${pkgs.coreutils}/bin/tr '\n' ' ')
      if [ -n "$generations_to_delete" ]; then
        ${pkgs.nix}/bin/nix-env -p /nix/var/nix/profiles/system --delete-generations $generations_to_delete
      fi
      ${pkgs.nix}/bin/nix-collect-garbage
    '';
    serviceConfig.Type = "oneshot";
  };

  environment.systemPackages = with pkgs; [
    vim git htop nvme-cli mangohud lm_sensors s-tui stress dmidecode util-linux gparted usbutils
    python3Full python3Packages.pip python3Packages.virtualenv python3Packages.cryptography python3Packages.pycryptodome
    python3Packages.grpcio python3Packages.grpcio-tools python3Packages.protobuf
    python3Packages.numpy python3Packages.matplotlib
    wireshark cmake kdePackages.kdenlive ardour blueberry vesktop audacity font-awesome fastfetch gnugrep scribus
    gcc gnumake ninja kitty wofi waybar pavucontrol hyprpaper rustc cargo go openssl gnutls qemu virt-manager
    ffmpeg jack2 qjackctl libpulseaudio pkgsi686Linux.libpulseaudio tcpdump nmap docker-compose docker-buildx
    vulkan-tools vulkan-loader vulkan-validation-layers brave dwm hyprland vlc pandoc kdePackages.okular xorg.xinit steam-run libva-utils obs-studio xdg-desktop-portal-hyprland steam
    xfce.thunar xfce.thunar-volman gvfs udiskie polkit_gnome framework-tool brightnessctl
    gimp inkscape blender libreoffice krita protobufc grpc pkgconf
    (perl.withPackages (ps: with ps; [ JSON GetoptLong CursesUI ModulePluggable Appcpanminus ]))
  ];

  programs.steam = {
    enable = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };

  environment.etc."jack/conf.xml".text = ''
    <?xml version="1.0"?>
    <jack>
      <engine>
        <param name="driver" value="alsa"/>
        <param name="realtime" value="true"/>
      </engine>
    </jack>
  '';

  environment.sessionVariables.QT_QPA_PLATFORM = "wayland;xcb";

  system.stateVersion = "25.05";
}
