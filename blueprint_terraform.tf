resource "azurerm_resource_group" "underlay1" {
    name = "underlay1"
    location = "East US"
}

//Route Table
//------------------------------------------------------------------------------------------
resource "azurerm_route_table" "underlay1_routetable1" {
    name = "underlay1_routetable1"
    location = "${azurerm_resource_group.underlay1.location}"
    resource_group_name = "${azurerm_resource_group.underlay1.name}"
}

//NSG
//------------------------------------------------------------------------------------------
resource "azurerm_network_security_group" "underlay1_nsg1" {
    name = "underlay1_nsg1"
    location = "${azurerm_resource_group.underlay1.location}"
    resource_group_name = "${azurerm_resource_group.underlay1.name}"
}

resource "azurerm_network_security_rule" "underlay1_nsg1_rule_allow_ssh" {
    name = "underlay1_nsg1_rule_allow_ssh"
    resource_group_name = "${azurerm_resource_group.underlay1.name}"
    network_security_group_name = "${azurerm_network_security_group.underlay1_nsg1.name}"
    priority                    = 105
    direction                   = "Inbound"
    access                      = "Allow"
    protocol                    = "Tcp"
    source_port_range           = "*"
    destination_port_range      = "22-22"
    source_address_prefix       = "*"
    destination_address_prefix  = "*"
}

resource "azurerm_network_security_rule" "underlay1_nsg1_rule_allow_kube_tls" {
    name = "underlay1_nsg1_rule_allow_kube_tls"
    resource_group_name = "${azurerm_resource_group.underlay1.name}"
    network_security_group_name = "${azurerm_network_security_group.underlay1_nsg1.name}"
    priority                    = 104
    direction                   = "Inbound"
    access                      = "Allow"
    protocol                    = "Tcp"
    source_port_range           = "*"
    destination_port_range      = "443-443"
    source_address_prefix       = "*"
    destination_address_prefix  = "*"
}

//Virtual Network
//------------------------------------------------------------------------------------------
resource "azurerm_virtual_network" "underlay1_virtualnetwork1" {
    name = "underlay1_virtualnetwork1"
    resource_group_name = "${azurerm_resource_group.underlay1.name}"
    location = "East US"
    address_space = ["10.0.0.0/8"]
}

resource "azurerm_subnet" "underlay1_mastersubnet" {
    name = "underlay1_mastersubnet"
    resource_group_name = "${azurerm_resource_group.underlay1.name}"
    virtual_network_name = "${azurerm_virtual_network.underlay1_virtualnetwork1.name}"
    address_prefix = "10.240.0.0/16"
    network_security_group_id = "${azurerm_network_security_group.underlay1_nsg1.id}"
    route_table_id = "${azurerm_route_table.underlay1_routetable1.id}"
    depends_on = ["azurerm_route_table.underlay1_routetable1"]
    depends_on = ["azurerm_network_security_group.underlay1_nsg1"]
}

//Internal Load Balancer
//------------------------------------------------------------------------------------------
resource "azurerm_lb" "underlay1_loadbalancer1" {
    name = "underlay1_loadbalancer1"
    resource_group_name = "${azurerm_resource_group.underlay1.name}"
    location = "East US"
    sku = "Basic"

    frontend_ip_configuration {
        name = "underlay1_loadbalancer1_frontend_ip_name"
        private_ip_address = "10.240.255.15"
        private_ip_address_allocation = "Static"
        subnet_id = "${azurerm_subnet.underlay1_mastersubnet.id}"
    }
    depends_on = ["azurerm_virtual_network.underlay1_virtualnetwork1"] 
}

resource "azurerm_lb_rule" "underlay1_loadbalancer1_internalLBRuleHTTPS" {
    name = "underlay1_loadbalancer1_internalLBRuleHTTPS"
    resource_group_name = "${azurerm_resource_group.underlay1.name}"
    loadbalancer_id = "${azurerm_lb.underlay1_loadbalancer1.id}"
    protocol = "Tcp"
    frontend_port = 443
    backend_port = 4443
    idle_timeout_in_minutes = 5 
    enable_floating_ip = false
    backend_address_pool_id = "${azurerm_lb_backend_address_pool.underlay1_loadbalancer1_backend_pool.id}"
    frontend_ip_configuration_name = "underlay1_loadbalancer1_frontend_ip_name"
    probe_id = "${azurerm_lb_probe.underlay1_loadbalancer1_tcpHTTPSproble.id}"
}

resource "azurerm_lb_backend_address_pool" "underlay1_loadbalancer1_backend_pool" {
    name = "underlay1_loadbalancer1_backend_pool"
    resource_group_name = "${azurerm_resource_group.underlay1.name}"
    loadbalancer_id = "${azurerm_lb.underlay1_loadbalancer1.id}"
}

resource "azurerm_lb_probe" "underlay1_loadbalancer1_tcpHTTPSproble" {
    name = "underlay1_loadbalancer1_tcpHTTPSproble"
    resource_group_name = "${azurerm_resource_group.underlay1.name}"
    loadbalancer_id = "${azurerm_lb.underlay1_loadbalancer1.id}"
    port = 4443
    protocol = "Tcp"
    number_of_probes = 2
    interval_in_seconds = 5
}


//Public IP
//------------------------------------------------------------------------------------------

resource "azurerm_public_ip" "underlay1_public_ip" {
    name = "underlay1_public_ip"
    resource_group_name = "${azurerm_resource_group.underlay1.name}"
    sku = "Basic"
    domain_name_label = "underlay1"
    allocation_method = "Static"  
    location = "East US"  
}

//External Load Balancer
//------------------------------------------------------------------------------------------
resource "azurerm_lb" "underlay1_loadbalancer2" {
    name = "underlay1_loadbalancer2"
    resource_group_name = "${azurerm_resource_group.underlay1.name}"
    location = "East US"
    sku = "Basic"

    frontend_ip_configuration {
        name = "underlay1_loadbalancer2_frontend_ip_name"
        public_ip_address_id = "${azurerm_public_ip.underlay1_public_ip.id}"
    }
    depends_on = ["azurerm_public_ip.underlay1_public_ip"] 

}
resource "azurerm_lb_backend_address_pool" "underlay1_loadbalancer2_backend_pool" {
    name = "underlay1_loadbalancer2_backend_pool"
    resource_group_name = "${azurerm_resource_group.underlay1.name}"
    loadbalancer_id = "${azurerm_lb.underlay1_loadbalancer2.id}"
}

resource "azurerm_lb_rule" "underlay1_loadbalancer2_LBRuleHTTPS" {
    name = "underlay1_loadbalancer2_LBRuleHTTPS"
    resource_group_name = "${azurerm_resource_group.underlay1.name}"
    loadbalancer_id = "${azurerm_lb.underlay1_loadbalancer2.id}"
    protocol = "Tcp"
    frontend_port = 443
    backend_port = 443
    idle_timeout_in_minutes = 5 
    enable_floating_ip = false
    load_distribution = "Default"
    backend_address_pool_id = "${azurerm_lb_backend_address_pool.underlay1_loadbalancer2_backend_pool.id}"
    frontend_ip_configuration_name = "underlay1_loadbalancer2_frontend_ip_name"
    probe_id = "${azurerm_lb_probe.underlay1_loadbalancer2_tcpHTTPSprob.id}"
}

resource "azurerm_lb_probe" "underlay1_loadbalancer2_tcpHTTPSprob" {
    name = "underlay1_loadbalancer1_tcpHTTPSprob"
    resource_group_name = "${azurerm_resource_group.underlay1.name}"
    loadbalancer_id = "${azurerm_lb.underlay1_loadbalancer2.id}"
    port = 443
    protocol = "Tcp"
    number_of_probes = 2
    interval_in_seconds = 5
}

//InboundNATRules
//------------------------------------------------------------------------------------------
resource "azurerm_lb_nat_rule" "underlay1_loadbalancer2_NAT_rule1" {
    name = "underlay1_loadbalancer2_NAT_rule1"
    resource_group_name = "${azurerm_resource_group.underlay1.name}"
    location = "East US"
    backend_port = 22
    enable_floating_ip = false
    frontend_ip_configuration_name = "underlay1_loadbalancer2_frontend_ip_name"
    frontend_port = 22
    protocol = "Tcp"
    loadbalancer_id = "${azurerm_lb.underlay1_loadbalancer2.id}"
}

resource "azurerm_lb_nat_rule" "underlay1_loadbalancer2_NAT_rule2" {
    name = "underlay1_loadbalancer2_NAT_rule2"
    resource_group_name = "${azurerm_resource_group.underlay1.name}"
    location = "East US"
    backend_port = 22
    enable_floating_ip = false
    frontend_ip_configuration_name = "underlay1_loadbalancer2_frontend_ip_name"
    frontend_port = 2201
    protocol = "Tcp"
    loadbalancer_id = "${azurerm_lb.underlay1_loadbalancer2.id}"
}

resource "azurerm_lb_nat_rule" "underlay1_loadbalancer2_NAT_rule3" {
    name = "underlay1_loadbalancer2_NAT_rule3"
    resource_group_name = "${azurerm_resource_group.underlay1.name}"
    location = "East US"
    backend_port = 22
    enable_floating_ip = false
    frontend_ip_configuration_name = "underlay1_loadbalancer2_frontend_ip_name"
    frontend_port = 2202
    protocol = "Tcp"
    loadbalancer_id = "${azurerm_lb.underlay1_loadbalancer2.id}"
}





//Master NICs
//------------------------------------------------------------------------------------------
resource "azurerm_network_interface" "master-vm0-nic0" {
    name = "master-vm0-nic0"
    resource_group_name = "${azurerm_resource_group.underlay1.name}"
    location = "East US"
    enable_ip_forwarding = true
    depends_on = ["azurerm_virtual_network.underlay1_virtualnetwork1","azurerm_lb.underlay1_loadbalancer1"]
    ip_configuration {
        name = "ipconfig1"
        load_balancer_backend_address_pools_ids = ["${azurerm_lb_backend_address_pool.underlay1_loadbalancer1_backend_pool.id}","${azurerm_lb_backend_address_pool.underlay1_loadbalancer2_backend_pool.id}"]
        load_balancer_inbound_nat_rules_ids = ["${azurerm_lb_nat_rule.underlay1_loadbalancer2_NAT_rule1.id}"]
        private_ip_address = "10.240.255.5"
        private_ip_address_allocation = "Static"
        subnet_id = "${azurerm_subnet.underlay1_mastersubnet.id}"
        primary = true
   }        
}

resource "azurerm_network_interface" "master-vm1-nic0" {
    name = "master-vm1-nic0"
    resource_group_name = "${azurerm_resource_group.underlay1.name}"
    location = "East US"
    enable_ip_forwarding = true
    depends_on = ["azurerm_virtual_network.underlay1_virtualnetwork1","azurerm_lb.underlay1_loadbalancer1"]
    ip_configuration {
        name = "ipconfig1"
        load_balancer_backend_address_pools_ids = ["${azurerm_lb_backend_address_pool.underlay1_loadbalancer1_backend_pool.id}","${azurerm_lb_backend_address_pool.underlay1_loadbalancer2_backend_pool.id}"]
        load_balancer_inbound_nat_rules_ids = ["${azurerm_lb_nat_rule.underlay1_loadbalancer2_NAT_rule2.id}"]
        private_ip_address = "10.240.255.6"
        private_ip_address_allocation = "Static"
        subnet_id = "${azurerm_subnet.underlay1_mastersubnet.id}"
        primary = true
   }   
}

resource "azurerm_network_interface" "master-vm2-nic0" {
    name = "master-vm2-nic0"
    resource_group_name = "${azurerm_resource_group.underlay1.name}"
    location = "East US"
    enable_ip_forwarding = true
    depends_on = ["azurerm_virtual_network.underlay1_virtualnetwork1","azurerm_lb.underlay1_loadbalancer1"]
    ip_configuration {
        name = "ipconfig1"
        load_balancer_backend_address_pools_ids = ["${azurerm_lb_backend_address_pool.underlay1_loadbalancer1_backend_pool.id}","${azurerm_lb_backend_address_pool.underlay1_loadbalancer2_backend_pool.id}"]
        load_balancer_inbound_nat_rules_ids = ["${azurerm_lb_nat_rule.underlay1_loadbalancer2_NAT_rule3.id}"]
        private_ip_address = "10.240.255.7"
        private_ip_address_allocation = "Static"
        subnet_id = "${azurerm_subnet.underlay1_mastersubnet.id}"
        primary = true
   }
}

//Agent NICs
//------------------------------------------------------------------------------------------
resource "azurerm_network_interface" "agent-vm0-nic0" {
    name = "agent-vm0-nic0"
    resource_group_name = "${azurerm_resource_group.underlay1.name}"
    location = "East US"
    enable_ip_forwarding = true
    enable_accelerated_networking = true
    depends_on = ["azurerm_virtual_network.underlay1_virtualnetwork1"]
    ip_configuration {
        name = "ipconfig1"
        private_ip_address_allocation = "Dynamic"
        subnet_id = "${azurerm_subnet.underlay1_mastersubnet.id}"
        primary = true
   }        
}

resource "azurerm_network_interface" "agent-vm1-nic0" {
    name = "agent-vm1-nic0"
    resource_group_name = "${azurerm_resource_group.underlay1.name}"
    location = "East US"
    enable_ip_forwarding = true
    enable_accelerated_networking = true
    depends_on = ["azurerm_virtual_network.underlay1_virtualnetwork1"]
    ip_configuration {
        name = "ipconfig1"
        private_ip_address_allocation = "Dynamic"
        subnet_id = "${azurerm_subnet.underlay1_mastersubnet.id}"
        primary = true
   }        
}

resource "azurerm_network_interface" "agent-vm2-nic0" {
    name = "agent-vm2-nic0"
    resource_group_name = "${azurerm_resource_group.underlay1.name}"
    location = "East US"
    enable_ip_forwarding = true
    enable_accelerated_networking = true
    depends_on = ["azurerm_virtual_network.underlay1_virtualnetwork1"]
    ip_configuration {
        name = "ipconfig1"
        private_ip_address_allocation = "Dynamic"
        subnet_id = "${azurerm_subnet.underlay1_mastersubnet.id}"
        primary = true
   }        
}

//Master Availability Sets
//------------------------------------------------------------------------------------------
resource "azurerm_availability_set" "masterAvailabilitySet" {
    name = "masterAvailabilitySet"
    location = "East US"
    resource_group_name = "${azurerm_resource_group.underlay1.name}" 
    platform_fault_domain_count = 2
    platform_update_domain_count = 3
    managed = true
}

//Agent Availability Sets
//------------------------------------------------------------------------------------------
resource "azurerm_availability_set" "agentAvailabilitySet" {
    name = "agentAvailabilitySet"
    location = "East US"
    resource_group_name = "${azurerm_resource_group.underlay1.name}"
    platform_fault_domain_count = 2
    platform_update_domain_count = 3
    managed = true
}

//Master Nodes
//------------------------------------------------------------------------------------------
resource "azurerm_virtual_machine" "masternode0" {
    name = "masternode0"
    location = "East US"
    resource_group_name = "${azurerm_resource_group.underlay1.name}"

    availability_set_id = "${azurerm_availability_set.masterAvailabilitySet.id}"
    vm_size = "Standard_D2_v2"
    network_interface_ids = ["${azurerm_network_interface.master-vm0-nic0.id}"]
    os_profile {
        admin_username = "cloudadmin"
        admin_password = "Password!123Password"
        computer_name = "masternode0"
        //TODO: Add customData which is the cloudinit stuff
    }
    os_profile_linux_config {
        disable_password_authentication = false
    }

    storage_image_reference {
        publisher = "microsoft-aks"
        offer     = "aks"
        sku       = "aks-ubuntu-1604-201901"
        version   = "2019.01.11"
    }
    
    storage_os_disk {
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
        disk_size_gb = 40 //TODO: originally 1000
        name = "masternode0_osdisk"
    }

    storage_data_disk {
        create_option = "Empty"
        disk_size_gb = 40 //TODO: originally 4000
        lun = 0
        name = "masternode0-etcddisk"
    }

    depends_on = ["azurerm_availability_set.masterAvailabilitySet", "azurerm_network_interface.master-vm0-nic0"]
}

resource "azurerm_virtual_machine" "masternode1" {
    name = "masternode1"
    location = "East US"
    resource_group_name = "${azurerm_resource_group.underlay1.name}"

    availability_set_id = "${azurerm_availability_set.masterAvailabilitySet.id}"
    vm_size = "Standard_D2_v2"
    network_interface_ids = ["${azurerm_network_interface.master-vm1-nic0.id}"]
    os_profile {
        admin_username = "cloudadmin"
        admin_password = "Password!123Password"
        computer_name = "masternode1"
        //TODO: Add customData which is the cloudinit stuff
    }
    os_profile_linux_config {
        disable_password_authentication = false
    }

    storage_image_reference {
        publisher = "microsoft-aks"
        offer     = "aks"
        sku       = "aks-ubuntu-1604-201901"
        version   = "2019.01.11"
    }
  
    storage_os_disk {
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
        disk_size_gb = 40 //TODO: originally 1000
        name = "masternode1_osdisk"
    }

    storage_data_disk {
        create_option = "Empty"
        disk_size_gb = 40 //TODO: originally 4000
        lun = 0
        name = "masternode1-etcddisk"
    }

    depends_on = ["azurerm_availability_set.masterAvailabilitySet", "azurerm_network_interface.master-vm1-nic0"]
}

resource "azurerm_virtual_machine" "masternode2" {
    name = "masternode2"
    location = "East US"
    resource_group_name = "${azurerm_resource_group.underlay1.name}"

    availability_set_id = "${azurerm_availability_set.masterAvailabilitySet.id}"
    vm_size = "Standard_D2_v2"
    network_interface_ids = ["${azurerm_network_interface.master-vm2-nic0.id}"]
    os_profile {
        admin_username = "cloudadmin"
        admin_password = "Password!123Password"
        computer_name = "masternode2"
        //TODO: Add customData which is the cloudinit stuff
    }
    os_profile_linux_config {
        disable_password_authentication = false
    }

    storage_image_reference {
        publisher = "microsoft-aks"
        offer     = "aks"
        sku       = "aks-ubuntu-1604-201901"
        version   = "2019.01.11"
    }
  
    storage_os_disk {
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
        disk_size_gb = 40 //TODO: originally 1000
        name = "masternode2_osdisk"
    }

    storage_data_disk {
      create_option = "Empty"
      disk_size_gb = 40 //TODO: originally 4000
      lun = 0
      name = "masternode2-etcddisk"
    }

    depends_on = ["azurerm_availability_set.masterAvailabilitySet", "azurerm_network_interface.master-vm2-nic0"]

}

//Agent Nodes
//------------------------------------------------------------------------------------------
resource "azurerm_virtual_machine" "agentnode0" {
    name = "agentnode0"
    location = "East US"
    resource_group_name = "${azurerm_resource_group.underlay1.name}"

    availability_set_id = "${azurerm_availability_set.agentAvailabilitySet.id}"
    vm_size = "Standard_D2_v2"
    network_interface_ids = ["${azurerm_network_interface.agent-vm0-nic0.id}"]
    os_profile {
        admin_username = "cloudadmin"
        admin_password = "Password!123Password"
        computer_name = "agentnode0"
        //TODO: Add customData which is the cloudinit stuff
    }
    os_profile_linux_config {
        disable_password_authentication = false
    }

    storage_image_reference {
        publisher = "microsoft-aks"
        offer     = "aks"
        sku       = "aks-ubuntu-1604-201901"
        version   = "2019.01.11"
    }
  
    storage_os_disk {
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
        disk_size_gb = 40 //TODO: originally 1000
        name = "agentnode0_osdisk"
    }
  
    depends_on = ["azurerm_availability_set.agentAvailabilitySet", "azurerm_network_interface.agent-vm0-nic0"]
}

resource "azurerm_virtual_machine" "agentnode1" {
    name = "agentnode1"
    location = "East US"
    resource_group_name = "${azurerm_resource_group.underlay1.name}"

    availability_set_id = "${azurerm_availability_set.agentAvailabilitySet.id}"
    vm_size = "Standard_D2_v2"
    network_interface_ids = ["${azurerm_network_interface.agent-vm1-nic0.id}"]
    os_profile {
        admin_username = "cloudadmin"
        admin_password = "Password!123Password"
        computer_name = "agentnode1"
        //TODO: Add customData which is the cloudinit stuff
    }
    os_profile_linux_config {
        disable_password_authentication = false
    }

    storage_image_reference {
        publisher = "microsoft-aks"
        offer     = "aks"
        sku       = "aks-ubuntu-1604-201901"
        version   = "2019.01.11"
    }

    storage_os_disk {
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
        disk_size_gb = 40 //TODO: originally 1000
        name = "agentnode1_osdisk"
    }
  
    depends_on = ["azurerm_availability_set.agentAvailabilitySet", "azurerm_network_interface.agent-vm1-nic0"]
}

resource "azurerm_virtual_machine" "agentnode2" {
    name = "agentnode2"
    location = "East US"
    resource_group_name = "${azurerm_resource_group.underlay1.name}"

    availability_set_id = "${azurerm_availability_set.agentAvailabilitySet.id}"
    vm_size = "Standard_D2_v2"
    network_interface_ids = ["${azurerm_network_interface.agent-vm2-nic0.id}"]
    os_profile {
        admin_username = "cloudadmin"
        admin_password = "Password!123Password"
        computer_name = "agentnode2"
        //TODO: Add customData which is the cloudinit stuff
    }
    os_profile_linux_config {
        disable_password_authentication = false
    }

    storage_image_reference {
        publisher = "microsoft-aks"
        offer     = "aks"
        sku       = "aks-ubuntu-1604-201901"
        version   = "2019.01.11"
    }

    storage_os_disk {
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
        disk_size_gb = 40 //TODO: originally 1000
        name = "agentnode2_osdisk"
    }
  
    depends_on = ["azurerm_availability_set.agentAvailabilitySet", "azurerm_network_interface.agent-vm2-nic0"]
}