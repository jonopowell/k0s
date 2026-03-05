variable "location" {
  description = "The Azure region to deploy the resources in."
  default     = "UK South"
}

variable "nodes" {
  type = list(string)
  default = ["c0","n0","n1"]
}