resource "aws_codepipeline" "codepipeline" {
  name     = "blog-pipeline"
  role_arn = "${aws_iam_role.codepipeline_role.arn}"
  tags     = {}
  tags_all = {}

  artifact_store {
    location = "${aws_s3_bucket.codepipeline_bucket.bucket}"
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      category = "Source"
      configuration = {
        "Branch"               = var.branch
        "OAuthToken"           = var.oauthtoken
        "Owner"                = var.owner
        "PollForSourceChanges" = "false"
        "Repo"                 = var.repo
      }
      input_artifacts = []
      name            = "Source"
      namespace       = "SourceVariables"
      output_artifacts = [
        "SourceArtifact",
      ]
      owner     = "ThirdParty"
      provider  = "GitHub"
      region    = var.region
      run_order = 1
      version   = "1"
    }
  }
  stage {
    name = "Build"

    action {
      category = "Build"
      configuration = {
        "ProjectName" = var.project_name
      }
      input_artifacts = [
        "SourceArtifact",
      ]
      name      = "Build"
      namespace = "BuildVariables"
      output_artifacts = [
        "BuildArtifact",
      ]
      owner     = "AWS"
      provider  = "CodeBuild"
      region    = var.region
      run_order = 1
      version   = "1"
    }
  }
  stage {
    name = "Deploy"

    action {
      category = "Deploy"
      configuration = {
        "BucketName" = "${aws_s3_bucket.hosting_bucket.bucket}"
        "Extract"    = "true"
      }
      input_artifacts = [
        "BuildArtifact",
      ]
      name             = "Deploy"
      namespace        = "DeployVariables"
      output_artifacts = []
      owner            = "AWS"
      provider         = "S3"
      region           = var.region
      run_order        = 1
      version          = "1"
    }
  }
}

resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket        = var.pipeline_bucket_name
  request_payer = "BucketOwner"
  acl           = "private"
  force_destroy = true
  versioning {
    enabled    = false
    mfa_delete = false
  }
}

resource "aws_s3_bucket" "hosting_bucket" {
  bucket           = var.hosting_bucket_name
  request_payer    = "BucketOwner"
  tags             = {}
  tags_all         = {}
  acl              = "private"
  force_destroy    = true
  versioning {
    enabled    = false
    mfa_delete = false
  }
  website {
    error_document = var.error_document
    index_document = var.index_document
  }
}

resource "aws_s3_bucket_policy" "hosting_bucket" {
  bucket = aws_s3_bucket.hosting_bucket.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "PublicReadGetObject",
        "Effect" : "Allow",
        "Principal" : "*",
        "Action" : "s3:GetObject",
        "Resource" : "${aws_s3_bucket.hosting_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role" "codepipeline_role" {
  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "codepipeline.amazonaws.com"
          }
        },
      ]
      Version = "2012-10-17"
    }
  )
  force_detach_policies = false
  name                  = var.codepipeline_role_name
  path                  = "/service-role/"
  tags                  = {}
  tags_all              = {}

}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = var.codepipeline_policy_name
  role = aws_iam_role.codepipeline_role.id

  policy = <<-EOF
  {
      "Statement": [
          {
              "Action": [
                  "iam:PassRole"
              ],
              "Resource": "*",
              "Effect": "Allow",
              "Condition": {
                  "StringEqualsIfExists": {
                      "iam:PassedToService": [
                          "cloudformation.amazonaws.com",
                          "elasticbeanstalk.amazonaws.com",
                          "ec2.amazonaws.com",
                          "ecs-tasks.amazonaws.com"
                      ]
                  }
              }
          },
          {
              "Action": [
                  "codecommit:CancelUploadArchive",
                  "codecommit:GetBranch",
                  "codecommit:GetCommit",
                  "codecommit:GetRepository",
                  "codecommit:GetUploadArchiveStatus",
                  "codecommit:UploadArchive"
              ],
              "Resource": "*",
              "Effect": "Allow"
          },
          {
              "Action": [
                  "codedeploy:CreateDeployment",
                  "codedeploy:GetApplication",
                  "codedeploy:GetApplicationRevision",
                  "codedeploy:GetDeployment",
                  "codedeploy:GetDeploymentConfig",
                  "codedeploy:RegisterApplicationRevision"
              ],
              "Resource": "*",
              "Effect": "Allow"
          },
          {
              "Action": [
                  "codestar-connections:UseConnection"
              ],
              "Resource": "*",
              "Effect": "Allow"
          },
          {
              "Action": [
                  "elasticbeanstalk:*",
                  "ec2:*",
                  "elasticloadbalancing:*",
                  "autoscaling:*",
                  "cloudwatch:*",
                  "s3:*",
                  "sns:*",
                  "cloudformation:*",
                  "rds:*",
                  "sqs:*",
                  "ecs:*"
              ],
              "Resource": "*",
              "Effect": "Allow"
          },
          {
              "Action": [
                  "lambda:InvokeFunction",
                  "lambda:ListFunctions"
              ],
              "Resource": "*",
              "Effect": "Allow"
          },
          {
              "Action": [
                  "opsworks:CreateDeployment",
                  "opsworks:DescribeApps",
                  "opsworks:DescribeCommands",
                  "opsworks:DescribeDeployments",
                  "opsworks:DescribeInstances",
                  "opsworks:DescribeStacks",
                  "opsworks:UpdateApp",
                  "opsworks:UpdateStack"
              ],
              "Resource": "*",
              "Effect": "Allow"
          },
          {
              "Action": [
                  "cloudformation:CreateStack",
                  "cloudformation:DeleteStack",
                  "cloudformation:DescribeStacks",
                  "cloudformation:UpdateStack",
                  "cloudformation:CreateChangeSet",
                  "cloudformation:DeleteChangeSet",
                  "cloudformation:DescribeChangeSet",
                  "cloudformation:ExecuteChangeSet",
                  "cloudformation:SetStackPolicy",
                  "cloudformation:ValidateTemplate"
              ],
              "Resource": "*",
              "Effect": "Allow"
          },
          {
              "Action": [
                  "codebuild:BatchGetBuilds",
                  "codebuild:StartBuild",
                  "codebuild:BatchGetBuildBatches",
                  "codebuild:StartBuildBatch"
              ],
              "Resource": "*",
              "Effect": "Allow"
          },
          {
              "Effect": "Allow",
              "Action": [
                  "devicefarm:ListProjects",
                  "devicefarm:ListDevicePools",
                  "devicefarm:GetRun",
                  "devicefarm:GetUpload",
                  "devicefarm:CreateUpload",
                  "devicefarm:ScheduleRun"
              ],
              "Resource": "*"
          },
          {
              "Effect": "Allow",
              "Action": [
                  "servicecatalog:ListProvisioningArtifacts",
                  "servicecatalog:CreateProvisioningArtifact",
                  "servicecatalog:DescribeProvisioningArtifact",
                  "servicecatalog:DeleteProvisioningArtifact",
                  "servicecatalog:UpdateProduct"
              ],
              "Resource": "*"
          },
          {
              "Effect": "Allow",
              "Action": [
                  "cloudformation:ValidateTemplate"
              ],
              "Resource": "*"
          },
          {
              "Effect": "Allow",
              "Action": [
                  "ecr:DescribeImages"
              ],
              "Resource": "*"
          },
          {
              "Effect": "Allow",
              "Action": [
                  "states:DescribeExecution",
                  "states:DescribeStateMachine",
                  "states:StartExecution"
              ],
              "Resource": "*"
          },
          {
              "Effect": "Allow",
              "Action": [
                  "appconfig:StartDeployment",
                  "appconfig:StopDeployment",
                  "appconfig:GetDeployment"
              ],
              "Resource": "*"
          }
      ],
      "Version": "2012-10-17"
  }
EOF
}

data "aws_caller_identity" "current" {}

data "aws_kms_alias" "codebuild_encryption_key" {
   name = "alias/aws/s3"
}

resource "aws_codebuild_project" "build-project" {
    badge_enabled          = false
    build_timeout          = 60
    concurrent_build_limit = 1
    encryption_key         = "${data.aws_kms_alias.codebuild_encryption_key.arn}"
    name                   = "blog"
    queued_timeout         = 480
    service_role           = "${aws_iam_role.codebuild_role.arn}"
    tags                   = {}
    tags_all               = {}

    artifacts {
        encryption_disabled    = false
        name                   = var.project_name
        override_artifact_name = false
        packaging              = "NONE"
        type                   = "CODEPIPELINE"
    }

    cache {
        modes = []
        type  = "NO_CACHE"
    }

    environment {
        compute_type                = "BUILD_GENERAL1_SMALL"
        image                       = "aws/codebuild/standard:4.0"
        image_pull_credentials_type = "CODEBUILD"
        privileged_mode             = false
        type                        = "LINUX_CONTAINER"
    }

    logs_config {
        cloudwatch_logs {
            status = "DISABLED"
        }

        s3_logs {
            encryption_disabled = false
            status              = "DISABLED"
        }
    }

    source {
        git_clone_depth     = 0
        insecure_ssl        = false
        report_build_status = false
        type                = "CODEPIPELINE"
    }
}

resource "aws_iam_role" "codebuild_role" {
    assume_role_policy    = jsonencode(
        {
            Statement = [
                {
                    Action    = "sts:AssumeRole"
                    Effect    = "Allow"
                    Principal = {
                        Service = "codebuild.amazonaws.com"
                    }
                },
            ]
            Version   = "2012-10-17"
        }
    )
    force_detach_policies = false
    max_session_duration  = 3600
    name                  = var.codebuild_role_name
    path                  = "/service-role/"
    tags                  = {}
    tags_all              = {}
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name = "CodeBuildBasePolicy-blog-us-west-2"
  role = aws_iam_role.codebuild_role.id

  policy = <<-EOF
  {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Effect": "Allow",
              "Resource": [
                  "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${var.project_name}",
                  "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${var.project_name}:*"
              ],
              "Action": [
                  "logs:CreateLogGroup",
                  "logs:CreateLogStream",
                  "logs:PutLogEvents"
              ]
          },
          {
              "Effect": "Allow",
              "Resource": [
                  "arn:aws:s3:::codepipeline-${var.region}-*"
              ],
              "Action": [
                  "s3:PutObject",
                  "s3:GetObject",
                  "s3:GetObjectVersion",
                  "s3:GetBucketAcl",
                  "s3:GetBucketLocation"
              ]
          },
          {
              "Effect": "Allow",
              "Action": [
                  "codebuild:CreateReportGroup",
                  "codebuild:CreateReport",
                  "codebuild:UpdateReport",
                  "codebuild:BatchPutTestCases",
                  "codebuild:BatchPutCodeCoverages"
              ],
              "Resource": [
                  "arn:aws:codebuild:${var.region}:${data.aws_caller_identity.current.account_id}:report-group/${var.project_name}-*"
              ]
          }
      ]
  }
EOF
}
