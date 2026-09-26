variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "security_groups" {
  description = "Map of security groups: tier name => description"
  type        = map(string)
}


variable "ingress_rules" {
  description = "Map of ingress rules. Use cidr_ipv4 OR referenced_security_group, not both."
  type = map(object({
    security_group            = string
    description               = string
    ip_protocol               = string
    from_port                 = optional(number)
    to_port                   = optional(number)
    cidr_ipv4                 = optional(string)
    referenced_security_group = optional(string)
  }))
  default = {}
}

variable "egress_rules" {
  description = "Map of egress rules. Same shape as ingress_rules."
  type = map(object({
    security_group            = string
    description               = string
    ip_protocol               = string
    from_port                 = optional(number)
    to_port                   = optional(number)
    cidr_ipv4                 = optional(string)
    referenced_security_group = optional(string)
  }))
  default = {}
}


variable "network_acls" {
  description = "Map of NACLs: name => subnets and rules"
  type = map(object({
    subnet_ids = list(string)
    ingress = list(object({
      rule_no    = number
      protocol   = string
      action     = string
      cidr_block = string
      from_port  = optional(number, 0)
      to_port    = optional(number, 0)
    }))
    egress = list(object({
      rule_no    = number
      protocol   = string
      action     = string
      cidr_block = string
      from_port  = optional(number, 0)
      to_port    = optional(number, 0)
    }))
  }))
  default = {}
}