terraform {
  backend "remote" {
    organization = "minkimipt"

    workspaces {
      name = "blog"
    }
  }
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 4.0"
    }

    aws = {
      source = "hashicorp/aws"
    }

  }
  required_version = ">=0.14.8"
}

provider "aws" {
  region = var.region
}

provider "github" {
  token        = var.oauthtoken
  owner = var.owner
}

data "github_repository" "blog_repo" {
  full_name = "${var.owner}/${var.repo}"
}

resource "github_repository_file" "buildspec" {
  repository          = data.github_repository.blog_repo.name
  branch              = "main"
  file                = "buildspec.yml"
  content             = <<-EOF
  version: 0.2

  phases:
    install:
      runtime-versions:
        python: 3.8
      commands:
        - apt-get update
        - echo Installing hugo
        - curl -L -o hugo.deb https://github.com/gohugoio/hugo/releases/download/v0.84.1/hugo_0.84.1_Linux-64bit.deb
        - dpkg -i hugo.deb
    pre_build:
      commands:
        - echo In pre_build phase..
        - echo Current directory is $CODEBUILD_SRC_DIR
        - ls -la
    build:
      commands:
        - hugo -v
  artifacts:
    files:
      - '**/*'
    base-directory: public
  EOF
  commit_message      = "Adding buildspec.yml for AWS codepipeline"
  commit_author       = "Terraform User"
  commit_email        = "terraform@example.com"
  overwrite_on_create = true
}

module "codepipeline" {
  source = "app.terraform.io/minkimipt/codepipeline/aws"
  branch = var.branch
  codebuild_role_name = var.codebuild_role_name
  codepipeline_policy_name = var.codepipeline_policy_name
  codepipeline_role_name = var.codepipeline_role_name
  error_document = var.error_document
  hosting_bucket_name = var.hosting_bucket_name
  index_document = var.index_document
  oauthtoken = var.oauthtoken
  owner = var.owner
  pipeline_bucket_name = var.pipeline_bucket_name
  project_name = var.project_name
  region = var.region
  repo = var.repo
}

resource "github_repository_file" "config" {
  repository          = data.github_repository.blog_repo.name
  branch              = "main"
  file                = "config.toml"
  content             = <<-EOF
    languageCode = "en-us"
    title = "Contrail Collateral"
    baseURL = "${module.codepipeline.site_url}"
    canonifyURLs = true
    theme = "cupper"
    
    [markup]
      [markup.goldmark]
        [markup.goldmark.renderer]
          unsafe = true
    
    [sitemap]
      changefreq = "monthly"
      filename = "sitemap.xml"
      priority = 0.5
    
    [params]
    description = "Reverse Engineering in Practice"
    
      [params.staticman]
      api = "https://minkimipt-staticman.herokuapp.com/v3/entry/gitlab/minkimipt/blog-comments/master/comments"
      enabled = true
      gitProvider = "gitlab"
      username = "minkimipt-staticman"
    
        [params.staticman.recaptcha]
        sitekey = "6LfNpsgZAAAAALm4RUToqxnT-MppTOsBEsijCxVH"
        secret = "ShsfOjZdwARINBeIRIprzGnbExYNA5LZ5WTT7+M1qmf2r3/HnpkwWvME2qZD0qswPvVNR5qjw26ebQ6pX//Kvu/1vLcQNDiFrjryRiYWCdjLb2hc8iyWyTYEEAm4rDWfUG/xDbwy9kLILxU+xzisgk8DfuGK9b06zlGoWBfYjY/tYLRl6ufHJhYqwa7te9UHTy02KzSqUVa4ASXenGmN9pckS92+bYuv+9rmqbPEKRF5sjZU3tZL2NgbFrDmopOn8tHVux//WMEdZeh4GciPhKTTjbTpKm3jXkjQ4Jya/IP2Hympye4g35ehkFfrdb7OgMu4TwlIAHfPLzE/H+IFKg=="
  EOF
  commit_message      = "Adjusting sit URL in config.toml based on S3 bucket website"
  commit_author       = "Terraform User"
  commit_email        = "terraform@example.com"
  overwrite_on_create = true
}

resource "github_repository_collaborator" "collaborators" {
  repository = data.github_repository.blog_repo.name
  username   = var.collaborators[count.index]
  permission = "push"
  count = length(var.collaborators)
}
