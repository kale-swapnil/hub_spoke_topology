terraform {
  required_version = ">= 1.4.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.80.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# -------------------------
# Resource group
# -------------------------
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = var.location
}

# -------------------------
# Hub VNet + subnets
# -------------------------
resource "azurerm_virtual_network" "hub" {
  name                = "${var.prefix}-hub-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = var.hub_address_space
}

# Azure Firewall requires a subnet named AzureFirewallSubnet
resource "azurerm_subnet" "azurefirewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.hub_firewall_subnet_prefix]
}

# Optional shared hub subnet
resource "azurerm_subnet" "hub_shared" {
  name                 = "hub-shared"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.hub_shared_subnet_prefix]
}

# -------------------------
# Spoke VNets + subnets
# -------------------------
resource "azurerm_virtual_network" "spoke" {
  for_each            = var.spokes
  name                = "${var.prefix}-${each.key}-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = each.value.address_space
}

resource "azurerm_subnet" "spoke_subnet" {
  for_each             = var.spokes
  name                 = "workload"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.spoke[each.key].name
  address_prefixes     = [each.value.subnet_prefix]
}

# -------------------------
# Azure Firewall + Public IP
# -------------------------
resource "azurerm_public_ip" "afw_pip" {
  name                = "${var.prefix}-afw-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall" "afw" {
  name                = "${var.prefix}-afw"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.azurefirewall.id
    public_ip_address_id = azurerm_public_ip.afw_pip.id
  }
}

# -------------------------
# Route table for spokes (default route to Firewall)
# -------------------------
resource "azurerm_route_table" "spokes_rt" {
  name                          = "${var.prefix}-spokes-rt"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  #disable_bgp_route_propagation = false
}

resource "azurerm_route" "default_to_fw" {
  name                   = "default-to-firewall"
  resource_group_name    = azurerm_resource_group.rg.name
  route_table_name       = azurerm_route_table.spokes_rt.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.afw.ip_configuration[0].private_ip_address
}

resource "azurerm_subnet_route_table_association" "spoke_assoc" {
  for_each       = azurerm_subnet.spoke_subnet
  subnet_id      = each.value.id
  route_table_id = azurerm_route_table.spokes_rt.id
}

# -------------------------
# VNet peerings (Hub <-> Spokes)
# -------------------------
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  for_each                     = azurerm_virtual_network.spoke
  name                         = "${var.prefix}-${each.key}-to-hub"
  resource_group_name          = azurerm_resource_group.rg.name
  virtual_network_name         = each.value.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  for_each                     = azurerm_virtual_network.spoke
  name                         = "${var.prefix}-hub-to-${each.key}"
  resource_group_name          = azurerm_resource_group.rg.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = each.value.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
}

# -------------------------
# Firewall rules (basic egress + spoke-to-spoke + DNS)
# -------------------------

# Sources = all spoke subnets
locals {
  spoke_source_prefixes = [for s in azurerm_subnet.spoke_subnet : s.address_prefixes[0]]
}

# Allow spoke-to-Internet web traffic (HTTP/HTTPS)
resource "azurerm_firewall_network_rule_collection" "egress_web" {
  name                = "egress-web"
  azure_firewall_name = azurerm_firewall.afw.name
  resource_group_name = azurerm_resource_group.rg.name
  priority            = 100
  action              = "Allow"

  rule {
    name                  = "allow-http-https"
    source_addresses      = local.spoke_source_prefixes
    destination_addresses = ["*"]
    protocols             = ["TCP"]
    destination_ports     = ["80", "443"]
  }
}

# Allow DNS to Azure DNS (168.63.129.16) so VMs can resolve names
resource "azurerm_firewall_network_rule_collection" "dns" {
  name                = "dns"
  azure_firewall_name = azurerm_firewall.afw.name
  resource_group_name = azurerm_resource_group.rg.name
  priority            = 110
  action              = "Allow"

  rule {
    name                  = "allow-azure-dns"
    source_addresses      = local.spoke_source_prefixes
    destination_addresses = ["168.63.129.16"]
    protocols             = ["UDP", "TCP"]
    destination_ports     = ["53"]
  }
}

# Allow spoke-to-spoke east-west traffic via firewall
resource "azurerm_firewall_network_rule_collection" "east_west" {
  name                = "east-west"
  azure_firewall_name = azurerm_firewall.afw.name
  resource_group_name = azurerm_resource_group.rg.name
  priority            = 120
  action              = "Allow"

  rule {
    name                  = "allow-spoke-to-spoke"
    source_addresses      = local.spoke_source_prefixes
    destination_addresses = local.spoke_source_prefixes
    protocols             = ["TCP", "UDP", "ICMP"]
    destination_ports     = ["*"]
  }
}
