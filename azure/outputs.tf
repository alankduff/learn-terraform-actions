output "public_key" {
  description = "Public part of VM SSH key."
  value       = tls_private_key.ssh.public_key_openssh
}

output "private_key_pem" {
  description = "Private part of VM SSH key."
  value       = tls_private_key.ssh.private_key_pem
  sensitive   = true
}

output "vm_name" {
  description = "Virtual machine name."
  value       = azurerm_linux_virtual_machine.vm.name
}

output "rg_name" {
  description = "Resource group name."
  value       = azurerm_resource_group.rg.name
}
