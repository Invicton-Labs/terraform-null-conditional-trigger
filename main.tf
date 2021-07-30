terraform {
  required_version = ">= 0.13.0"
}

module "backend_config" {
  //source          = "Invicton-Labs/backend-config/null"
  //version         = "0.1.0"
  source          = "../terraform-null-backend-config"
  fetch_raw_state = true
}

// A unique ID for this module
resource "random_uuid" "module_id" {}

// A unique ID to output
resource "random_uuid" "output_id" {
  keepers = {
    "key" = local.new_keeper
  }
}

locals {
  // Wait for the assertion to be checked before reading it
  state_resources = module.backend_config.raw_state != null ? module.backend_config.raw_state.resources : null
  // Find the resource we created with the module_id to figure out the name of the module we're in
  module_names = local.state_resources != null ? [
    for resource in local.state_resources :
    resource.module
    if resource.instances[0].attributes.id == random_uuid.module_id.id
  ] : []
  // Check if we found the module_id, and if so, save the module name
  module_name = length(local.module_names) > 0 ? local.module_names[0] : null
  // Find the resource for the output_id that has this module name and the proper resource name
  existing_resources = local.module_name == null ? [] : [
    for resource in local.state_resources :
    resource
    if lookup(resource, "module", "") == local.module_name && resource.type == "random_uuid" && resource.name == "output_id"
  ]
  // Check if we found a resource for this module, and if so, extract the keeper used last time
  existing_keeper = length(local.existing_resources) > 0 ? local.existing_resources[0].instances[0].attributes.keepers.key : null
  new_keeper      = var.regenerate || local.existing_keeper == null ? uuid() : local.existing_keeper
}
