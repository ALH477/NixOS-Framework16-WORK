# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

let
  # Prefer nixos-unstable channel, fallback to tarball if channel is unavailable
  unstable = import <nixos-unstable> {} // (
    if builtins.pathExists <nixos-unstable> then {}
    else import (builtins.fetchTarball {
      url = "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz";
      # Update this sha256 after running nix-prefetch-url if the tarball changes
      sha256 = "0000000000000000000000000000000000000000000000000000";
    }) {}
  );
in
{
  # Define sources for external modules
  imports = [
    # Include the results of the hardware scan
    ./hardware-configuration.nix
    # Framework 16 hardware module for AMD Ryzen 7040 Series
    (builtins.fetchTarball {
      url = "https://github.com/NixOS/nixpkgs-channels/archive/nixos-unstable.tar.gz";
      sha256 = "005wz7dfk2mmcymqxpi00zgag21bb83bk3wx174hm6nvk1wmqvfs";
    } + "/framework/16-inch/7040-amd")
    # fw-fanctrl module
    (builtins.fetchTarball {
      url = "https://github.com/TamtamHero/fw-fanctrl/archive/packaging/nix.tar.gz";
      sha256 = "1rcs2lpj8nmlqqc0if6ykagdg4c6v5g757prvhjgxyynsq2psb35";
    } + "/nix/module.nix")
  ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel for GPU and hardware support
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Boot into multi-user target (TTY) instead of graphical
  services.xserver.enable = false;
  systemd.defaultUnit = lib.mkForce "multi-user.target";

  # Networking
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  hardware.bluetooth.enable = true; # enables support for Bluetooth
  hardware.bluetooth.powerOnBoot = true;

  # Time zone
  time.timeZone = "America/Los_Angeles";

  # Internationalisation
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

  # Enable touchpad support
  services.libinput.enable = true;

  # Enable acpid
  services.acpid.enable = true;

  # Enable CUPS for printing
  services.printing.enable = true;

  # Enable sound with PipeWire
  services.pulseaudio.enable = false;
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

  # Enable power management
  services.power-profiles-daemon.enable = true;

  # Enable firmware updates
  services.fwupd.enable = true;

  # Enable redistributable firmware
  hardware.enableRedistributableFirmware = true;

  # Enable OpenGL and Vulkan with latest Mesa from unstable
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    package = unstable.mesa;
    package32 = unstable.pkgsi686Linux.mesa;
    extraPackages = with unstable; [
      mesa
      amdvlk
      vulkan-loader
      vulkan-tools
      vulkan-validation-layers
      libva
      libvdpau
    ];
    extraPackages32 = with unstable.pkgsi686Linux; [
      mesa
      amdvlk
      vulkan-loader
      libva
      libvdpau
    ];
  };

  # Enable Docker
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };

  # Enable Wireshark
  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark;
  };

  # Enable Hyprland
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

 programs.thunar.enable = true;

  # Enable fw-fanctrl for fan control with aggressive cooling
  programs.fw-fanctrl = {
    enable = true;
    config = {
      defaultStrategy = "lazy";
      strategies = {
        lazy = {
          fanSpeedUpdateFrequency = 5;
          movingAverageInterval = 30;
          speedCurve = [
            { temp = 0; speed = 20; }   # Start at 20% speed for better baseline cooling
            { temp = 50; speed = 20; }  # Maintain 20% up to 50°C
            { temp = 60; speed = 30; }  # Increase to 30% at 60°C
            { temp = 65; speed = 40; }  # 40% at 65°C for quicker response
            { temp = 70; speed = 60; }  # 60% at 70°C for aggressive cooling
            { temp = 80; speed = 100; } # Full speed at 80°C to prevent overheating
          ];
        };
      };
    };
  };

  # User account
  users.users.asher = {
    isNormalUser = true;
    description = "Asher";
    extraGroups = [ "networkmanager" "wheel" "docker" "wireshark" ];
    shell = pkgs.bash;
    packages = with pkgs; [];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # System packages
  environment.systemPackages = with pkgs; [
    # Core tools
    vim
    git
    htop
    nvme-cli
    mangohud
    lm_sensors
    s-tui
    stress
    dmidecode
    util-linux

    # Requested packages
    python3Full
    python3Packages.pip
    python3Packages.virtualenv
    wireshark
    cmake
    kdePackages.kdenlive
    ardour
    blueberry
    vesktop

    # Development tools
    gcc
    gnumake
    ninja
    kitty
    wofi
    waybar
    pavucontrol
    hyprpaper

    # Multimedia dependencies
    ffmpeg
    jack2
    qjackctl
    libpulseaudio  # Added for PulseAudio compatibility
    pkgsi686Linux.libpulseaudio  # 32-bit PulseAudio for Steam

    # Networking tools
    tcpdump
    nmap

    # Docker tools
    docker-compose
    docker-buildx

    # Gaming and graphics
    vulkan-tools
    vulkan-loader
    vulkan-validation-layers
    brave
    dwm
    hyprland
    vlc
    pandoc
    kdePackages.okular
    xorg.xinit
    steam-run  # For FHS environment
    libva-utils
    obs-studio
    xdg-desktop-portal-hyprland  # For PipeWire screen sharing
    steam  # Added to ensure full Steam package
  ];

  # Enable Steam
  programs.steam = {
    enable = true;
    extraCompatPackages = with pkgs; [ proton-ge-bin ];
  };

  # JACK configuration for Ardour
  environment.etc."jack/conf.xml".text = ''
    <?xml version="1.0"?>
    <jack>
      <engine>
        <param name="driver" value="alsa"/>
        <param name="realtime" value="true"/>
      </engine>
    </jack>
  '';

  # Configure .xinitrc for dwm
  environment.etc."xinitrc".text = ''
    #!/bin/sh
    exec ${pkgs.dwm}/bin/dwm
  '';

  # Ensure Qt applications run on Wayland for OBS compatibility
  environment.sessionVariables = {
    QT_QPA_PLATFORM = "wayland";
  };

  # NixOS release version
  system.stateVersion = "25.05";
}
