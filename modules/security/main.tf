# Security groups for each tier: ALB, web servers, database
resource "aws_security_group" "this" {
  for_each = var.security_groups

  name        = "${each.key}-sg-${var.project_name}"
  description = each.value
  vpc_id      = var.vpc_id

  tags = {
    Name = "${each.key}-sg-${var.project_name}"
  }
}


# Security group Ingress rules
resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = var.ingress_rules

  security_group_id = aws_security_group.this[each.value.security_group].id
  description       = each.value.description
  ip_protocol       = each.value.ip_protocol
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  cidr_ipv4         = each.value.cidr_ipv4

  referenced_security_group_id = (
    each.value.referenced_security_group != null
    ? aws_security_group.this[each.value.referenced_security_group].id
    : null
  )

  tags = {
    Name = "${each.key}-${var.project_name}"
  }
}

# Security Egress rules
resource "aws_vpc_security_group_egress_rule" "this" {
  for_each = var.egress_rules

  security_group_id = aws_security_group.this[each.value.security_group].id
  description       = each.value.description
  ip_protocol       = each.value.ip_protocol
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  cidr_ipv4         = each.value.cidr_ipv4

  referenced_security_group_id = (
    each.value.referenced_security_group != null
    ? aws_security_group.this[each.value.referenced_security_group].id
    : null
  )

  tags = {
    Name = "${each.key}-${var.project_name}"
  }
}


# Network ACLs: stateless, subnet-level firewall
resource "aws_network_acl" "this" {
  for_each = var.network_acls

  vpc_id     = var.vpc_id
  subnet_ids = each.value.subnet_ids

  dynamic "ingress" {
    for_each = each.value.ingress
    content {
      rule_no    = ingress.value.rule_no
      protocol   = ingress.value.protocol
      action     = ingress.value.action
      cidr_block = ingress.value.cidr_block
      from_port  = ingress.value.from_port
      to_port    = ingress.value.to_port
    }
  }

  dynamic "egress" {
    for_each = each.value.egress
    content {
      rule_no    = egress.value.rule_no
      protocol   = egress.value.protocol
      action     = egress.value.action
      cidr_block = egress.value.cidr_block
      from_port  = egress.value.from_port
      to_port    = egress.value.to_port
    }
  }

  tags = {
    Name = "${each.key}-nacl-${var.project_name}"
  }
}