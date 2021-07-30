# Terraform Conditional Trigger
Accepts a boolean condition for whether a new value should be generated. This allows you to provide a `trigger` or `keeper` value that will only change if the `regerate` input variable is set to `true`.

## Notes:
- This module has the same limitations as the [Invicton-Labs/get-state/null](https://registry.terraform.io/modules/Invicton-Labs/get-state/null/latest) module. Namely, only the `s3` and `local` backend types have been tested (others should work though), and if you're using a `local` backend on windows, you must use the `-lock=false` flag on `terraform plan` and `terraform apply`.

## Sample Use Case

### Problem
Consider a case where you want to generate a new random ID for a resource if *and only if* a given input variable is set. With conventional Terraform, there's no way to do this. You might try something like this:
```
variable "regenerate_id" {
  description = "Whether to generate a new random ID."
  type = bool
  default = false
}

resource "random_id" "my_id" {
  keepers = {
    // Try using the input variable as a keeper/trigger?
    regenerate = var.regenerate_id
  }

  byte_length = 8
}
```

But the problem is that the `random_id` will only be re-created when the input variable is *different* than it was on the previous `terraform apply`. We want it to regenerate when provided and set to `true`, and keep the old one when it's not provided or is set to `false`. That is to say, if I run `terraform apply -var="regenerate_id=true"` repeatedly, it should generate a new ID *each time*, and as soon as I run `terraform apply` without that input variable, it should stop generating a new ID.

You might say "OK, well let's generate a new `keeper` value when the input variable is set to `true`, something like this:
```
variable "regenerate_id" {
  description = "Whether to generate a new random ID."
  type = bool
  default = false
}

resource "random_id" "my_id" {
  keepers = {
    // Try using the input variable to determine if a new keeper value should be set?
    regenerate = var.regenerate_id ? uuid() : null
  }

  byte_length = 8
}
```

But here we run into another problem; even though it solves one of our issues (it will generate a new `random_id` each time `terraform apply -var="regenerate_id=true"` is run), it has another problem in that when you try running `terraform apply` without that input variable, the `keeper` value will switch from the previous `uuid()` value to `null`, so it will regenerate again.

This module solves this problem with some serious black magic that involves [reading the existing state file](https://registry.terraform.io/modules/Invicton-Labs/get-state/null/latest) to get the previous `keeper` value so it can be re-used in order to prevent the value from changing when you don't want it to.

### Solution
Use this module to create an ID that only changes when the input `regenerate` boolean parameter is set to `true`:
```
variable "regenerate_id" {
  description = "Whether to generate a new random ID."
  type        = bool
  default     = false
}

module "conditional_trigger" {
  source = "Invicton-Labs/conditional-trigger/null"
  // A new output ID will only be generated when this field is `true`
  regenerate = var.regenerate_id
}

resource "random_id" "my_id" {
  keepers = {
    // Use the module output UUID, which only changes when desired
    regenerate = module.conditional_trigger.uuid
  }

  byte_length = 8
}

output "my_id" {
  value = random_id.my_id.id
}
```

Now let's see what happens when we run it several times:

- Run 1 - `terraform apply`: Since no ID has been generated yet, it creates one
```
 # random_id.my_id will be created
  + resource "random_id" "my_id" {
      + b64_std     = (known after apply)
      + b64_url     = (known after apply)
      + byte_length = 8
      + dec         = (known after apply)
      + hex         = (known after apply)
      + id          = (known after apply)
      + keepers     = (known after apply)
    }

  ...

Plan: 3 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + my_id = (known after apply)

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

...
random_id.my_id: Creating...
random_id.my_id: Creation complete after 0s [id=WnP_u4H7Jwg]

Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

Outputs:

my_id = "WnP_u4H7Jwg"
```

- Run 2 - `terraform apply`: Since an ID has already been generated and the `regenerate_id` input variable is not set to `true`, it does nothing
```
No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration and found no differences, so no
changes are needed.

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

my_id = "WnP_u4H7Jwg"
```

- Run 3 - `terraform apply -var="regenerate_id=true"`: Since we've set the `regenerate_id` input variable to `true`, it will re-create the ID
```
Terraform will perform the following actions:

  # random_id.my_id must be replaced
-/+ resource "random_id" "my_id" {
      ~ b64_std     = "WnP/u4H7Jwg=" -> (known after apply)
      ~ b64_url     = "WnP_u4H7Jwg" -> (known after apply)
      ~ dec         = "6517834266539927304" -> (known after apply)
      ~ hex         = "5a73ffbb81fb2708" -> (known after apply)
      ~ id          = "WnP_u4H7Jwg" -> (known after apply)
      ~ keepers     = {
          - "regenerate" = "40b706c5-600a-5ae2-178c-9a36bd04d5bb"
        } -> (known after apply) # forces replacement
        # (1 unchanged attribute hidden)
    }

  ...

Plan: 2 to add, 0 to change, 2 to destroy.

Changes to Outputs:
  ~ my_id = "WnP_u4H7Jwg" -> (known after apply)

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

random_id.my_id: Destroying... [id=WnP_u4H7Jwg]
random_id.my_id: Destruction complete after 0s
...
random_id.my_id: Creating...
random_id.my_id: Creation complete after 0s [id=OBw2GzuOCrQ]

Apply complete! Resources: 2 added, 0 changed, 2 destroyed.

Outputs:

my_id = "OBw2GzuOCrQ"
```

- Run 4 - `terraform apply -var="regenerate_id=true"`: Since we still have the `regenerate_id` input variable set as `true`, it will re-create the ID **again**
```
Terraform will perform the following actions:

  # random_id.my_id must be replaced
-/+ resource "random_id" "my_id" {
      ~ b64_std     = "OBw2GzuOCrQ=" -> (known after apply)
      ~ b64_url     = "OBw2GzuOCrQ" -> (known after apply)
      ~ dec         = "4043166056063044276" -> (known after apply)
      ~ hex         = "381c361b3b8e0ab4" -> (known after apply)
      ~ id          = "OBw2GzuOCrQ" -> (known after apply)
      ~ keepers     = {
          - "regenerate" = "afab172e-69f9-7bce-d022-3bc8f8c3a990"
        } -> (known after apply) # forces replacement
        # (1 unchanged attribute hidden)
    }

  ...

Plan: 2 to add, 0 to change, 2 to destroy.

Changes to Outputs:
  ~ my_id = "OBw2GzuOCrQ" -> (known after apply)

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

random_id.my_id: Destroying... [id=OBw2GzuOCrQ]
random_id.my_id: Destruction complete after 0s
...
random_id.my_id: Creating...
random_id.my_id: Creation complete after 0s [id=psuWnKDBsnI]

Apply complete! Resources: 2 added, 0 changed, 2 destroyed.

Outputs:

my_id = "psuWnKDBsnI"
```

- Run 5: `terraform apply`: Since an ID has already been generated and the `regenerate_id` input variable is not set to `true`, it does nothing (even though the input variable's value (`false`) is different than it was on the last apply (`true`))
```
No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration and found no differences, so no
changes are needed.

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

my_id = "psuWnKDBsnI"
```