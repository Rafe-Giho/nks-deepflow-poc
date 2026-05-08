Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "current context:"
kubectl config current-context

Write-Host "`nnodes:"
kubectl get nodes -o wide

Write-Host "`nworker node OS/kernel:"
kubectl get nodes -o jsonpath="{range .items[*]}{.metadata.name}{' '}{.status.nodeInfo.osImage}{' '}{.status.nodeInfo.kernelVersion}{'\n'}{end}"

Write-Host "`nstorage classes:"
kubectl get storageclass

Write-Host "`ncalico pods:"
kubectl -n kube-system get pods -o wide | Select-String -Pattern "calico|typha" -CaseSensitive:$false

Write-Host "`ncalico felix signal:"
$calicoPods = @(kubectl -n kube-system get pods -o name | Where-Object { $_ -match "calico" })
foreach ($pod in $calicoPods) {
  Write-Host $pod
  kubectl -n kube-system logs $pod --tail=100 --all-containers |
    Select-String -Pattern "felix|bpf|kube-proxy" -CaseSensitive:$false |
    Select-Object -First 10
}

Write-Host "`nkube-proxy check:"
$kubeProxy = kubectl -n kube-system get daemonset kube-proxy --ignore-not-found
if ([string]::IsNullOrWhiteSpace($kubeProxy)) {
  Write-Host "kube-proxy DaemonSet not found. This is expected for Calico-eBPF mode."
} else {
  Write-Host $kubeProxy
  Write-Host "kube-proxy exists. Confirm whether this cluster is Calico-VXLAN rather than Calico-eBPF."
}

Write-Host "`ncluster permissions:"
kubectl auth can-i create customresourcedefinitions.apiextensions.k8s.io
kubectl auth can-i create daemonsets.apps -n istio-system
kubectl auth can-i create daemonsets.apps -n deepflow
kubectl auth can-i create deployments.apps -n deepflow
