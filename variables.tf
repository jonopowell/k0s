variable "location" {
  description = "The Azure region to deploy the resources in."
  default     = "UK South"
}

variable "cp-nodes" {
  type = list(string)
  default = ["c0","c1"]
}

variable "wk-nodes" {
  type = list(string)
  default = ["n0","n1"]
}

variable "cp_ports" {
  type = list(string)
  default = [6443,8132,9443]
}
