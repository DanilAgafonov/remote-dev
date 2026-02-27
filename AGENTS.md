# Remote Dev Environment

Fully declarative remote EC2 development environment for persistent Claude Code sessions.

## What This Is

A personal remote development machine on AWS, configured entirely through code. Two independent systems:

- **`infra/`** — Pulumi (TypeScript) manages AWS resources (VPC, EC2, IAM)
- **`nixos/`** — NixOS flake manages the machine (system config + home-manager for user config)

They connect only by "Pulumi creates the instance that runs the NixOS config."

## Project Structure

```
infra/                  # Pulumi TypeScript — AWS infrastructure
  index.ts              # EC2 instance, VPC, IAM, security groups
nixos/                  # NixOS flake — machine configuration
  flake.nix             # Inputs: nixpkgs-unstable, home-manager, claude-code-nix
  configuration.nix     # System-level: hostname, SSH, SSM agent, firewall, locale
  home.nix              # User-level: shell, tools, dotfiles
  home-dotfiles/        # Files symlinked into ~ via home-manager (recursive)
    .claude/            # Claude Code config (settings.json, CLAUDE.md, skills/)
```

## Key Concepts

### Two Separate Flake Outputs

`nixos-rebuild switch` applies system config (`configuration.nix`). `home-manager switch` applies user config (`home.nix`). They are independent — changing `home.nix` only requires `home-manager switch`.

### home-dotfiles Directory

Files in `nixos/home-dotfiles/` are automatically symlinked into `~` by home-manager with `recursive = true`. The mapping is auto-discovered via `builtins.readDir` — no need to edit `home.nix` when adding new entries. Individual files are symlinked (not directories), so the parent directories remain writable.

### Applying Changes

From laptop after pushing to main:

```bash
# System config
ssh remote-dev "cd ~/remote-dev && git pull && sudo nixos-rebuild switch --flake ./nixos"

# Home-manager config
ssh remote-dev "cd ~/remote-dev && git pull && home-manager switch --flake ./nixos#dagafonov"
```
