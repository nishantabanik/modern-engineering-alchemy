# backend config

terraform {
  required_version = "~> 1.5"
  backend "gcs" {
    bucket  = "tf-actions-backend-012"
    prefix  = "terraform/tf-gh-actions"
  }
}

provider "google" {
  #project = ""
}
