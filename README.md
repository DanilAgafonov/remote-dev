# Remote Dev Environment

Persistent EC2 machine for Claude Code agent sessions. Fully declarative:
AWS infrastructure via Pulumi, machine configuration via NixOS + home-manager.

## Prerequisites

- AWS CLI v2 with SSM Session Manager plugin
- [mise](https://mise.jdx.dev/) (manages Pulumi version, see `mise.toml`)
- pnpm
- AWS profile `dil-team-eevee/SandboxAdministratorAccess` configured

## First-Time Setup

### 1. Create Pulumi state bucket

```bash
aws s3 mb s3://dagafonov-remote-dev-pulumi-state --region us-west-2 \
  --profile dil-team-eevee/SandboxAdministratorAccess
```

```bash
aws s3api put-bucket-versioning \
  --bucket dagafonov-remote-dev-pulumi-state \
  --versioning-configuration Status=Enabled \
  --region us-west-2 \
  --profile dil-team-eevee/SandboxAdministratorAccess
```

```bash
aws s3api put-bucket-tagging \
  --bucket dagafonov-remote-dev-pulumi-state \
  --tagging 'TagSet=[{Key=do-not-nuke,Value=true}]' \
  --region us-west-2 \
  --profile dil-team-eevee/SandboxAdministratorAccess
```

### 2. Create KMS key for Pulumi secrets encryption

```bash
aws kms create-key \
  --description "Pulumi secrets encryption for remote-dev" \
  --tags TagKey=do-not-nuke,TagValue=true \
  --region us-west-2 \
  --profile dil-team-eevee/SandboxAdministratorAccess
```

Note the `KeyId` from the output, then create an alias:

```bash
aws kms create-alias \
  --alias-name alias/dagafonov-remote-dev-pulumi \
  --target-key-id <key-id> \
  --region us-west-2 \
  --profile dil-team-eevee/SandboxAdministratorAccess
```

### 3. Deploy infrastructure

```bash
cd infra
pnpm install
pulumi login s3://dagafonov-remote-dev-pulumi-state
pulumi stack init prod --secrets-provider="awskms://alias/dagafonov-remote-dev-pulumi?region=us-west-2"
pulumi up
```

Note the `instanceId` output -- you'll need it for SSM.

### 4. First-time NixOS setup

SSM into the instance:

```bash
aws ssm start-session --target <instance-id> \
  --profile dil-team-eevee/SandboxAdministratorAccess \
  --region us-west-2
```

Apply NixOS system configuration directly from GitHub (no local clone needed):

```bash
sudo nixos-rebuild switch --flake github:DanilAgafonov/remote-dev?dir=nixos#dagafonov-remote-dev-machine
```

Clone the repo as your user (user was created by nixos-rebuild above):

```bash
sudo -u dagafonov git clone https://github.com/DanilAgafonov/remote-dev.git /home/dagafonov/remote-dev
```

Switch to your user and apply home-manager configuration:

```bash
sudo su - dagafonov
nix run home-manager/master -- switch --flake ~/remote-dev/nixos#dagafonov
```

## Common Commands

### Connect to machine

Add to `~/.ssh/config`:

```
Host remote-dev
  HostName <instance-id>
  User dagafonov
  ProxyCommand sh -c "aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters 'portNumber=%p' --profile dil-team-eevee/SandboxAdministratorAccess --region us-west-2"
```

Then:

```bash
ssh remote-dev
```

### Reconnect to zellij session

```bash
zellij attach
```

### Apply system config changes from laptop

Edit configs locally, then:

```bash
git add -A && git commit -m "..." && git push
```

```bash
aws ssm send-command --instance-id <instance-id> \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["cd /home/dagafonov/remote-dev && sudo -u dagafonov git pull && sudo nixos-rebuild switch --flake ./nixos"]' \
  --profile dil-team-eevee/SandboxAdministratorAccess \
  --region us-west-2
```

### Apply config changes from machine

```bash
cd ~/remote-dev
# edit configs...
sudo nixos-rebuild switch --flake ./nixos
home-manager switch --flake ./nixos#dagafonov
git add -A && git commit -m "..." && git push
```

### Apply infrastructure changes

```bash
cd infra && pulumi up
```

## Cost

| Item | Cost |
|------|------|
| m8g.xlarge 24/7 | ~$131/month |
| 100 GB gp3 EBS | ~$8/month |
| **Total** | **~$139/month** |
