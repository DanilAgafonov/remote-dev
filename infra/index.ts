import * as aws from "@pulumi/aws";
import * as pulumi from "@pulumi/pulumi";

const config = new pulumi.Config();
const instanceType = config.get("instanceType") ?? "m8g.xlarge";
const volumeSize = config.getNumber("volumeSize") ?? 100;

// Prevents team cleanup automation from deleting resources.
const defaultTags: Record<string, string> = {
  "do-not-nuke": "true",
};

// --- VPC + Networking ---

const vpc = new aws.ec2.Vpc("dagafonov-remote-dev-vpc", {
  cidrBlock: "10.0.0.0/16",
  enableDnsSupport: true,
  enableDnsHostnames: true,
  // Name tag is displayed in the AWS Console.
  tags: { ...defaultTags, Name: "dagafonov-remote-dev-vpc" },
});

const igw = new aws.ec2.InternetGateway("dagafonov-remote-dev-igw", {
  vpcId: vpc.id,
  // Name tag is displayed in the AWS Console.
  tags: { ...defaultTags, Name: "dagafonov-remote-dev-igw" },
});

const subnet = new aws.ec2.Subnet("dagafonov-remote-dev-subnet", {
  vpcId: vpc.id,
  cidrBlock: "10.0.1.0/24",
  mapPublicIpOnLaunch: true,
  // Name tag is displayed in the AWS Console.
  tags: { ...defaultTags, Name: "dagafonov-remote-dev-subnet" },
});

const routeTable = new aws.ec2.RouteTable("dagafonov-remote-dev-rt", {
  vpcId: vpc.id,
  routes: [{ cidrBlock: "0.0.0.0/0", gatewayId: igw.id }],
  // Name tag is displayed in the AWS Console.
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
  // Name tag is displayed in the AWS Console.
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

new aws.iam.RolePolicy("dagafonov-remote-dev-bedrock-policy", {
  role: role.name,
  policy: JSON.stringify({
    Version: "2012-10-17",
    Statement: [
      {
        Effect: "Allow",
        Action: [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
          "bedrock:ListInferenceProfiles",
        ],
        Resource: [
          "arn:aws:bedrock:*:*:inference-profile/*",
          "arn:aws:bedrock:*:*:application-inference-profile/*",
          "arn:aws:bedrock:*:*:foundation-model/*",
        ],
      },
      {
        Effect: "Allow",
        Action: "aws-marketplace:ViewSubscriptions",
        Resource: "*",
        Condition: {
          StringEquals: {
            "aws:CalledViaLast": "bedrock.amazonaws.com",
          },
        },
      },
    ],
  }),
});

// --- KMS Key for sops secrets ---

const sopsKey = new aws.kms.Key("dagafonov-remote-dev-sops-key", {
  description: "Encrypts sops secrets for dagafonov remote dev environment",
  tags: { ...defaultTags, Name: "dagafonov-remote-dev-sops" },
});

new aws.kms.Alias("dagafonov-remote-dev-sops-alias", {
  name: "alias/dagafonov-remote-dev-sops",
  targetKeyId: sopsKey.id,
});

new aws.iam.RolePolicy("dagafonov-remote-dev-kms-policy", {
  role: role.name,
  policy: sopsKey.arn.apply((arn) =>
    JSON.stringify({
      Version: "2012-10-17",
      Statement: [
        {
          Effect: "Allow",
          Action: "kms:Decrypt",
          Resource: arn,
        },
      ],
    }),
  ),
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
    { name: "name", values: ["nixos/25.11.*-aarch64-linux"] },
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
      encrypted: true,
      deleteOnTermination: true,
      // Name tag is displayed in the AWS Console.
      tags: { ...defaultTags, Name: "dagafonov-remote-dev-volume" },
    },
    // Name tag is displayed in the AWS Console. Matches NixOS networking.hostName.
    // Team and Explanation tags are required by the org SCP for non-small instance types.
    tags: {
      ...defaultTags,
      Name: "dagafonov-remote-dev-machine",
      Team: "rd-team-espeon",
      Explanation: "Personal remote dev environment for Danil Agafonov",
    },
  },
  { ignoreChanges: ["ami"] },
);

// --- Outputs ---

export const instanceId = instance.id;
export const publicIp = instance.publicIp;
export const amiId = ami.id;
export const sopsKeyArn = sopsKey.arn;
