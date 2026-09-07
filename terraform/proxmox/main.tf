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
# node_name below is pinned to var.target_node (host1). Once a resource actually needs to land
# on pve2/pve3, switch to var.proxmox_nodes (see variables.tf) for per-resource or round-robin
# placement instead of adding more single-node defaults.

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

# --- k3s1: control-plane node, cloned from the debian12-cloudinit template (vm_id 9000,
# built manually on host1 via qm, not TF-managed). Agents k3s2/k3s3 follow the same pattern
# on pve2/pve3 once local-zfs storage is re-registered there and each node has its own
# template (storage is node-local — no shared/replicated storage across the cluster yet). ---
resource "proxmox_virtual_environment_vm" "k3s1" {
  name      = "k3s1"
  node_name = var.target_node # host1
  vm_id     = 201

  clone {
    vm_id = 9000
    full  = true # independent disk, not tied to the template's lifecycle
  }

  agent {
    enabled = true
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 4096
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 20
  }

  network_device {
    bridge = "vmbr0"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "192.168.1.21/24"
        gateway = "192.168.1.1"
      }
    }

    user_account {
      keys = [file(pathexpand("~/.ssh/id_ed25519.pub"))]
    }
  }
}
