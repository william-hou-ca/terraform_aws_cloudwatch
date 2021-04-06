output "ec2-ip" {
  value =  aws_instance.web.public_ip
}