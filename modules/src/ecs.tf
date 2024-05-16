#######ECS関連#######
##　ECSクラスタ
resource "aws_ecs_cluster" "main" {
  name = "ecls-dev-I231-sample"
}

# ECS用セキュリティグループ
resource "aws_security_group" "ecs" {
  name        = "security-group"
  description = "handson ecs"

  vpc_id = data.aws_vpc.vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "security-group"
  }
}

# ECS用セキュリティグループルール
resource "aws_security_group_rule" "ecs" {
  security_group_id = aws_security_group.ecs.id

  # インターネットからセキュリティグループ内のリソースへのアクセス許可設定
  type = "ingress"

  # TCPでの80ポートへのアクセスを許可する
  from_port = 80
  to_port   = 80
  protocol  = "tcp"

  # 同一VPC内からのアクセスのみ許可
  cidr_blocks = ["10.0.0.0/16"]
}

resource "aws_secretsmanager_secret_version" "github_token" {
  secret_id     = "github_token"
  secret_string = "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"
}

#　タスク定義
resource "aws_ecs_task_definition" "main" {
  family                   = "etsk-dev-I231-soumu"
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.ecs_role.arn
  task_role_arn         =  aws_iam_role.ecs_role.arn
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  

  container_definitions = <<DEFINITION
  [
    {
      "name": "ectr_dev_i231",
      "image": "ghcr.io/yuuking0304/ectr_dev_i231_sample:latest",
      "essential": true,
      "portMappings": [
        {
           "containerPort": 80,
            "hostPort": 80,
            "protocol": "tcp"
        }
        ],
      "runtimePlatform": {
        "cpuArchitecture": "X86_64",
        "operatingSystemFamily": "LINUX"
      },
      "repositoryCredentials": {
        "credentialsParameter": "arn:aws:secretsmanager:ap-northeast-1:471112955196:secret:github_token-C4pPPk"
      },
      "cpu": 256,
      "memory": 512
    }
  ]
  DEFINITION
}

#　タスク実行用ロール
resource "aws_iam_role" "ecs_role" {
  name               = "ecs_role"
  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
      {
          "Sid": "",
          "Effect": "Allow",
          "Principal": {
              "Service": "ecs-tasks.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
      }
  ]
}
  EOF
}

#　deploy実行用ロール
resource "aws_iam_role" "code_deploy_role" {
  name               = "code_deploy_role"
  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "codedeploy.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
  ]
}
  EOF
}

resource "aws_iam_policy_attachment" "ecs_secretsmanager_readwrite" {
  name       = "ecs_secretsmanager_readwrite"
  roles      = [aws_iam_role.ecs_role.name]
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

#　ECSサービス
resource "aws_ecs_service" "main" {
  name            = "esvc-dev-I231"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    assign_public_ip = false
    subnets          = [data.aws_subnet.subnet_a.id, data.aws_subnet.subnet_b.id, data.aws_subnet.subnet_c.id]
    security_groups  = [aws_security_group.ecs.id]
  }
  depends_on = [
    aws_lb.main,
  ]
  load_balancer {
    container_name = "ectr_dev_i231"
    container_port = 80
    target_group_arn = aws_lb_target_group.main.arn
  }
}