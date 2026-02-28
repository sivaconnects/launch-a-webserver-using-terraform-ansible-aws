***

# Launch a Webserver using Ansible and Terraform

This project demonstrates how to provision an AWS EC2 instance using Terraform and configure it as an Nginx web server using Ansible.

## Prerequisites
*   AWS Account
*   Existing Key Pair named `aws_keypair` in the region `eu-north-1` (required for the Terraform code provided).
*   MobaXterm (or any SSH client) installed on your local machine.

---

## Step 1: Launch the Master Node
First, we need a controller machine (Master) to run our automation tools.

1.  Launch an EC2 instance with the following configuration:
    *   **Name:** Master
    *   **AMI:** Ubuntu Latest (24.04 LTS)
    *   **Instance Type:** t3.micro
    *   **Region:** eu-north-1
    *   **Key Pair:** aws_keypair
2.  Connect to the instance via SSH:
    ```bash
    ssh -i /path/to/your-key.pem ubuntu@<Master-Public-IP>
    ```
3.  Update the package list:
    ```bash
    sudo apt update
    ```

---

## Step 2: Install AWS CLI, Ansible, and Terraform

### 1. Configure AWS CLI
1.  Create an IAM user in the AWS Console with `AdministratorAccess` policy.
2.  Generate `Access Key` and `Secret Access Key` for the IAM user.
3.  Install AWS CLI on the Master node:
    ```bash
    # Install unzip if not present
    sudo apt install unzip -y

    # Download and install AWS CLI v2
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    ```
4.  Configure AWS credentials:
    ```bash
    aws configure
    # Provide Access Key, Secret Key, Region (eu-north-1), and Output format (json).
    ```
5.  Verify installation:
    ```bash
    aws --version
    ```

### 2. Install Ansible
```bash
sudo apt update
sudo apt install software-properties-common -y
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install ansible -y
```
Verify installation: `ansible --version`

### 3. Install Terraform
```bash
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform -y
```
Verify installation: `terraform --version`

---

## Step 3: Provision Web Server using Terraform

1.  Create the project directory structure:
    ```bash
    mkdir -p my-web-server/terraform_files
    cd my-web-server/terraform_files
    ```
2.  Create `main.tf`:
    ```hcl
    terraform {
      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = "~> 5.92"
        }
      }
      required_version = ">= 1.2"
    }

    provider "aws" {
      region = "eu-north-1"
    }

    data "aws_ami" "ubuntu" {
      most_recent = true

      filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
      }

      owners = ["099720109477"] # Canonical
    }

    resource "aws_instance" "app_server" {
      ami           = data.aws_ami.ubuntu.id
      instance_type = "t3.micro"
      key_name      = "aws_keypair"

      tags = {
        Name = "nginx-web-server"
      }
    }
    ```
3.  Initialize and Apply:
    ```bash
    terraform init
    terraform validate
    terraform plan
    terraform apply --auto-approve
    ```

---

## Step 4: Configure Web Server using Ansible

### 1. Setup SSH Connectivity
For Ansible to communicate with the new instance, we need passwordless SSH.

1.  Generate an SSH key pair on the **Master** node:
    ```bash
    ssh-keygen
    # Press Enter to accept defaults
    ```
2.  Copy the public key content:
    ```bash
    cat ~/.ssh/id_ed25519.pub
    # Or cat ~/.ssh/id_rsa.pub if you used RSA
    ```
3.  SSH into the **newly created Target Instance** (using the `aws_keypair.pem` key) and add the Master's public key to `~/.ssh/authorized_keys`.

### 2. Create Ansible Files
1.  Navigate back to the project root and create the ansible directory:
    ```bash
    cd ..
    mkdir ansible_files
    cd ansible_files
    ```
2.  Create `inventory.txt` with the Public IP of the Target Instance:
    ```text
    <TARGET_INSTANCE_PUBLIC_IP>
    ```
3.  Create `ansible-playbook.yaml`:
    ```yaml
    ---
    - name: Install and start nginx
      hosts: all
      become: true
      tasks:
        - name: Install nginx
          apt:
            name: nginx
            state: present
            update_cache: yes

        - name: Start nginx service
          service:
            name: nginx
            state: started
    ```

### 3. Execute Ansible Playbook
Run the playbook to install and start Nginx:
```bash
ansible-playbook -i inventory.txt ansible-playbook.yaml
```

---

## Step 5: Verification

1.  Go to the AWS Console -> EC2 -> Security Groups.
2.  Find the Security Group attached to the `nginx-web-server` instance.
3.  Edit **Inbound Rules** and add:
    *   **Type:** HTTP
    *   **Port:** 80
    *   **Source:** Anywhere (0.0.0.0/0)
4.  Open your browser and visit `http://<TARGET_INSTANCE_PUBLIC_IP>`.
5.  You should see the **Welcome to nginx!** page.

---

