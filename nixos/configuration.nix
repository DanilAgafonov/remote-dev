{ modulesPath, pkgs, ... }:

{
  imports = [
    "${modulesPath}/virtualisation/amazon-image.nix"
  ];

  # Preserve EFI boot config from stock AMI.
  ec2.efi = true;

  networking.hostName = "dagafonov-remote-dev-machine";

  # SSM agent — enabled by default in amazon-image.nix, made explicit here
  services.amazon-ssm-agent.enable = true;

  # Nix settings
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters = [
      "https://cache.nixos.org"
      "https://claude-code.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk="
    ];
  };

  # User account
  users.users.dagafonov = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
  };

  # zsh must be enabled at system level for it to be a valid login shell
  programs.zsh.enable = true;

  # Locale and timezone
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  # Firewall — no inbound, all outbound
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ ];
    allowedUDPPorts = [ ];
  };

  # Match the NixOS version of the AMI used for first install.
  # Do NOT change this after deployment — it controls backwards compatibility.
  system.stateVersion = "24.11";
}
