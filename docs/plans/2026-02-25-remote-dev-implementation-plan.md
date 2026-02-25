# Remote Dev Environment Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a fully declarative remote EC2 development environment for persistent Claude Code sessions, with Pulumi (TypeScript) for AWS infrastructure and NixOS + home-manager for machine configuration.

**Architecture:** Pulumi manages AWS resources (VPC, EC2, IAM) in `infra/`. NixOS flake in `nixos/` manages the machine (system config + home-manager). They are independent — connected only by "Pulumi creates the instance that runs the NixOS config." Git synchronizes config between laptop and machine.

**Tech Stack:** Pulumi (TypeScript), NixOS (unstable), home-manager, AWS (EC2, VPC, IAM, SSM)

---

### Task 1: Project scaffolding

**Files:**
- Create: `.gitignore`

**Step 1: Create .gitignore**

```gitignore
# Node / Pulumi
node_modules/
infra/node_modules/

# Pulumi
infra/.pulumi/

# Nix
nixos/result

# OS
.DS_Store
```

**Step 2: Verify and commit**

Run: `cat .gitignore`
Expected: File contents as above.

```bash
git add .gitignore
git commit -m "Add .gitignore for Pulumi, Nix, and OS artifacts"
```

---

### Task 2: Pulumi project setup

**Files:**
- Create: `infra/package.json`
- Create: `infra/tsconfig.json`
- Create: `infra/Pulumi.yaml`

**Step 1: Create `infra/package.json`**

```json
{
  "name": "remote-dev-infra",
  "version": "1.0.0",
  "description": "Pulumi infrastructure for remote dev environment",
  "type": "module",
  "main": "index.ts",
  "scripts": {
    "typecheck": "tsc --noEmit"
  },
  "devDependencies": {
    "@tsconfig/strictest": "^2",
    "typescript": "^5"
  },
  "dependencies": {
    "@pulumi/aws": "^6",
    "@pulumi/pulumi": "^3"
  }
}
```

**Step 2: Create `infra/tsconfig.json`**

```json
{
  "extends": "@tsconfig/strictest/tsconfig",
  "compilerOptions": {
    "target": "esnext",
    "module": "esnext",
    "moduleResolution": "bundler",
    "outDir": "bin",
    "noEmit": true
  },
  "include": ["./**/*.ts"]
}
```

**Step 3: Create `infra/Pulumi.yaml`**

```yaml
name: remote-dev-infra
runtime:
  name: nodejs
  options:
    typescript: true
description: AWS infrastructure for dagafonov remote dev environment
```

**Step 4: Install dependencies**

Run: `cd infra && pnpm install`
Expected: Dependencies installed, `pnpm-lock.yaml` created.

**Step 5: Verify TypeScript setup**

Run: `cd infra && pnpm run typecheck`
Expected: May warn about no input files (no `.ts` files yet). No errors.

**Step 6: Commit**

```bash
git add infra/package.json infra/tsconfig.json infra/Pulumi.yaml infra/pnpm-lock.yaml
git commit -m "Initialize Pulumi project with TypeScript configuration"
```

---

### Task 3: Pulumi infrastructure code

**Files:**
- Create: `infra/index.ts`

**Step 1: Create `infra/index.ts`**

```typescript
import * as aws from "@pulumi/aws";
import * as pulumi from "@pulumi/pulumi";

const config = new pulumi.Config();
const instanceType = config.get("instanceType") ?? "m8g.xlarge";
const volumeSize = config.getNumber("volumeSize") ?? 100;

const defaultTags: Record<string, string> = {
  "do-not-nuke": "true",
  Project: "remote-dev",
  Owner: "dagafonov",
};

// --- VPC + Networking ---

const vpc = new aws.ec2.Vpc("dagafonov-remote-dev-vpc", {
  cidrBlock: "10.0.0.0/16",
  enableDnsSupport: true,
  enableDnsHostnames: true,
  tags: { ...defaultTags, Name: "dagafonov-remote-dev-vpc" },
});

const igw = new aws.ec2.InternetGateway("dagafonov-remote-dev-igw", {
  vpcId: vpc.id,
  tags: { ...defaultTags, Name: "dagafonov-remote-dev-igw" },
});

const subnet = new aws.ec2.Subnet("dagafonov-remote-dev-subnet", {
  vpcId: vpc.id,
  cidrBlock: "10.0.1.0/24",
  mapPublicIpOnLaunch: true,
  tags: { ...defaultTags, Name: "dagafonov-remote-dev-subnet" },
});

const routeTable = new aws.ec2.RouteTable("dagafonov-remote-dev-rt", {
  vpcId: vpc.id,
  routes: [{ cidrBlock: "0.0.0.0/0", gatewayId: igw.id }],
  tags: { ...defaultTags, Name: "dagafonov-remote-dev-rt" },
});

new aws.ec2.RouteTableAssociation("dagafonov-remote-dev-rta", {
  subnetId: subnet.id,
  routeTableId: routeTable.id,
});

// --- Security Group ---

const sg = new aws.ec2.SecurityGroup("dagafonov-remote-dev-sg", {
  vpcId: vpc.id,
  description: "Remote dev - no inbound, all outbound",
  egress: [
    {
      protocol: "-1",
      fromPort: 0,
      toPort: 0,
      cidrBlocks: ["0.0.0.0/0"],
    },
  ],
  tags: { ...defaultTags, Name: "dagafonov-remote-dev-sg" },
});

// --- IAM Role for SSM ---

const role = new aws.iam.Role("dagafonov-remote-dev-role", {
  assumeRolePolicy: JSON.stringify({
    Version: "2012-10-17",
    Statement: [
      {
        Action: "sts:AssumeRole",
        Effect: "Allow",
        Principal: { Service: "ec2.amazonaws.com" },
      },
    ],
  }),
  tags: defaultTags,
});

new aws.iam.RolePolicyAttachment("dagafonov-remote-dev-ssm-policy", {
  role: role.name,
  policyArn: "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
});

const instanceProfile = new aws.iam.InstanceProfile(
  "dagafonov-remote-dev-instance-profile",
  {
    role: role.name,
    tags: defaultTags,
  },
);

// --- NixOS AMI Lookup ---

const ami = aws.ec2.getAmiOutput({
  owners: ["427812963091"],
  filters: [
    { name: "architecture", values: ["arm64"] },
    { name: "name", values: ["NixOS-*"] },
  ],
  mostRecent: true,
});

// --- EC2 Instance ---

const instance = new aws.ec2.Instance(
  "dagafonov-remote-dev",
  {
    ami: ami.id,
    instanceType,
    subnetId: subnet.id,
    vpcSecurityGroupIds: [sg.id],
    iamInstanceProfile: instanceProfile.name,
    rootBlockDevice: {
      volumeSize,
      volumeType: "gp3",
      deleteOnTermination: true,
      tags: { ...defaultTags, Name: "dagafonov-remote-dev-volume" },
    },
    tags: { ...defaultTags, Name: "dagafonov-remote-dev" },
  },
  { ignoreChanges: ["ami"] },
);

// --- Outputs ---

export const instanceId = instance.id;
export const publicIp = instance.publicIp;
export const amiId = ami.id;
```

**Step 2: Type-check**

Run: `cd infra && pnpm run typecheck`
Expected: No errors.

**Step 3: Commit**

```bash
git add infra/index.ts
git commit -m "Add Pulumi infrastructure: VPC, EC2, IAM, security group"
```

---

### Task 4: Pulumi stack configuration

**Files:**
- Create: `infra/Pulumi.prod.yaml`

**Step 1: Create `infra/Pulumi.prod.yaml`**

```yaml
config:
  aws:region: us-west-2
  remote-dev-infra:instanceType: m8g.xlarge
  remote-dev-infra:volumeSize: "100"
```

**Step 2: Commit**

```bash
git add infra/Pulumi.prod.yaml
git commit -m "Add Pulumi prod stack configuration"
```

---

### Task 5: NixOS flake

**Files:**
- Create: `nixos/flake.nix`

**Step 1: Create `nixos/flake.nix`**

```nix
{
  description = "Remote dev environment — NixOS + home-manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-code = {
      url = "github:sadjow/claude-code-nix";
    };
  };

  outputs = { self, nixpkgs, home-manager, claude-code, ... }: {
    nixosConfigurations.remote-dev = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
        {
          nixpkgs.overlays = [ claude-code.overlays.default ];
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.dagafonov = import ./home.nix;
        }
      ];
    };
  };
}
```

**Step 2: Commit**

```bash
git add nixos/flake.nix
git commit -m "Add NixOS flake with nixpkgs-unstable, home-manager, claude-code inputs"
```

Note: `flake.lock` will be generated on first `nix flake lock` or `nixos-rebuild`.
Do NOT run `nix flake lock` locally unless you have an aarch64-linux builder —
the lock file will be generated on the machine during first deployment.

---

### Task 6: NixOS system configuration

**Files:**
- Create: `nixos/configuration.nix`

**Step 1: Create `nixos/configuration.nix`**

```nix
{ modulesPath, pkgs, ... }:

{
  imports = [
    "${modulesPath}/virtualisation/amazon-image.nix"
  ];

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
```

**Step 2: Commit**

```bash
git add nixos/configuration.nix
git commit -m "Add NixOS system config: SSM, user account, nix settings, firewall"
```

---

### Task 7: Home-manager user configuration

**Files:**
- Create: `nixos/home.nix`

**Step 1: Create `nixos/home.nix`**

```nix
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
```

**Step 2: Commit**

```bash
git add nixos/home.nix
git commit -m "Add home-manager config: Claude Code, zsh, starship, zellij, granted"
```

---

### Task 8: README documentation

**Files:**
- Create: `README.md`

**Step 1: Create `README.md`**

```markdown
# Remote Dev Environment

Persistent EC2 machine for Claude Code agent sessions. Fully declarative:
AWS infrastructure via Pulumi, machine configuration via NixOS + home-manager.

## Prerequisites

- AWS CLI v2 with SSM Session Manager plugin
- Pulumi CLI
- pnpm
- AWS profile `dil-team-eevee/SandboxAdministratorAccess` configured

## First-Time Setup

### 1. Create Pulumi state bucket

```bash
aws s3 mb s3://dagafonov-remote-dev-pulumi-state --region us-west-2 \
  --profile dil-team-eevee/SandboxAdministratorAccess

aws s3api put-bucket-versioning \
  --bucket dagafonov-remote-dev-pulumi-state \
  --versioning-configuration Status=Enabled \
  --region us-west-2 \
  --profile dil-team-eevee/SandboxAdministratorAccess

aws s3api put-bucket-tagging \
  --bucket dagafonov-remote-dev-pulumi-state \
  --tagging 'TagSet=[{Key=do-not-nuke,Value=true},{Key=Owner,Value=dagafonov},{Key=Project,Value=remote-dev}]' \
  --region us-west-2 \
  --profile dil-team-eevee/SandboxAdministratorAccess
```

### 2. Deploy infrastructure

```bash
cd infra
pnpm install
pulumi login s3://dagafonov-remote-dev-pulumi-state --region us-west-2
pulumi stack init prod
pulumi up
```

Note the `instanceId` output — you'll need it for SSM.

### 3. First-time NixOS setup

```bash
# SSM into the instance
aws ssm start-session --target <instance-id> \
  --profile dil-team-eevee/SandboxAdministratorAccess \
  --region us-west-2

# IMPORTANT: Read stock NixOS config BEFORE applying your own.
# Verify your flake's configuration.nix covers everything important.
cat /etc/nixos/configuration.nix

# Clone this repo
git clone <repo-url> ~/remote-dev

# Apply NixOS configuration
cd ~/remote-dev
sudo nixos-rebuild switch --flake ./nixos#remote-dev

# Switch to your user
sudo su - dagafonov
```

## Common Commands

### Connect to machine

```bash
aws ssm start-session --target <instance-id> \
  --profile dil-team-eevee/SandboxAdministratorAccess \
  --region us-west-2
```

### Reconnect to zellij session

```bash
zellij attach
```

### Apply NixOS config changes from laptop

Edit configs locally, then:

```bash
git add -A && git commit -m "..." && git push

aws ssm send-command --instance-id <instance-id> \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["cd /home/dagafonov/remote-dev && git pull && sudo nixos-rebuild switch --flake ./nixos#remote-dev"]' \
  --profile dil-team-eevee/SandboxAdministratorAccess \
  --region us-west-2
```

### Apply NixOS config changes from machine

```bash
cd ~/remote-dev
# edit configs...
sudo nixos-rebuild switch --flake ./nixos#remote-dev
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
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "Add README with bootstrap, deployment, and usage documentation"
```

---

### Task 9: Final verification

**Step 1: Verify project structure**

Run: `find . -type f -not -path './.git/*' | sort`

Expected:
```
./.gitignore
./README.md
./docs/plans/2026-02-25-remote-dev-environment-design.md
./docs/plans/2026-02-25-remote-dev-implementation-plan.md
./infra/Pulumi.prod.yaml
./infra/Pulumi.yaml
./infra/index.ts
./infra/package.json
./infra/pnpm-lock.yaml
./infra/tsconfig.json
./nixos/configuration.nix
./nixos/flake.nix
./nixos/home.nix
```

**Step 2: Verify Pulumi type-checks**

Run: `cd infra && pnpm run typecheck`
Expected: No errors.

**Step 3: Verify all files committed**

Run: `git status`
Expected: `nothing to commit, working tree clean`
