variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
  
}

variable "prefix" {
  description = "Name prefix for all resources"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "Central India"
}

variable "hub_address_space" {
  description = "Hub VNet address space"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "hub_firewall_subnet_prefix" {
  description = "AzureFirewallSubnet prefix in the hub"
  type        = string
  default     = "10.0.1.0/24"
}

variable "hub_shared_subnet_prefix" {
  description = "Optional shared hub subnet prefix"
  type        = string
  default     = "10.0.10.0/24"
}

variable "spokes" {
  description = "Map of spokes: address space(s) and single workload subnet"
  type = map(object({
    address_space = list(string)
    subnet_prefix = string
  }))

  default = {
    spoke1 = {
      address_space = ["10.1.0.0/16"]
      subnet_prefix = "10.1.1.0/24"
    }
    spoke2 = {
      address_space = ["10.2.0.0/16"]
      subnet_prefix = "10.2.1.0/24"
    }
  }
}
