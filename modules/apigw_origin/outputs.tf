output "domain_name" {
	value = replace(aws_api_gateway_deployment.deployment.invoke_url, "/^https?://([^/]*).*/", "$1")
}

output "stage_path" {
	value = "/${aws_api_gateway_deployment.deployment.stage_name}"
}
