terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = "${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}"
  insecure  = true # self-signed cert on host1 — set false if you've installed a real one
}

# --- Example resource: a fresh LXC to cut your teeth on Terraform+Ansible before touching k3s ---
# Uncomment and adjust once your API token is in place, then `terraform plan`.

# resource "proxmox_virtual_environment_container" "example" {
#   node_name = var.target_node
#   vm_id     = 140
#
#   initialization {
#     hostname = "tf-test-01"
#
#     ip_config {
#       ipv4 {
#         address = "192.168.1.140/24"
#         gateway = "192.168.1.1"
#       }
#     }
#
#     user_account {
#       keys = [file("~/.ssh/id_rsa.pub")]
#     }
#   }
#
#   disk {
#     datastore_id = "local-lvm"
#     size         = 8
#   }
#
#   cpu {
#     cores = 1
#   }
#
#   memory {
#     dedicated = 512
#   }
#
#   operating_system {
#     template_file_id = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
#     type              = "debian"
#   }
#
#   network_interface {
#     name   = "eth0"
#     bridge = "vmbr0"
#   }
# }
