data "aws_vpc" "current" {
  id = module.vpc.vpc_id
}
