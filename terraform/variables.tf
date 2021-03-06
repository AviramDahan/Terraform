variable "location" {
  description = "Region to build into"
  default     = "westeurope"

}


variable "resource_group_name" {
  type        = string
  description = "Resource group name"
  default     = "TFResourceGroup"
}

variable "public_vm_size" {
  type        = string
  description = "Vm-Size Config"
  default     = "Standard_B1ls"
}

variable "vnet-cidr" {
  type        = string
  description = "Vnet address space(CIDR)"
  default     = "16.0.0.0/16"
}



variable "subnet_name" {
  default = ["Public-Subnet", "Private-Subnet"]
}

variable "subnet_prefix" {
  default = ["16.0.0.0/22", "16.0.4.0/22"]
}


variable "admin_username" {
  type        = string
  description = "Administrator user name for virtual machine"
}

variable "admin_password" {
  type        = string
  description = "Password must meet Azure complexity requirements"
}

variable "my_ip" {
   type = string
   description = "ip user"
}
