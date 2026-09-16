# ============================================================================
# Prod's own network inside the SHARED VPC.
# ============================================================================
#
# Production shares dev's VPC (decided 12 September), so isolation is
# configurational and the D17 gate check enforces it. But production does NOT
# share dev's public-subnet, no-NAT topology: that trade was accepted for dev and
# explicitly refused for prod. Prod's tasks run in prod's OWN private subnets and
# reach the internet through prod's OWN NAT gateway - the ~37 EUR/month already
# costed.
#
# The VPC and the internet gateway are shared (one per VPC); prod reads them
# rather than creating them. Everything below - subnets, route tables, the NAT,
# its EIP - is prod's, tagged Environment=prod, and lives in prod's state.

locals {
  shared_vpc_id = data.terraform_remote_state.shared.outputs.vpc_id
}

# The shared VPC's internet gateway - one per VPC, so prod reads it.
data "aws_internet_gateway" "shared" {
  filter {
    name   = "attachment.vpc-id"
    values = [local.shared_vpc_id]
  }
}

resource "aws_subnet" "public" {
  count                   = length(var.prod_public_subnet_cidrs)
  vpc_id                  = local.shared_vpc_id
  cidr_block              = var.prod_public_subnet_cidrs[count.index]
  availability_zone       = var.prod_azs[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "kambriq-prod-public-${count.index + 1}"
  }
}

resource "aws_subnet" "private" {
  count             = length(var.prod_private_subnet_cidrs)
  vpc_id            = local.shared_vpc_id
  cidr_block        = var.prod_private_subnet_cidrs[count.index]
  availability_zone = var.prod_azs[count.index]

  tags = {
    Name = "kambriq-prod-private-${count.index + 1}"
  }
}

# One NAT gateway (single-AZ, lean) in the first public subnet. A second in the
# other AZ would remove a single point of failure at ~37 EUR/month more; not
# taken for the launch, one resource away if wanted.
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name = "kambriq-prod-nat"
  }
}

resource "aws_nat_gateway" "prod" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "kambriq-prod-nat"
  }

  depends_on = [data.aws_internet_gateway.shared]
}

# Public route table: prod's public subnets reach the internet via the SHARED IGW.
resource "aws_route_table" "public" {
  vpc_id = local.shared_vpc_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_internet_gateway.shared.id
  }
  tags = {
    Name = "kambriq-prod-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private route table: prod's private subnets reach the internet via prod's NAT.
resource "aws_route_table" "private" {
  vpc_id = local.shared_vpc_id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.prod.id
  }
  tags = {
    Name = "kambriq-prod-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
