provider "azure" {
    client_id = "YOUR_CLIENT_ID"
    client_secret = "YOUR_CLIENT_SECRET"
}

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
    load_distribution = "default"
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







//resource "azurerm_network_interface" "master-vm0-nic0" {
//    name = "master-vm0-nic0"
//    resource_group_name = "${azurerm_resource_group.underlay1.name}"
//    location = "East US"
//    enable_ip_forwarding = true
//    depends_on = ["azurerm_virtual_network.underlay1_virtualnetwork1","azurerm_lb.underlay1_loadbalancer1"]
//    ip_configuration {
//        name = "ipconfig1"
//        load_balancer_backend_address_pools_ids = ["${azurerm_lb_backend_address_pool.underlay1_loadbalancer1_backend_pool.id}"]
        //TODO: add external load balancer backend pool id in above array
//        load_balancer_inbound_nat_rules_ids = 
//    }
//}

