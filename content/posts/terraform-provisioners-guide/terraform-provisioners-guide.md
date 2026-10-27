![Terraform](../images/terraform-logo.svg)

# Terraform Provisioners Guide

Provisioners execute scripts or commands on local or remote machines as part of resource creation or destruction. They are a last resort — prefer native resource arguments, cloud-init, or configuration management tools when possible.

## When to Use Provisioners

| Use Case | Better Alternative |
|----------|-------------------|
| Install packages on EC2 | `user_data` / cloud-init |
| Configure a server | Ansible, Chef, Puppet |
| Run a one-off script after creation | `local-exec` (acceptable) |
| Bootstrap a cluster | `null_resource` + `local-exec` |
| Upload a config file | `file` provisioner or `templatefile()` + `user_data` |

Provisioners should be used only when there is no declarative alternative available.

## local-exec

Runs a command on the machine where Terraform is executed (your workstation or CI runner). Does not require any connectivity to the target resource.

```hcl
variable "environment" {
  type    = string
  default = "dev"
}

resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"

  tags = {
    Name = "web-${var.environment}"
  }

  provisioner "local-exec" {
    command = "echo 'Instance ${self.id} created in ${var.environment}' >> instances.log"
  }
}
# Result: appends the instance ID to a local log file after creation
```

### local-exec with Working Directory and Environment Variables

```hcl
resource "aws_instance" "app" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"

  provisioner "local-exec" {
    command     = "./deploy.sh"
    working_dir = "${path.module}/scripts"

    environment = {
      INSTANCE_ID = self.id
      ENVIRONMENT = var.environment
      PRIVATE_IP  = self.private_ip
    }
  }
}
# Result: runs deploy.sh from the scripts/ directory with env vars set
```

### local-exec with Interpreter

Use a specific shell or scripting language.

```hcl
# Run a Python script
resource "null_resource" "python_script" {
  provisioner "local-exec" {
    command     = "scripts/process_data.py --env ${var.environment}"
    interpreter = ["python3"]
  }
}

# Inline Python (passed to -c)
resource "null_resource" "python_inline" {
  provisioner "local-exec" {
    command     = "import json; print(json.dumps({'env': '${var.environment}'}))"
    interpreter = ["python3", "-c"]
  }
}

# PowerShell on Windows
resource "null_resource" "windows_script" {
  provisioner "local-exec" {
    command     = "Get-Date | Out-File -Append provisioner.log"
    interpreter = ["PowerShell", "-Command"]
  }
}

# Bash explicit
resource "null_resource" "bash_script" {
  provisioner "local-exec" {
    command     = "echo $HOSTNAME && date"
    interpreter = ["/bin/bash", "-c"]
  }
}
```

### local-exec with when = destroy

Run a command when the resource is destroyed.

```hcl
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"

  provisioner "local-exec" {
    command = "echo 'Instance ${self.id} created' >> lifecycle.log"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "echo 'Instance ${self.id} destroyed' >> lifecycle.log"
  }
}
# Result: logs both creation and destruction events
```

## remote-exec

Runs commands on the remote resource via SSH or WinRM. Requires a `connection` block.

```hcl
variable "ssh_key_path" {
  type        = string
  default     = "~/.ssh/id_rsa"
  description = "Path to the private SSH key"
}

variable "ssh_user" {
  type    = string
  default = "ubuntu"
}

resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"
  key_name      = "my-key"

  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.ssh_key_path)
    host        = self.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y nginx",
      "sudo systemctl enable --now nginx",
    ]
  }
}
# Result: installs and starts nginx on the new instance via SSH
```

### remote-exec with Script File

```hcl
resource "aws_instance" "app" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"
  key_name      = "my-key"

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("~/.ssh/id_rsa")
    host        = self.public_ip
  }

  provisioner "remote-exec" {
    script = "${path.module}/scripts/bootstrap.sh"
  }
}
# Result: uploads and executes bootstrap.sh on the remote instance
```

### remote-exec with Multiple Scripts

```hcl
resource "aws_instance" "app" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"
  key_name      = "my-key"

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("~/.ssh/id_rsa")
    host        = self.public_ip
  }

  provisioner "remote-exec" {
    scripts = [
      "${path.module}/scripts/install-deps.sh",
      "${path.module}/scripts/configure-app.sh",
      "${path.module}/scripts/start-service.sh",
    ]
  }
}
# Result: runs all three scripts in order on the remote machine
```

## file Provisioner

Copies files or directories from the local machine to the remote resource.

```hcl
resource "aws_instance" "app" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"
  key_name      = "my-key"

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("~/.ssh/id_rsa")
    host        = self.public_ip
  }

  # Copy a single file
  provisioner "file" {
    source      = "${path.module}/configs/app.conf"
    destination = "/tmp/app.conf"
  }

  # Copy an entire directory
  provisioner "file" {
    source      = "${path.module}/scripts/"
    destination = "/opt/scripts"
  }

  # Use content instead of a file (inline content)
  provisioner "file" {
    content     = templatefile("${path.module}/templates/config.tpl", {
      db_host = aws_db_instance.main.endpoint
      db_name = "myapp"
    })
    destination = "/etc/myapp/config.yml"
  }

  # Then run the copied script
  provisioner "remote-exec" {
    inline = [
      "chmod +x /opt/scripts/*.sh",
      "sudo /opt/scripts/setup.sh",
    ]
  }
}
# Result: uploads config and scripts, then executes them remotely
```

## Connection Block

Defines how Terraform connects to the remote resource for `remote-exec` and `file` provisioners.

### SSH Connection

```hcl
connection {
  type        = "ssh"
  user        = "ubuntu"
  private_key = file("~/.ssh/id_rsa")
  host        = self.public_ip
  port        = 22
  timeout     = "5m"
}
```

### SSH via Bastion Host

```hcl
connection {
  type        = "ssh"
  user        = "ec2-user"
  private_key = file("~/.ssh/id_rsa")
  host        = self.private_ip

  bastion_host        = var.bastion_ip
  bastion_user        = "ec2-user"
  bastion_private_key = file("~/.ssh/bastion_key")
}
```

### WinRM Connection (Windows)

```hcl
connection {
  type     = "winrm"
  user     = "Administrator"
  password = var.admin_password
  host     = self.public_ip
  port     = 5986
  https    = true
  insecure = true
  timeout  = "10m"
}
```

### Connection Reference

| Argument | Description |
|----------|-------------|
| `type` | `ssh` or `winrm` |
| `user` | Remote username |
| `private_key` | SSH private key content |
| `password` | Password (SSH or WinRM) |
| `host` | Target host IP or hostname |
| `port` | Connection port (default: 22 for SSH, 5985/5986 for WinRM) |
| `timeout` | Connection timeout (default: `5m`) |
| `bastion_host` | Bastion/jump host for SSH |
| `bastion_user` | Bastion username |
| `bastion_private_key` | Bastion SSH key |
| `agent` | Use SSH agent (`true`/`false`) |
| `host_key` | Expected remote host key for verification |

## null_resource and triggers

`null_resource` doesn't create infrastructure — it exists only to run provisioners. Use `triggers` to control when it re-executes.

```hcl
variable "app_version" {
  type        = string
  default     = "1.0.0"
  description = "Application version to deploy"
}

resource "null_resource" "deploy" {
  triggers = {
    app_version = var.app_version
    script_hash = filemd5("${path.module}/scripts/deploy.sh")
  }

  provisioner "local-exec" {
    command = "./scripts/deploy.sh ${var.app_version}"
  }
}
# Result: re-runs deploy.sh whenever app_version changes or deploy.sh is modified
```

### Common Trigger Patterns

```hcl
# Re-run when any instance changes
resource "null_resource" "post_deploy" {
  triggers = {
    instance_ids = join(",", aws_instance.app[*].id)
  }

  provisioner "local-exec" {
    command = "ansible-playbook -i inventory.ini site.yml"
  }
}

# Re-run every apply (always trigger)
resource "null_resource" "always_run" {
  triggers = {
    always = timestamp()
  }

  provisioner "local-exec" {
    command = "echo 'This runs every apply at ${timestamp()}'"
  }
}

# Re-run when a file changes
resource "null_resource" "config_update" {
  triggers = {
    config_hash = filemd5("${path.module}/configs/app.conf")
  }

  provisioner "local-exec" {
    command = "scp configs/app.conf user@${aws_instance.app.public_ip}:/etc/app/"
  }
}
```

## terraform_data (Terraform 1.4+ Replacement for null_resource)

`terraform_data` is the built-in replacement for `null_resource` — no `hashicorp/null` provider needed.

```hcl
resource "terraform_data" "deploy" {
  triggers_replace = [
    var.app_version,
    filemd5("${path.module}/scripts/deploy.sh"),
  ]

  provisioner "local-exec" {
    command = "./scripts/deploy.sh ${var.app_version}"
  }
}
# Result: same behavior as null_resource but no external provider required
```

### terraform_data with input/output

```hcl
resource "terraform_data" "bootstrap" {
  input = aws_instance.web.public_ip

  provisioner "local-exec" {
    command = "ssh ubuntu@${self.output} 'sudo apt update && sudo apt install -y nginx'"
  }
}
# self.output exposes the input value for use in provisioners
```

## Provisioner Failure Behavior

### on_failure = continue

By default, a provisioner failure taints the resource. Use `on_failure = continue` to ignore errors.

```hcl
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"

  provisioner "local-exec" {
    command    = "optional-notification.sh ${self.id}"
    on_failure = continue
  }
}
# Result: if the script fails, Terraform continues without tainting the resource
```

### on_failure = fail (default)

```hcl
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"

  provisioner "remote-exec" {
    inline     = ["sudo /opt/setup.sh"]
    on_failure = fail
  }
}
# Result: if setup.sh fails, the resource is tainted and will be recreated on next apply
```

## Destroy-Time Provisioners

Run cleanup commands when a resource is destroyed.

```hcl
resource "aws_instance" "app" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"

  # Creation-time provisioner
  provisioner "local-exec" {
    command = "ansible-playbook setup.yml -e host=${self.public_ip}"
  }

  # Destroy-time provisioner
  provisioner "local-exec" {
    when    = destroy
    command = "ansible-playbook cleanup.yml -e host=${self.public_ip}"
  }
}
# Note: destroy-time provisioners can only reference self.* attributes
# They CANNOT reference other resources or variables
```

### Limitations of Destroy-Time Provisioners

```hcl
# VALID — uses self.*
provisioner "local-exec" {
  when    = destroy
  command = "deregister-instance.sh ${self.id} ${self.private_ip}"
}

# INVALID — cannot reference other resources
# provisioner "local-exec" {
#   when    = destroy
#   command = "cleanup.sh ${aws_eip.web.public_ip}"  # ERROR
# }

# INVALID — cannot reference variables
# provisioner "local-exec" {
#   when    = destroy
#   command = "cleanup.sh ${var.environment}"  # ERROR
# }
```

## Practical Examples

### Format Disk, Install and Serve a Web Page

```hcl
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"
  key_name      = "my-key"

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("~/.ssh/id_rsa")
    host        = self.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkfs.xfs /dev/xvdh",
      "sudo yum install httpd -y",
      "sudo mount /dev/xvdh /var/www/html",
      "sudo sh -c \"echo 'Terraform Server Running' > /var/www/html/index.html\"",
      "sudo systemctl restart httpd",
    ]
  }
}
# Result: formats an attached EBS volume, installs Apache, mounts it, and serves a page
```

### Install nginx on Ubuntu

```hcl
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"
  key_name      = "my-key"

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("~/.ssh/id_rsa")
    host        = self.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get -y update",
      "sudo apt-get -y install nginx",
      "sudo service nginx start",
    ]
  }
}
# Result: installs and starts nginx on an Ubuntu instance
```

### Run kubectl Commands

```hcl
variable "kubeconfig" {
  type        = string
  sensitive   = true
  description = "Base64-encoded kubeconfig content"
}

variable "command" {
  type        = string
  default     = "get nodes"
  description = "kubectl command to run"
}

resource "null_resource" "kubectl" {
  provisioner "local-exec" {
    command     = "kubectl ${var.command} --kubeconfig <(echo $KUBECONFIG | base64 --decode)"
    interpreter = ["/bin/bash", "-c"]

    environment = {
      KUBECONFIG = var.kubeconfig
    }
  }
}
# Result: runs a kubectl command using a kubeconfig passed as a variable
# Uses process substitution to avoid writing the kubeconfig to disk
```

### Install kubectl and Configure EKS

```hcl
variable "region" {
  type    = string
  default = "us-west-2"
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
}

resource "null_resource" "kubectl_setup" {
  provisioner "local-exec" {
    command = <<-EOF
      set -e
      cd ~/bin
      curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.30.4/2024-09-11/bin/linux/amd64/kubectl
      chmod +x ./kubectl
      aws eks --region ${var.region} update-kubeconfig --name ${var.cluster_name}
    EOF
  }
}
# Result: downloads kubectl binary and configures kubeconfig for the EKS cluster
```

### Run Ansible After Instance Creation

```hcl
variable "ansible_playbook" {
  type    = string
  default = "site.yml"
}

resource "aws_instance" "app" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"

  tags = {
    Name = "app-server"
  }
}

resource "null_resource" "ansible" {
  triggers = {
    instance_id   = aws_instance.app.id
    playbook_hash = filemd5("${path.module}/${var.ansible_playbook}")
  }

  provisioner "local-exec" {
    command = <<-EOT
      ANSIBLE_HOST_KEY_CHECKING=False \
      ansible-playbook \
        -i '${aws_instance.app.public_ip},' \
        -u ubuntu \
        --private-key ~/.ssh/id_rsa \
        ${var.ansible_playbook}
    EOT
  }

  depends_on = [aws_instance.app]
}
# Result: runs the playbook after the instance is ready, re-runs if playbook changes
```

### Register Instance with Load Balancer

```hcl
resource "aws_instance" "web" {
  count         = 3
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"
}

resource "null_resource" "register_lb" {
  triggers = {
    instance_ids = join(",", aws_instance.web[*].id)
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws elbv2 register-targets \
        --target-group-arn ${aws_lb_target_group.web.arn} \
        --targets ${join(" ", [for i in aws_instance.web : "Id=${i.id}"])}
    EOT
  }
}
```

### Wait for Instance to be Ready

```hcl
resource "aws_instance" "app" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"
}

resource "null_resource" "wait_for_instance" {
  depends_on = [aws_instance.app]

  provisioner "local-exec" {
    command = <<-EOT
      until ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
        ubuntu@${aws_instance.app.public_ip} "echo ready" 2>/dev/null; do
        echo "Waiting for SSH..."
        sleep 10
      done
    EOT
  }
}
# Result: blocks until SSH is available on the new instance
```

### Generate Inventory File

```hcl
resource "aws_instance" "app" {
  count         = var.instance_count
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"
}

resource "null_resource" "inventory" {
  triggers = {
    instance_ips = join(",", aws_instance.app[*].public_ip)
  }

  provisioner "local-exec" {
    command = <<-EOT
      cat > inventory.ini << EOF
      [app_servers]
      ${join("\n", [for i, ip in aws_instance.app[*].public_ip : "${ip} ansible_user=ubuntu"])}
      EOF
    EOT
  }
}
# Result: generates an Ansible inventory file with all instance IPs
```

## self Reference

Inside a provisioner, `self` refers to the parent resource's attributes.

```hcl
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"

  provisioner "local-exec" {
    command = <<-EOT
      echo "ID:         ${self.id}"
      echo "Public IP:  ${self.public_ip}"
      echo "Private IP: ${self.private_ip}"
      echo "AZ:         ${self.availability_zone}"
      echo "Subnet:     ${self.subnet_id}"
    EOT
  }
}
# self.* gives access to all computed attributes of the resource
```

## Best Practices

1. **Prefer declarative alternatives** — use `user_data`, cloud-init, or Packer images instead of provisioners
2. **Use `null_resource` / `terraform_data`** for provisioners that aren't tied to a specific resource lifecycle
3. **Set `triggers`** so provisioners re-run when relevant inputs change
4. **Use `on_failure = continue`** for non-critical operations (notifications, logging)
5. **Keep provisioners idempotent** — scripts should be safe to run multiple times
6. **Avoid destroy-time provisioners** when possible — they can't reference variables or other resources
7. **Use `terraform_data`** (1.4+) instead of `null_resource` to avoid the null provider dependency
8. **Timeout considerations** — provisioners have no built-in timeout; add `timeout` to the connection or wrap commands with `timeout`
9. **Don't store secrets** in provisioner commands — they appear in state and plan output

## Quick Reference

| Provisioner | Runs On | Use Case |
|-------------|---------|----------|
| `local-exec` | Terraform machine | Run CLI tools, scripts, notifications |
| `remote-exec` | Target resource | Bootstrap, install packages, configure |
| `file` | Target resource | Upload config files, scripts |

| Argument | Description |
|----------|-------------|
| `when = create` | Run on creation (default) |
| `when = destroy` | Run on destruction |
| `on_failure = fail` | Taint resource on error (default) |
| `on_failure = continue` | Ignore errors and proceed |
| `self.*` | Reference parent resource attributes |
| `triggers` | Map that forces re-creation when values change (null_resource) |
| `triggers_replace` | List that forces replacement (terraform_data) |
