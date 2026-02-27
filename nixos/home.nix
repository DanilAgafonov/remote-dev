{ pkgs, lib, ... }:

{
  home.username = "dagafonov";
  home.homeDirectory = "/home/dagafonov";

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "claude-code"
  ];

  home.packages = with pkgs; [
    claude-code
    sops
  ];

  home.activation.npmrc = lib.hm.dag.entryAfter ["writeBoundary"] ''
    TOKEN=$(run ${pkgs.sops}/bin/sops --decrypt --extract '["github_packages_token"]' ${./secrets.yaml})
    run install -m 600 /dev/stdin $HOME/.npmrc << EOF
    @acl-services:registry=https://npm.pkg.github.com
    @diligentcorp:registry=https://npm.pkg.github.com
    //npm.pkg.github.com/:_authToken=$TOKEN
    EOF
  '';

  programs.git = {
    enable = true;
    signing = {
      format = "ssh";
      key = "~/.ssh/id_ed25519.pub";
      signByDefault = true;
    };
    settings = {
      user = {
        name = "Danil Agafonov";
        email = "dagafonov@diligent.com";
      };
      init.defaultBranch = "main";
    };
  };

  programs.granted = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.awscli.enable = true;

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  programs.gh.enable = true;

  programs.jq.enable = true;

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    initContent = ''
      bindkey "''${key[Up]}" up-line-or-search
      bindkey "''${key[Down]}" down-line-or-search

      take() { mkdir -p "$1" && cd "$1"; }
    '';
    sessionVariables = {
      COLORTERM = "truecolor";
    };
    shellAliases = {
      la = "ls -lAh";
      grep = "grep --color";
      gst = "git status";
      ga = "git add";
      gaa = "git add --all";
      gsw = "git switch";
      gswc = "git switch -c";
      gco = "git checkout";
      gp = "git push";
      ggp = "git push origin HEAD";
      gl = "git pull";
      ggl = "git pull origin HEAD";
      gprom = "git pull --rebase origin main";
      gpromi = "git pull --rebase=interactive origin main";
    };
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zellij = {
    enable = true;
    enableZshIntegration = true;
    attachExistingSession = true;
    exitShellOnExit = true;
  };

  home.file = builtins.mapAttrs (name: _: {
    source = ./home-dotfiles + "/${name}";
    recursive = true;
  }) (builtins.readDir ./home-dotfiles);

  # Makes the home-manager CLI available for standalone usage.
  programs.home-manager.enable = true;

  home.stateVersion = "25.11";
}
