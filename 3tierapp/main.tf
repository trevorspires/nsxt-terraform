# Data Sources we need for reference later
#Input your own data sources
#Be sure your T0 is redistributing connected T1 segments

# vSphere Provider
provider "vsphere" {
  user           = var.vsphere_user
  password       = var.vsphere_password
  vsphere_server = var.vsphere_server

  # If you have a self-signed cert
  allow_unverified_ssl = true
}

# NSX-T Manager Credentials
provider "nsxt" {
    host                     = var.nsx_manager
    username                 = var.nsx_username
    password                 = var.nsx_password
    allow_unverified_ssl     = true
    max_retries              = 10
    retry_min_delay          = 500
    retry_max_delay          = 5000
    retry_on_status_codes    = [429]
}

data "nsxt_policy_transport_zone" "overlay_tz" {
    display_name = "SITEA-OVERLAY-TZ"
}

data "nsxt_policy_transport_zone" "vlan_tz" {
    display_name = "SITEA-VLAN-TZ"
}

data "nsxt_policy_tier0_gateway" "tier0_gw" {
  display_name = "t0-sitea"
}

data "nsxt_policy_edge_cluster" "edge_cluster" {
  display_name = "sitea-edge-cluster"
}

data "nsxt_policy_service" "ssh" {
    display_name = "SSH"
}

data "nsxt_policy_service" "http" {
    display_name = "HTTP"
}

data "nsxt_policy_service" "https" {
    display_name = "HTTPS"
}

 data "nsxt_policy_lb_app_profile" "default_tcp" {
  type         = "TCP"
  display_name = "default-tcp-lb-app-profile"
}

###vSphere Data###
data "vsphere_datacenter" "dc" {
  name = "Site-A"
}

data "vsphere_datastore" "datastore" {
  name          = "RegionA01-ISCSI01-COMP01"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_compute_cluster" "cluster" {
  name          = "Cluster-01a"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_virtual_machine" "template" {
  name = "vmtemplate"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

#DHCP Server
resource "nsxt_policy_dhcp_server" "DHCP-1" {
  display_name      = "TF-DHCP"
  description       = "Terraform provisioned DhcpServerConfig"
  edge_cluster_path = data.nsxt_policy_edge_cluster.edge_cluster.path
  lease_time        = 200
  server_addresses  = ["10.67.67.67/24"]
}

# Create Tier-1 Gateway
resource "nsxt_policy_tier1_gateway" "tier1_gw" {
    description               = "Tier-1 provisioned by Terraform"
    display_name              = "TF-Ten1-T1"
    nsx_id                    = "predefined_id"
    edge_cluster_path         = data.nsxt_policy_edge_cluster.edge_cluster.path
    failover_mode             = "NON_PREEMPTIVE"
    default_rule_logging      = "false"
    enable_firewall           = "true"
    enable_standby_relocation = "false"
    force_whitelisting        = "true"
    tier0_path                = data.nsxt_policy_tier0_gateway.tier0_gw.path
    route_advertisement_types = ["TIER1_STATIC_ROUTES", "TIER1_CONNECTED", "TIER1_LB_VIP", "TIER1_LB_SNAT"]
    dhcp_config_path		  = nsxt_policy_dhcp_server.DHCP-1.path

    tag {
        scope = "TF"
        tag   = "web"
    }

    route_advertisement_rule {
        name                      = "Tier 1 Networks"
        action                    = "PERMIT"
        subnets                   = ["172.18.10.0/24", "172.18.20.0/24", "172.18.30.0/24"]
        prefix_operator           = "GE"
        route_advertisement_types = ["TIER1_CONNECTED"]
    }
}

# Create NSX-T Overlay Segments
resource "nsxt_policy_segment" "web" {
    display_name        = var.nsx_segment_web
    description         = "Segment created by Terraform"
    transport_zone_path = data.nsxt_policy_transport_zone.overlay_tz.path
    connectivity_path   = nsxt_policy_tier1_gateway.tier1_gw.path

    subnet {
        cidr        = "172.18.10.1/24"
         dhcp_ranges = ["172.18.10.50-172.18.10.100"]

         dhcp_v4_config {
            lease_time  = 36000
            dns_servers = ["192.168.110.10"]
         }
    }
}

resource "nsxt_policy_segment" "tf_segment_app" {
    display_name = var.nsx_segment_app
    description = "Segment created by Terraform"
    transport_zone_path = data.nsxt_policy_transport_zone.overlay_tz.path
    connectivity_path   = nsxt_policy_tier1_gateway.tier1_gw.path

    subnet {
        cidr        = "172.18.20.1/24"
    }
}

resource "nsxt_policy_segment" "tf_segment_db" {
    display_name = var.nsx_segment_db
    description = "Segment created by Terraform"
    transport_zone_path = data.nsxt_policy_transport_zone.overlay_tz.path
    connectivity_path   = nsxt_policy_tier1_gateway.tier1_gw.path

    subnet {
        cidr        = "172.18.30.1/24"
    }

}

#Create Load Balancer for Web Seervers
#Edit Size?
#
#resource "nsxt_policy_lb_service" "ten1_web_lb" {
#  display_name      = "ten1_web_lb"
#  description       = "Terraform provisioned Service"
#  connectivity_path = nsxt_policy_tier1_gateway.tier1_gw.path
#  size = "SMALL"
#  enabled = true
#  error_log_level = "ERROR"
#}
#
#resource "nsxt_policy_lb_pool" "ten1_web_pool" {
#    display_name         = "ten1_web_pool"
#    description          = "Terraform provisioned LB Pool"
#    algorithm            = "IP_HASH"
#    min_active_members   = 2
#    active_monitor_path  = "/infra/lb-monitor-profiles/default-icmp-lb-monitor"
#    passive_monitor_path = "/infra/lb-monitor-profiles/default-passive-lb-monitor"
#    member_group {
#      group_path                 = nsxt_policy_group.web_servers.path
#    }
#    snat {
#       type = "AUTOMAP"
#    }
#    tcp_multiplexing_enabled = true
#    tcp_multiplexing_number  = 8
#}
#
#resource "nsxt_policy_lb_virtual_server" "ten1_web" {
#  display_name               = "ten1 web virual server"
#  description                = "Terraform provisioned Virtual Server"
#  access_log_enabled         = true
#  application_profile_path   = data.nsxt_policy_lb_app_profile.default_tcp.path
#  enabled                    = true
#  ip_address                 = "172.18.10.10"
#  ports                      = ["443"]
#  pool_path                  = nsxt_policy_lb_pool.ten1_web_pool.path
#  service_path				  = nsxt_policy_lb_service.ten1_web_lb.path
#}

#Create Security Groups
resource "nsxt_policy_group" "web_servers" {
    display_name = var.nsx_group_web
    description  = "Terraform provisioned Group"

    criteria {
        condition {
            key         = "Tag"
            member_type = "VirtualMachine"
            operator    = "CONTAINS"
            value       = "Web"
        }
    }
}

resource "nsxt_policy_group" "app_servers" {
    display_name = var.nsx_group_app
    description  = "Terraform provisioned Group"

    criteria {
        condition {
            key         = "Tag"
            member_type = "VirtualMachine"
            operator    = "CONTAINS"
            value       = "App"
        }
    }
}

resource "nsxt_policy_group" "db_servers" {
    display_name = var.nsx_group_db
    description  = "Terraform provisioned Group"

    criteria {
        condition {
            key         = "Tag"
            member_type = "VirtualMachine"
            operator    = "CONTAINS"
            value       = "DB"
        }
    }
}

resource "nsxt_policy_group" "three_tier_app" {
    display_name = var.nsx_group_three_tier_app
    description  = "Terraform provisioned Group"

    criteria {
        condition {
            key         = "Tag"
            member_type = "VirtualMachine"
            operator    = "CONTAINS"
            value       = "three_tier_app"
        }
    }
}

# Create Custom Services
resource "nsxt_policy_service" "service_tcp8443" {
    description  = "HTTPS service provisioned by Terraform"
    display_name = "TCP 8443"

    l4_port_set_entry {
        display_name      = "TCP8443"
        description       = "TCP port 8443 entry"
        protocol          = "TCP"
        destination_ports = [ "8443" ]
    }

    tag {
        scope = "TF"
        tag   = "web"
    }
}

# Create Security Policies
resource "nsxt_policy_security_policy" "allow_web" {
    display_name = "TF - Allow Web Application"
    description  = "Terraform provisioned Security Policy"
    category     = "Application"
    locked       = false
    stateful     = true
    tcp_strict   = false
    scope        = [nsxt_policy_group.web_servers.path]

    rule {
        display_name        = "Allow SSH to Web Servers"
        destination_groups  = [nsxt_policy_group.three_tier_app.path]
        action              = "ALLOW"
        services            = [data.nsxt_policy_service.ssh.path]
        logged              = true
        scope               = [nsxt_policy_group.three_tier_app.path]
    }

    rule {
        display_name        = "Allow HTTPS to Web Servers"
        destination_groups  = [nsxt_policy_group.web_servers.path]
        action              = "ALLOW"
        services            = [data.nsxt_policy_service.https.path]
        logged              = true
        scope               = [nsxt_policy_group.three_tier_app.path]
    }

    rule {
        display_name        = "Allow TCP 8443 to App Servers"
        source_groups       = [nsxt_policy_group.web_servers.path]
        destination_groups  = [nsxt_policy_group.app_servers.path]
        action              = "ALLOW"
        services            = [nsxt_policy_service.service_tcp8443.path]
        logged              = true
        scope               = [nsxt_policy_group.three_tier_app.path]
    }

    rule {
        display_name        = "Allow HTTP to DB Servers"
        source_groups       = [nsxt_policy_group.app_servers.path]
        destination_groups  = [nsxt_policy_group.db_servers.path]
        action              = "ALLOW"
        services            = [data.nsxt_policy_service.http.path]
        logged              = true
        scope               = [nsxt_policy_group.three_tier_app.path]
    }

    rule {
        display_name        = "Any Deny"
        action              = "REJECT"
        logged              = false
        scope               = [nsxt_policy_group.three_tier_app.path]
    }
}


###Delay for vCenter to sync with NSX for Logical Switch
resource "null_resource" "before" {
  depends_on    = [nsxt_policy_segment.web]
}

resource "null_resource" "delay" {
  provisioner "local-exec" {
    command = "sleep 20"
  }
  triggers = {
    "before" = null_resource.before.id
  }
}

resource "null_resource" "after" {
  depends_on = [null_resource.delay]
}

##Data Source for Logical Switch
###NETWORK####
data "vsphere_network" "net1" {
  name          = nsxt_policy_segment.web.display_name
  datacenter_id = data.vsphere_datacenter.dc.id
  depends_on    = [null_resource.after]
}


resource "vsphere_virtual_machine" "vm1" {
  name             = "web-1"
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id
  guest_id = "ubuntu64Guest"
  depends_on    = [null_resource.after]

  network_interface {
    network_id = data.vsphere_network.net1.id
    }
    disk {
    label = "disk0"
    size  = 24
  }
  clone {
    template_uuid = data.vsphere_virtual_machine.template.id
    }
}

resource "nsxt_vm_tags" "vm1_tags" {
  instance_id = vsphere_virtual_machine.vm1.id

  tag {
    scope = "TF"
    tag   = "Web"
  }
}
