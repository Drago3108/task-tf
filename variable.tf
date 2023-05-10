variable "cidr" {
  type        = string
  description = "VPC CIDR Value"
}
variable "pub1" {
  type        = string
  description = "Public Subnet 1 CIDR"
}
variable "pub2" {
  type        = string
  description = "Public Subnet 2 CIDR"

}
variable "pri1" {
  type = string
  description = "Private Subnet 1 CIDR"
}
variable "pri2" {
  type = string
  description = "Private Subnet 1 CIDR"
}
variable "ec2type" {
  type = string
  description = "Instance Type"
}
variable "amiid" {
  type = string
  description = "Instance AMI ID"
}
variable "lbsg" {
  type = string
  description = "ALB Security Group"
}
variable "ec2sg" {
  type = string
  description = "ec2sg"
}
variable "iamarn" {
  type = string
  description = "ROLE ARN specify here"
}