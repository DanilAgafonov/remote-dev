{ pkgs, lib, ... }:

{
  home.username = "dagafonov";
  home.homeDirectory = "/home/dagafonov";

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "claude-code"
  ];

  home.packages = with pkgs; [
    claude-code
  ];

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

  programs.zellij = {
    enable = true;
    enableZshIntegration = false;
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  home.file.".claude/settings.json".text = builtins.toJSON {
    "$schema" = "https://json.schemastore.org/claude-code-settings.json";
    env = {
      CLAUDE_CODE_USE_BEDROCK = "1";
      ANTHROPIC_DEFAULT_HAIKU_MODEL = "us.anthropic.claude-haiku-4-5-20251001-v1:0";
      ANTHROPIC_DEFAULT_SONNET_MODEL = "us.anthropic.claude-sonnet-4-6";
      ANTHROPIC_DEFAULT_OPUS_MODEL = "us.anthropic.claude-opus-4-6-v1";
      CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
    };
    permissions = {
      allow = [
        "Bash(grep:*)"
        "Bash(gh pr diff:*)"
        "Bash(gh pr view:*)"
        "Bash(npm view:*)"
        "Bash(find:*)"
        "Bash(ls:*)"
        "mcp__aws-mcp__aws___search_documentation"
        "mcp__aws-mcp__aws___read_documentation"
        "mcp__aws-mcp__aws___recommend"
      ];
      defaultMode = "default";
    };
    model = "us.anthropic.claude-opus-4-6-v1";
    alwaysThinkingEnabled = true;
    skipDangerousModePermissionPrompt = true;
    enabledPlugins = {
      "superpowers@claude-plugins-official" = true;
      "atlassian@claude-plugins-official" = true;
    };
  };

  # Makes the home-manager CLI available for standalone usage.
  programs.home-manager.enable = true;

  home.stateVersion = "25.11";
}
