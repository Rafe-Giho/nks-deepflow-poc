Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "current context:"
kubectl config current-context

Write-Host "`nnodes:"
kubectl get nodes -o wide

Write-Host "`ncalico pods:"
kubectl -n kube-system get pods -o wide | Select-String -Pattern "calico|typha" -CaseSensitive:$false

Write-Host "`nkube-proxy check:"
$kubeProxy = kubectl -n kube-system get daemonset kube-proxy --ignore-not-found
if ([string]::IsNullOrWhiteSpace($kubeProxy)) {
  Write-Host "kube-proxy DaemonSet not found. This is expected for Calico-eBPF mode."
} else {
  Write-Host $kubeProxy
  Write-Host "kube-proxy exists. Confirm whether this cluster is Calico-VXLAN rather than Calico-eBPF."
}

Write-Host "`nworker node OS/kernel:"
kubectl get nodes -o jsonpath="{range .items[*]}{.metadata.name}{' '}{.status.nodeInfo.osImage}{' '}{.status.nodeInfo.kernelVersion}{'\n'}{end}"

