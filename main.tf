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

resource "random_string" "rg_name" {
  length           = 5
  special          = true
  override_special = "/@£$"
}

resource "azurerm_resource_group" "main" {
  name     = join("",["rg-aqu" , random_string.rg_name.id])
  location = var.location
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-k0s"
  # address_space       = ["10.0.0.0/16","fd00::/8"]
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "main" {
  name                 = "snet-k0s"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  # address_prefixes     = ["10.0.1.0/24", "fd00:0:0:1:/64"]
  address_prefixes = ["10.0.1.0/24"]
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
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main[count.index].id
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
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Debian"
    offer     = "debian-13"
    sku       = "13-gen2"
    version   = "latest"
  }
}
