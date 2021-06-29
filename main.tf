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
  branch              = var.branch
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
        - curl -L -o hugo.deb https://github.com/gohugoio/hugo/releases/download/v0.74.3/hugo_0.74.3_Linux-64bit.deb
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
  branch              = var.branch
  file                = "config.toml"
  content             = <<-EOF
    baseurl = "${module.codepipeline.site_url}"
    contentdir    = "content"
    layoutdir     = "layouts"
    publishdir    = "public"
    title = "Beautiful Hugo"
    canonifyurls  = true
    
    DefaultContentLanguage = "en"
    theme = "${var.theme}"
    metaDataFormat = "yaml"
    pygmentsUseClasses = true
    pygmentCodeFences = true
    
    [Params]
      subtitle = "Hugo Blog Template for GitLab Pages"
      logo = "img/avatar-icon.png"
      favicon = "img/favicon.ico"
      dateFormat = "January 2, 2006"
      commit = false
      rss = true
      comments = true
    
    [Author]
      name = "Some Person"
      email = "youremail@domain.com"
      facebook = "username"
      googleplus = "+username" # or xxxxxxxxxxxxxxxxxxxxx
      gitlab = "username"
      github = "username"
      twitter = "username"
      reddit = "username"
      linkedin = "username"
      xing = "username"
      stackoverflow = "users/XXXXXXX/username"
      snapchat = "username"
      instagram = "username"
      youtube = "user/username" # or channel/channelname
      soundcloud = "username"
      spotify = "username"
      bandcamp = "username"
      itchio = "username"
      keybase = "username"
    
    
    [[menu.main]]
        name = "Blog"
        url = ""
        weight = 1
    
    [[menu.main]]
        name = "About"
        url = "page/about/"
        weight = 3
    
    [[menu.main]]
        identifier = "samples"
        name = "Samples"
        weight = 2
    
    [[menu.main]]
        parent = "samples"
        name = "Big Image Sample"
        url = "post/2017-03-07-bigimg-sample"
        weight = 1
    
    [[menu.main]]
        parent = "samples"
        name = "Math Sample"
        url = "post/2017-03-05-math-sample"
        weight = 2
    
    [[menu.main]]
        parent = "samples"
        name = "Code Sample"
        url = "post/2016-03-08-code-sample"
        weight = 3
    
    [[menu.main]]
        name = "Tags"
        url = "tags"
        weight = 3
  EOF
  commit_message      = "Adjusting site URL and theme in config.toml from Terraform"
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
