provider "azurerm" {
  features {}
}

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-mvm"
    storage_account_name = "stafortfstate"
    container_name       = "tfstatefile1"
    key                  = "abc.terraform.tfstate"
  }
}

variable "resource_group" {
  default = "rgnew"
}

variable "region" {
  default = "centralus"
}

variable "virtual_network" {
  default = "myvnet"
}

#RG
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group
  location = var.region
}

#VNet
resource "azurerm_virtual_network" "vnet" {
  name                = var.virtual_network
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["192.168.0.0/16", "172.16.0.0/16", "10.0.0.0/8"]
}

#Subnet
resource "azurerm_subnet" "subnet1" {
  name                 = "${var.virtual_network}_int_172.16.0.0"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["172.16.0.0/24"]
}

resource "azurerm_public_ip" "cedge41_publicip" {
  name                = "${var.virtual_network}-cedge-publicip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
}

#cEdge41
resource "azurerm_network_interface" "cedge41_int_nic" {
  name                = "${var.virtual_network}-cedge-int_172.16.0.41"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name                          = "${var.virtual_network}-cedge-int_172.16.0.41"
    subnet_id                     = azurerm_subnet.subnet1.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "172.16.0.41"
    public_ip_address_id          = azurerm_public_ip.cedge41_publicip.id
  }
}

resource "azurerm_linux_virtual_machine" "cedge41" {
  name                = "${var.virtual_network}-cEdge41"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2s"
  network_interface_ids = [
    azurerm_network_interface.cedge41_int_nic.id
  ]
  source_image_reference {
    publisher = "cisco"
    offer     = "cisco-csr-1000v"
    sku       = "17_3_2-byol"
    version   = "latest"
  }
  plan {
    name      = "17_3_2-byol"
    product   = "cisco-csr-1000v"
    publisher = "cisco"
  }
  admin_username                  = "netadmin"
  admin_password                  = "C1sco!234$"
  computer_name                   = "Cvedge41"
  disable_password_authentication = false
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}

#Get-AzureRmMarketplaceTerms -Publisher "cisco" -Product "cisco-csr-1000v" -Name "17_3_2-byol" | Set-AzureRmMarketplaceTerms -Accept