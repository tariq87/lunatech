# lunatech
# Pre-requisites
1) This setup is tested on amazon linux
2) Should have AWS account 
3) An AWS user with credentials having enough access to perform the operations.
4) You can run this from your local machine as well give that you have terraform and ansible installed (along with anyother dependency)

Configure your awscli
# aws configure

Install Ansible
# pip install ansible

Download and install Terraform for your system (linux, mac or windows)

# How to run the setup
1) Create a directory "lunatech" on your machine
2) Clone the repository
3) cd into the directory
4) run "terraform plan"
5) Once plan is successful, run "terraform apply"
6) Make the get calls to api's using the dns of the ELB -> eg: http://my-elb-lunatech:8000/countries or airports
