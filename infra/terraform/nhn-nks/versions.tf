terraform {
  required_version = ">= 1.0.0"

  required_providers {
    nhncloud = {
      source  = "nhn-cloud/nhncloud"
      version = "1.0.8"
    }
  }
}

provider "nhncloud" {
  user_name = var.nhncloud_user_name
  tenant_id = var.nhncloud_tenant_id
  password  = var.nhncloud_api_password
  auth_url  = var.nhncloud_auth_url
  region    = var.nhncloud_region
}
