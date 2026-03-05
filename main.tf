terraform {
  required_providers {
    azurerm = {
      source  = "opentofu/azurerm"
    }
    random = {
      source = "opentofu/random"
    }
    tls = {
      source = "opentofu/tls"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = "rg-aquuks-k0s"
  location = var.location
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-k0s"
  address_space       = ["10.0.0.0/16","fd00::/8"]

  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "main" {
  name                 = "snet-k0s"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24", "fd00:0:0:1::/64"]
}

resource "azurerm_subnet" "cloudshell" {
  name                 = "snet-cloudshell"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24", "fd00:0:0:2::/64"]
}


resource "azurerm_network_security_group" "main" { 
  name = "nsg-vnet-k0s" 
  location = azurerm_resource_group.main.location 
  resource_group_name = azurerm_resource_group.main.name 
  security_rule { 
    name = "Allow-SSH" 
    priority = 100 
    direction = "Inbound" 
    access = "Allow" 
    protocol = "Tcp" 
    source_port_range = "*" 
    destination_port_range = "22" 
    source_address_prefixes = ["145.40.146.231"]
    destination_address_prefix = "*" 
  } 
    security_rule { 
    name = "Allow-SSH2" 
    priority = 101 
    direction = "Inbound" 
    access = "Allow" 
    protocol = "Tcp" 
    source_port_range = "*" 
    destination_port_range = "22" 
    source_address_prefixes = ["2a0e:cb01:14c:a500::/64"]
    destination_address_prefix = "*" 
  } 
  security_rule { 
    name = "Allow-HTTPS" 
    priority = 110 
    direction = "Inbound" 
    access = "Allow" 
    protocol = "Tcp" 
    source_port_range = "*" 
    destination_port_range = "443" 
    source_address_prefixes = ["145.40.146.231"]
    destination_address_prefix = "*" 
  }
    security_rule { 
    name = "Allow-HTTPS2" 
    priority = 111 
    direction = "Inbound" 
    access = "Allow" 
    protocol = "Tcp" 
    source_port_range = "*" 
    destination_port_range = "443" 
    source_address_prefixes = ["2a0e:cb01:14c:a500::/64"]
    destination_address_prefix = "*" 
  }
}

resource "azurerm_subnet_network_security_group_association" "main" { 
  subnet_id = azurerm_subnet.main.id 
  network_security_group_id = azurerm_network_security_group.main.id 
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_ssh_public_key" "main" {
  name                = "ssh-key"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  public_key          = tls_private_key.ssh_key.public_key_openssh
}

resource "azurerm_network_interface" "main" {
  count               = 3
  name                = "nic-vm-${count.index}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.${10 + count.index}"
    public_ip_address_id          = azurerm_public_ip.main[count.index].id
  }

  ip_configuration {
    name                          = "ipv6"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Static"
    private_ip_address_version    = "IPv6"
    private_ip_address            = "fd00:0:0:1::${10 + count.index}"
    public_ip_address_id          = azurerm_public_ip.main_ipv6[count.index].id
  }
}

resource "azurerm_public_ip" "main" {
  count               = 3
  name                = "pip-vm-${count.index}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = [count.index + 1]
}

resource "azurerm_public_ip" "main_ipv6" {
  count               = 3
  name                = "pip-vm-${count.index}-ipv6"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  allocation_method   = "Static"
  sku                 = "Standard"

  ip_version          = "IPv6"

  # If your region supports IPv6 zones, keep this.
  # If you get an error, remove the zones line.
  zones               = [count.index + 1]
}

resource "azurerm_linux_virtual_machine" "main" {
  count                 = 3
  name                  = "k0s-${count.index}"
  resource_group_name   = azurerm_resource_group.main.name
  location              = azurerm_resource_group.main.location
  size                  = "Standard_B1s"
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.main[count.index].id]
  zone                  = count.index + 1

  admin_ssh_key {
    username   = "adminuser"
    public_key = azurerm_ssh_public_key.main.public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "Debian"
    offer     = "debian-13"
    sku       = "13-gen2"
    version   = "latest"
  }

  custom_data = base64encode(file("${path.module}/${count.index == 0 ? "script-0.sh" : "script.sh"}"))
}

resource "random_string" "storage_account_name" {
  length  = 10
  special = false
  upper   = false
}

resource "azurerm_storage_account" "main" {
  name                     = "stk0s${random_string.storage_account_name.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

resource "azurerm_storage_share" "main" {
  name                 = "cloudshell"
  storage_account_name = azurerm_storage_account.main.name
  quota                = 50
}

resource "azurerm_network_profile" "main" {
  name                = "np-cloudshell"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  
  container_network_interface {
    name = "cloudshell-nic"

    ip_configuration {
      name      = "cloudshell-ipconfig"
      subnet_id = azurerm_subnet.cloudshell.id
    }
  }
}

resource "azurerm_relay_namespace" "main" {
  name                = "rns-aquuks-clsh"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "Standard"
}

resource "azurerm_relay_hybrid_connection" "main" {
  name                = "cloudshell-hybrid"
  relay_namespace_name = azurerm_relay_namespace.main.name
  resource_group_name  = azurerm_resource_group.main.name
}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "main" {
  count              = 3
  virtual_machine_id = azurerm_linux_virtual_machine.main[count.index].id
  location           = azurerm_resource_group.main.location
  enabled            = true

  daily_recurrence_time = "0000"
  timezone              = "UTC"

  notification_settings {
    enabled = false
  }
}

resource "azurerm_lb" "control_plane" {
  name                = "lb-k0s-control-plane"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"

 frontend_ip_configuration {
    name                          = "internal-frontend-ipv4"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.9"
  }

 frontend_ip_configuration {
    name                          = "internal-frontend-ipv6"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Static"
    private_ip_address_version    = "IPv6"
    private_ip_address            = "fd00:0:0:1::9"
  }
}

resource "azurerm_lb_backend_address_pool" "control_plane" {
  loadbalancer_id = azurerm_lb.control_plane.id
  name            = "bep-k0s-control-plane"
}

resource "azurerm_lb_backend_address_pool" "control_plane_v6" {
  loadbalancer_id = azurerm_lb.control_plane.id
  name            = "bep-k0s-control-plane-v6"
}

resource "azurerm_lb_probe" "control_plane" {
 loadbalancer_id = azurerm_lb.control_plane.id
 name            = "probe-k0s-api"
 port            = 6443
 protocol        = "Tcp"
}

resource "azurerm_lb_probe" "control_plane_v6" {
 loadbalancer_id = azurerm_lb.control_plane.id
 name            = "probe-k0s-api-v6"
 port            = 6443
 protocol        = "Tcp"
}

resource "azurerm_lb_rule" "control_plane_ipv4" {
  loadbalancer_id                = azurerm_lb.control_plane.id
  name                           = "rule-k0s-api-ipv4"
  protocol                       = "Tcp"
  frontend_port                  = 6443
  backend_port                   = 6443
  frontend_ip_configuration_name = "internal-frontend-ipv4"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.control_plane.id]
  probe_id                       = azurerm_lb_probe.control_plane.id
}

resource "azurerm_lb_rule" "control_plane_ipv6" {
  loadbalancer_id                = azurerm_lb.control_plane.id
  name                           = "rule-k0s-api-ipv6"
  protocol                       = "Tcp"
  frontend_port                  = 6443
  backend_port                   = 6443
  frontend_ip_configuration_name = "internal-frontend-ipv6"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.control_plane_v6.id]
  probe_id                       = azurerm_lb_probe.control_plane_v6.id
}

resource "azurerm_network_interface_backend_address_pool_association" "main" {
  count                   = 3
  network_interface_id    = azurerm_network_interface.main[count.index].id
  ip_configuration_name   = "ipconfig"
  backend_address_pool_id = azurerm_lb_backend_address_pool.control_plane.id
}

resource "azurerm_network_interface_backend_address_pool_association" "main_ipv6" {
  count                   = 3
  network_interface_id    = azurerm_network_interface.main[count.index].id
  ip_configuration_name   = "ipv6"
  backend_address_pool_id = azurerm_lb_backend_address_pool.control_plane_v6.id
}