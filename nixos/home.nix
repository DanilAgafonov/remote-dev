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

  # Makes the home-manager CLI available for standalone usage.
  programs.home-manager.enable = true;

  home.stateVersion = "25.11";
}
