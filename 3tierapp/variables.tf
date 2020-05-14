#Variables

#vCenter
variable "vsphere_server" {
  default = "vcsa-01a.corp.local"
}

# Username & Password for vCenter
variable "vsphere_user" {
  default = "administrator@vsphere.local"
}
variable "vsphere_password" {
    default = "VMware1!"
}

#NSX Manager
variable "nsx_manager" {
  default = "nsxmgr-01a"
}

# Username & Password for NSX-T Manager
variable "nsx_username" {
  default = "admin"
}
variable "nsx_password" {
    default = "VMware1!VMware1!"
}

# Segment Names
variable "nsx_segment_web" {
    default = "TF-Segment-Web"
}
variable "nsx_segment_app" {
    default = "TF-Segment-App"
}
variable "nsx_segment_db" {
    default = "TF-Segment-DB"
}

# Security Group names.
variable "nsx_group_web" {
    default = "TF Web Servers"
}

variable "nsx_group_app" {
    default = "TF App Servers"
}

variable "nsx_group_db" {
    default = "TF DB Servers"
}

variable "nsx_group_three_tier_app" {
    default = "TF three tier app"
}
