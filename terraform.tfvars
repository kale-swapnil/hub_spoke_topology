prefix   = "hubspoke"
location = "Central India"

hub_address_space          = ["10.0.0.0/16"]
hub_firewall_subnet_prefix = "10.0.1.0/24"
hub_shared_subnet_prefix   = "10.0.10.0/24"

spokes = {
  spoke1 = {
    address_space = ["10.1.0.0/16"]
    subnet_prefix = "10.1.1.0/24"
  }
  spoke2 = {
    address_space = ["10.2.0.0/16"]
    subnet_prefix = "10.2.1.0/24"
  }
}

subscription_id = ""