provider "aws" {
  region = "us-east-1"
}

data "aws_availability_zones" "all" {}

resource "aws_vpc" "myvpc" {
  cidr_block = "10.1.0.0/16"
  enable_dns_hostnames = true
}

resource "aws_subnet" "mysub" {
  vpc_id = "${aws_vpc.myvpc.id}"
  cidr_block = "10.1.1.0/24"
  
}

resource "aws_internet_gateway" "myigw" {
  vpc_id = "${aws_vpc.myvpc.id}"
  
}

resource "aws_route_table" "myroutetable" {
  vpc_id = "${aws_vpc.myvpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.myigw.id}"
  }
}

resource "aws_route_table_association" "myroutetableassoc" {
  subnet_id = "${aws_subnet.mysub.id}"
  route_table_id = "${aws_route_table.myroutetable.id}"
}

resource "aws_security_group" "mysg" {
  name = "mysecuritygroup"
  description = "Allow incoming HTTP connections & SSH access"

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
	from_port = 8080
	to_port = 8080
	protocol = "tcp"
	cidr_blocks = ["0.0.0.0/0"]
}

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks =  ["0.0.0.0/0"]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  vpc_id = "${aws_vpc.myvpc.id}"

}

resource "aws_key_pair" "default" {
  key_name = "lunatech"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC0dn/fEPVv/y0kNkx47EyyEnfb5P4BhKWZn40ec4iDjIBBGPQqg+9maDbel8zwlMdSYwy+OTuebeQto8Q8/ZRdaUCNz30H09Vl51SZOfsXWIsEsoz9ePZHvpQ5O6hxl9rFbTCC2XFknm8SDe9xLw+LZrUrIlSf9jVp92lR01lyPiEe+7/ogq1bG5jmzUynvRPZow0VrrFcYzIjmyoZvb5xPG44gKH9aw10iPGxWq12VbP1QhrLjIfR+FDFYgiugZXaAkHoCzo1nQH8niPd68s6HDaX/hsA597CpzYL+a+3DzyXzli0Zo96slr7U+BxFSfAW/TtbEACCmuQXa35REyB tariqsiddiqui@tariqsiddiqui.local"
}


resource "aws_instance" "myapp" {
   ami  = "ami-cfe4b2b0"
   count = 3
   instance_type = "t2.micro"
   key_name = "${aws_key_pair.default.id}"
   subnet_id = "${aws_subnet.mysub.id}"
   vpc_security_group_ids = ["${aws_security_group.mysg.id}"]
   associate_public_ip_address = true
   source_dest_check = false
   user_data = "${file("userdata")}"

  tags {
    Name = "webserver-${count.index + 1}"
  }
}
resource "null_resource" "myapp" {
  triggers {
    cluster_instance_ids = "${join(",", aws_instance.myapp.*.id)}"
  }
  provisioner "local-exec" {
	command = <<EOD
	cat <<EOF >aws_hosts
[app1]
${aws_instance.myapp.0.public_ip}
[app2]
${aws_instance.myapp.1.public_ip}
[app3]
${aws_instance.myapp.2.public_ip}
EOF
EOD
}
  provisioner "local-exec" {
       command = "aws ec2 wait instance-status-ok --no-include-all-instances && ansible-playbook -i aws_hosts install.yml"
  }

}

output "instance_ips" {
    value = ["${aws_instance.myapp.*.public_ip}"]
}

resource "aws_security_group" "elb" {
  name = "lunatech-elb-sg"
  vpc_id = "${aws_vpc.myvpc.id}"
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 8000
    to_port = 8000
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
	}
}




resource "aws_elb" "myelb" {
  name = "lunatech"
  subnets = ["${aws_subnet.mysub.id}"]
  security_groups = ["${aws_security_group.elb.id}"]
  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTP:80/"
  }


  listener {
    lb_port = 8000
    lb_protocol = "http"
    instance_port = 80
    instance_protocol = "http"
  }

  instances = ["${aws_instance.myapp.0.id}", "${aws_instance.myapp.1.id}"]
}








