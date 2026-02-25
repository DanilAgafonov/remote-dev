{ pkgs, ... }:

{
  home.username = "dagafonov";
  home.homeDirectory = "/home/dagafonov";

  home.packages = with pkgs; [
    claude-code
    zellij
    granted
    awscli2
  ];

  programs.git = {
    enable = true;
  };

  programs.zsh = {
    enable = true;
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  # Match the NixOS version of the AMI used for first install.
  home.stateVersion = "24.11";
}
