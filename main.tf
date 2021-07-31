terraform {
  required_version = ">= 0.13.0"
}

module "state" {
  source  = "Invicton-Labs/get-state/null"
  version = "0.2.1"
}

// A unique ID for this module
resource "random_uuid" "module_id" {}

// A unique ID to output
resource "random_uuid" "output_id" {
  keepers = {
    "___CONDITIONAL_TRIGGER_module_id" = random_uuid.module_id.id
    "key"                              = local.new_keeper
  }
}

locals {
  existing_resources = [
    for address, resource in module.state.resources :
    resource
    if resource.type == "random_uuid" && resource.name == "output_id" ? lookup(resource.instances[0].attributes.keepers, "___CONDITIONAL_TRIGGER_module_id", null) == random_uuid.module_id.id : false
  ]
  existing_keeper = length(local.existing_resources) > 0 ? local.existing_resources[0].instances[0].attributes.keepers.key : null
  new_keeper      = var.regenerate ? uuid() : (local.existing_keeper == null ? uuid() : local.existing_keeper)
}
