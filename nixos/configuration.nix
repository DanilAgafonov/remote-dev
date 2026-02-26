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

  environment.systemPackages = with pkgs; [
    git
  ];

  # User account
  users.defaultUserShell = pkgs.zsh;
  users.users.dagafonov = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIMKXvDHR/86WVK0DzdTS+cVOKbOwLHaF6nSiQA8zKNS1AAAADHNzaDpkaWxpZ2VudA== ssh:diligent"
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIB6bK5tXatpCeMez+TDoN7IPtgJy/OdziP7OIjmmPJvQAAAADHNzaDpkaWxpZ2VudA== dagafonov@DILKL911QGK4M"
    ];
  };

  # zsh must be enabled at system level for it to be a valid login shell
  programs.zsh.enable = true;

  # Locale and timezone
  time.timeZone = "America/Vancouver";
  i18n.defaultLocale = "en_CA.UTF-8";

  # Firewall — no inbound, all outbound
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ ];
    allowedUDPPorts = [ ];
  };

}
