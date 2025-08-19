output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "hub_vnet_id" {
  value = azurerm_virtual_network.hub.id
}

output "spoke_vnet_ids" {
  value = { for k, v in azurerm_virtual_network.spoke : k => v.id }
}

output "firewall_public_ip" {
  value = azurerm_public_ip.afw_pip.ip_address
}

output "firewall_private_ip" {
  value = azurerm_firewall.afw.ip_configuration[0].private_ip_address
}
