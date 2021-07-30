output "uuid" {
  description = "The UUID that only changes when either the `regenerate` input variable is set to `true`, or this module is being created for the first time."
  value       = random_uuid.output_id.id
}
