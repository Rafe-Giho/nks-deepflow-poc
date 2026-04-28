output "cluster_name" {
  description = "NKS cluster name."
  value       = nhncloud_kubernetes_cluster_v1.this.name
}

output "cluster_uuid" {
  description = "NKS cluster UUID."
  value       = nhncloud_kubernetes_cluster_v1.this.uuid
}

output "calico_mode" {
  description = "Requested NKS Calico mode."
  value       = var.calico_mode
}

output "kubernetes_version" {
  description = "Requested Kubernetes version."
  value       = var.kubernetes_version
}

