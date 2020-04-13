#Variables

variable "nsx_manager" {
  default = "nsxmgr-01a"
}
 
# Username & Password for NSX-T Manager
variable "username" {
  default = "admin"
}
 
variable "password" {
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
    default = "Web Servers"
}
 
variable "nsx_group_app" {
    default = "App Servers"
}
 
variable "nsx_group_db" {
    default = "DB Servers"
}
 
variable "nsx_group_blue" {
    default = "Blue Application"
}