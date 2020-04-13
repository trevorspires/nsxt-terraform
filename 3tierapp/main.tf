# Data Sources we need for reference later
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
 
# NSX-T Manager Credentials
provider "nsxt" {
    host                     = var.nsx_manager
    username                 = var.username
    password                 = var.password
    allow_unverified_ssl     = true
    max_retries              = 10
    retry_min_delay          = 500
    retry_max_delay          = 5000
    retry_on_status_codes    = [429]
}
 
# Create Tier-1 Gateway
resource "nsxt_policy_tier1_gateway" "tier1_gw" {
    description               = "Tier-1 provisioned by Terraform"
    display_name              = "TF-Tier-1-01"
    nsx_id                    = "predefined_id"
    edge_cluster_path         = data.nsxt_policy_edge_cluster.edge_cluster.path
    failover_mode             = "NON_PREEMPTIVE"
    default_rule_logging      = "false"
    enable_firewall           = "true"
    enable_standby_relocation = "false"
    force_whitelisting        = "true"
    tier0_path                = data.nsxt_policy_tier0_gateway.tier0_gw.path
    route_advertisement_types = ["TIER1_STATIC_ROUTES", "TIER1_CONNECTED"]
 
    tag {
        scope = "color"
        tag   = "blue"
    }
 
    route_advertisement_rule {
        name                      = "Tier 1 Networks"
        action                    = "PERMIT"
        subnets                   = ["172.16.10.0/24", "172.16.20.0/24", "172.16.30.0/24"]
        prefix_operator           = "GE"
        route_advertisement_types = ["TIER1_CONNECTED"]
    }
}
 
# Create NSX-T Overlay Segments
resource "nsxt_policy_segment" "tf_segment_web" {
    display_name        = var.nsx_segment_web
    description         = "Segment created by Terraform"
    transport_zone_path = data.nsxt_policy_transport_zone.overlay_tz.path
    connectivity_path   = nsxt_policy_tier1_gateway.tier1_gw.path
 
    subnet {   
        cidr        = "172.17.10.1/24"
        # dhcp_ranges = ["172.17.10.50-172.17.10.100"] 
     
        # dhcp_v4_config {
        #     lease_time  = 36000
        #     dns_servers = ["192.168.110.10"]
        # }
    }
}
 
resource "nsxt_policy_segment" "tf_segment_app" {
    display_name = var.nsx_segment_app
    description = "Segment created by Terraform"
    transport_zone_path = data.nsxt_policy_transport_zone.overlay_tz.path
    connectivity_path   = nsxt_policy_tier1_gateway.tier1_gw.path
 
    subnet {   
        cidr        = "172.17.20.1/24"
    }
}
 
resource "nsxt_policy_segment" "tf_segment_db" {
    display_name = var.nsx_segment_db
    description = "Segment created by Terraform"
    transport_zone_path = data.nsxt_policy_transport_zone.overlay_tz.path
    connectivity_path   = nsxt_policy_tier1_gateway.tier1_gw.path
 
    subnet {   
        cidr        = "172.17.30.1/24"
    }
     
}
 
# Create Security Groups
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
 
resource "nsxt_policy_group" "blue_servers" {
    display_name = var.nsx_group_blue
    description  = "Terraform provisioned Group"
 
    criteria {
        condition {
            key         = "Tag"
            member_type = "VirtualMachine"
            operator    = "CONTAINS"
            value       = "Blue"
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
        scope = "color"
        tag   = "blue"
    }
}
 
# Create Security Policies
resource "nsxt_policy_security_policy" "allow_blue" {
    display_name = "Allow Blue Application"
    description  = "Terraform provisioned Security Policy"
    category     = "Application"
    locked       = false
    stateful     = true
    tcp_strict   = false
    scope        = [nsxt_policy_group.web_servers.path]
 
    rule {
        display_name        = "Allow SSH to Blue Servers"
        destination_groups  = [nsxt_policy_group.blue_servers.path]
        action              = "ALLOW"
        services            = [data.nsxt_policy_service.ssh.path]
        logged              = true
        scope               = [nsxt_policy_group.blue_servers.path]
    }   
 
    rule {
        display_name        = "Allow HTTPS to Web Servers"
        destination_groups  = [nsxt_policy_group.web_servers.path]
        action              = "ALLOW"
        services            = [data.nsxt_policy_service.https.path]
        logged              = true
        scope               = [nsxt_policy_group.web_servers.path]
    }
 
    rule {
        display_name        = "Allow TCP 8443 to App Servers"
        source_groups       = [nsxt_policy_group.web_servers.path]
        destination_groups  = [nsxt_policy_group.app_servers.path]
        action              = "ALLOW"
        services            = [nsxt_policy_service.service_tcp8443.path]
        logged              = true
        scope               = [nsxt_policy_group.web_servers.path,nsxt_policy_group.app_servers.path]
    }
 
    rule {
        display_name        = "Allow HTTP to DB Servers"
        source_groups       = [nsxt_policy_group.app_servers.path]
        destination_groups  = [nsxt_policy_group.db_servers.path]
        action              = "ALLOW"
        services            = [data.nsxt_policy_service.http.path]
        logged              = true
        scope               = [nsxt_policy_group.app_servers.path,nsxt_policy_group.db_servers.path]
    }
 
    rule {
        display_name        = "Any Deny"
        action              = "REJECT"
        logged              = false
        scope               = [nsxt_policy_group.blue_servers.path]
    }
}