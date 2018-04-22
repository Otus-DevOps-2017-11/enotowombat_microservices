variable project {
  description = "Project ID"
  default = "docker-194015"
}

variable region {
  description = "Region"
  default     = "europe-west1"
}

variable zone {
  description = "Compute instance zone"
  default     = "europe-west1-b"
}

variable initial_node_count {
  description = "GKE Initial Node Count"
  default     = 2
}

variable gke_version {
  description = "GKE Version"
  default     = "1.8.8-gke.0"
}

variable disk_size {
  description = "GKE node disk size in gb"
  default     = 20
}

variable machine_type {
  description = "GKE node machine type"
  default     = "g1-small"
}
