terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.65"
    }
  }

  required_version = ">= 0.14.9"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "vmscale" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "random_string" "fqdn" {
  length  = 6
  special = false
  upper   = false
  number  = false
}

resource "azurerm_virtual_network" "vmscale" {
  name                = "vmscale-vnet"
  address_space       = ["16.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.vmscale.name
  tags                = var.tags
}

resource "azurerm_subnet" "vmscale" {
  name                 = "vmscale-subnet"
  resource_group_name  = azurerm_resource_group.vmscale.name
  virtual_network_name = azurerm_virtual_network.vmscale.name
  address_prefixes     = ["16.0.0.0/22"]
}

resource "azurerm_public_ip" "vmscale" {
  name                = "vmscale-public-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.vmscale.name
  allocation_method   = "Static"
  domain_name_label   = random_string.fqdn.result
  tags                = var.tags
}

resource "azurerm_lb" "vmscale" {
  name                = "vmscale-lb"
  location            = var.location
  resource_group_name = azurerm_resource_group.vmscale.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.vmscale.id
  }

  tags = var.tags
}

resource "azurerm_lb_backend_address_pool" "bpepool" {
  loadbalancer_id = azurerm_lb.vmscale.id
  name            = "BackEndAddressPool"
}

resource "azurerm_lb_probe" "vmscale" {
  resource_group_name = azurerm_resource_group.vmscale.name
  loadbalancer_id     = azurerm_lb.vmscale.id
  name                = "ssh-running-probe"
  port                = var.application_port
}

resource "azurerm_lb_rule" "lbnatrule" {
  resource_group_name            = azurerm_resource_group.vmscale.name
  loadbalancer_id                = azurerm_lb.vmscale.id
  name                           = "http"
  protocol                       = "Tcp"
  frontend_port                  = var.application_port
  backend_port                   = var.application_port
  backend_address_pool_id        = azurerm_lb_backend_address_pool.bpepool.id
  frontend_ip_configuration_name = "PublicIPAddress"
  probe_id                       = azurerm_lb_probe.vmscale.id
}

resource "azurerm_virtual_machine_scale_set" "vmscale" {
  name                = "vmscaleset"
  location            = var.location
  resource_group_name = azurerm_resource_group.vmscale.name
  upgrade_policy_mode = "Manual"

  sku {
    name     = "Standard_B1ls"
    tier     = "Standard"
    capacity = 2
  }

  storage_profile_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_profile_os_disk {
    name              = ""
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_profile_data_disk {
    lun           = 0
    caching       = "ReadWrite"
    create_option = "Empty"
    disk_size_gb  = 10
  }

  os_profile {
    computer_name_prefix = "vmlab"
    admin_username       = var.admin_user
    admin_password       = var.admin_password

  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  network_profile {
    name    = "terraformnetworkprofile"
    primary = true

    ip_configuration {
      name                                   = "IPConfiguration"
      subnet_id                              = azurerm_subnet.vmscale.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.bpepool.id]
      primary                                = true
    }
  }

  tags = var.tags
}

resource "azurerm_public_ip" "scale_set" {
  name                = "scale_set-public-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.vmscale.name
  allocation_method   = "Static"
  domain_name_label   = "${random_string.fqdn.result}-ssh"
  tags                = var.tags
}

resource "azurerm_network_interface" "scale_set" {
  name                = "scale_set-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.vmscale.name

  ip_configuration {
    name                          = "IPConfiguration"
    subnet_id                     = azurerm_subnet.vmscale.id
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = azurerm_public_ip.scale_set.id
  }

  tags = var.tags
}

resource "azurerm_virtual_machine" "vm" {
  name                  = "scaleset"
  location              = var.location
  resource_group_name   = azurerm_resource_group.vmscale.name
  network_interface_ids = [azurerm_network_interface.scale_set.id]
  vm_size               = "Standard_B1ls"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "scale_set-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "scaleset"
    admin_username = var.admin_user
    admin_password = var.admin_password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = var.tags
}




#Get ip data
data "azurerm_public_ip" "ip" {
  name                = azurerm_public_ip.vmscale.name
  resource_group_name = var.resource_group_name
  depends_on          = [azurerm_virtual_machine_scale_set.vmscale]

}
#Print public ip
output "public_ip_address" {
  value = data.azurerm_public_ip.ip.ip_address
}