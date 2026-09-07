variable "proxmox_api_url" {
  description = "Proxmox API endpoint, e.g. https://192.168.1.10:8006/api2/json"
  type        = string
  default     = "https://192.168.1.10:8006/api2/json"
}

variable "proxmox_api_token_id" {
  description = "API token ID, format: user@realm!tokenname (e.g. terraform@pve!tf)"
  type        = string
  sensitive   = true
}

variable "proxmox_api_token_secret" {
  description = "API token secret"
  type        = string
  sensitive   = true
}

variable "target_node" {
  description = "Proxmox node to deploy to"
  type        = string
  default     = "host1"
}

variable "proxmox_nodes" {
  description = "All nodes in the homelab cluster, for future per-resource/round-robin placement (e.g. element(var.proxmox_nodes, count.index % length(var.proxmox_nodes)))"
  type        = list(string)
  default     = ["host1", "pve2", "pve3"]
}
