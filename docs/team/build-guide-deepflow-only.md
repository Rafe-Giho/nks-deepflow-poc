# DeepFlow 단독 구축 가이드

이 문서는 NHN Cloud NKS에서 Istio 없이 DeepFlow만 설치해 Pod/Service L4/L7 traffic 가시성을 확인하는 구축 절차입니다. 명령어는 Ubuntu 계열 Linux 기준이며, 저장소 루트에서 실행한다고 가정합니다.

이 문서는 실제 NKS 클러스터에서 검증한 DeepFlow 구축/가시성 확인 과정을 기준으로 작성했습니다. 단, 작업 도구 설치, Gateway API/NGINX Gateway Fabric/cert-manager 신규 설치, DNS 등록은 새 환경에서 필요한 준비 절차이므로 환경에 맞게 수행합니다.

아래 순서대로 진행하면 됩니다.

```text
NKS 사전 점검
  -> Cinder StorageClass 준비
  -> DeepFlow 설치
  -> DeepFlow Agent 설정
  -> web-was-db 앱 배포
  -> 트래픽 발생
  -> ClickHouse/Grafana 확인
```

## 0. 검증 범위

검증 완료된 절차:

- `sgh-cinder-sc` StorageClass 기준 DeepFlow PVC Bound 확인
- DeepFlow Helm chart `7.1.002` 설치 및 Pod/Service/PVC 상태 확인
- DeepFlow chart가 생성한 ClickHouse/Grafana/MySQL 사용
- DeepFlow controller API로 agent group 설정 적용
- continuous profiling 비활성화 후 `deepflow-agent` DaemonSet 정상화 확인
- `k8s-3tier-app`의 web-was-db Pod/Gateway 상태 확인
- 외부 URL 요청 `status=200` 확인
- DeepFlow ClickHouse에서 `vtap_map`, `pod_map`, `pod_service_map`, L4/L7 log, metric 증가 확인
- DeepFlow ClickHouse에서 `sgh-*` Pod/Service tag와 HTTP L7 log 확인
- DeepFlow Grafana port-forward 접속 경로 확인

환경별로 달라지는 절차:

- 작업 머신의 `kubectl`, `helm`, `jq`, `curl` 설치
- NGINX Gateway Fabric, Gateway API CRD, cert-manager가 이미 설치되어 있는지 여부
- Gateway LoadBalancer IP와 DNS 등록
- 인증서 발급 상태
- worker node 수와 node flavor

노드 증설은 이 문서의 구축 절차에 포함하지 않습니다. 클러스터 리소스가 부족해 Pod가 Pending, Evicted, CrashLoopBackOff 상태가 될 때 별도 인프라 조치로 판단합니다.

## 1. 목표

```text
NHN Cloud NKS
  -> DeepFlow
       -> deepflow-agent
       -> deepflow-server
       -> MySQL
       -> ClickHouse
       -> Grafana
  -> web-was-db traffic
```

성공 기준:

- DeepFlow Agent가 모든 worker node에서 Ready입니다.
- DeepFlow Server/App/MySQL/ClickHouse/Grafana가 Ready입니다.
- DeepFlow PVC가 `sgh-cinder-sc` StorageClass로 Bound입니다.
- web-was-db traffic이 DeepFlow ClickHouse와 Grafana에서 Pod/Service/Namespace 기준으로 보입니다.
- Istio, ztunnel, waypoint, Kiali는 이 경로의 필수 구성요소가 아닙니다.

## 2. 전제

이 문서는 이미 사용할 수 있는 NKS 클러스터와 kubeconfig가 있다는 전제로 작성합니다. kubeconfig 경로나 프로젝트 경로는 문서에 고정하지 않습니다.

필수 전제:

- NHN Cloud NKS 클러스터가 준비되어 있습니다.
- `kubectl` context가 대상 NKS 클러스터를 바라보고 있습니다.
- NKS `csi-cinder` add-on이 설치되어 있습니다.
- Cinder CSI provisioner는 `cinder.csi.openstack.org`입니다.
- DeepFlow PVC는 `sgh-cinder-sc` StorageClass를 사용합니다.
- DeepFlow chart가 ClickHouse, Grafana, MySQL을 함께 생성합니다.
- Terraform 구성은 마지막 IaC 전환 단계에서 별도로 진행합니다.

## 3. 도구 설치

작업 머신에 `kubectl`, `helm`, `jq`, `curl`이 필요합니다.

```bash
sudo apt-get update
sudo apt-get install -y curl wget ca-certificates gnupg lsb-release unzip jq git

curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

helm version
kubectl version --client
jq --version
```

## 4. NKS 사전 점검

대상 클러스터와 기본 권한을 확인합니다.

```bash
kubectl config current-context
kubectl cluster-info
kubectl get nodes -o wide

kubectl auth can-i create daemonsets.apps -n deepflow
kubectl auth can-i create deployments.apps -n deepflow
kubectl auth can-i create statefulsets.apps -n deepflow
kubectl auth can-i create persistentvolumeclaims -n deepflow
kubectl auth can-i create storageclasses.storage.k8s.io
```

Cinder CSI add-on 상태를 확인합니다.

```bash
kubectl get csidriver | grep cinder
kubectl -n kube-system get pods -o wide | grep -i cinder
```

기대 기준:

```text
node: Ready
CSIDriver: cinder.csi.openstack.org
Cinder CSI Pod: Running
```

## 5. Cinder StorageClass 준비

DeepFlow PVC가 사용할 StorageClass를 적용합니다.

```bash
kubectl apply -f infra/observability/deepflow/storageclass/sc-cinder.yaml
```

적용 결과를 확인합니다.

```bash
kubectl get storageclass sgh-cinder-sc \
  -o jsonpath='{.provisioner}{"\t"}{.parameters.type}{"\t"}{.reclaimPolicy}{"\t"}{.volumeBindingMode}{"\n"}'
```

기대값:

```text
cinder.csi.openstack.org    General HDD    Retain    Immediate
```

현재 manifest 기준:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: sgh-cinder-sc
provisioner: cinder.csi.openstack.org
parameters:
  type: General HDD
reclaimPolicy: Retain
volumeBindingMode: Immediate
```

주의:

- 이미 생성된 StorageClass의 `parameters`, `reclaimPolicy`, `volumeBindingMode`는 변경이 제한됩니다.
- 다른 값으로 이미 존재하면 무리하게 수정하지 말고 새 StorageClass를 만들거나 DeepFlow values의 `global.storageClass`를 기존 이름에 맞춥니다.

## 6. DeepFlow 설치

DeepFlow Helm repo를 추가합니다.

```bash
helm repo add deepflow https://deepflowio.github.io/deepflow --force-update
helm repo update deepflow
```

values 파일이 `sgh-cinder-sc`를 사용하고 있는지 확인합니다.

```bash
cat infra/observability/deepflow/values/poc-values.yaml
```

기대값:

```yaml
global:
  replicas: 1
  storageClass: sgh-cinder-sc
```

DeepFlow를 설치합니다.

```bash
helm upgrade --install deepflow deepflow/deepflow \
  --namespace deepflow \
  --create-namespace \
  --version "7.1.002" \
  -f infra/observability/deepflow/values/poc-values.yaml \
  --wait \
  --timeout 20m
```

설치 상태를 확인합니다.

```bash
helm status deepflow -n deepflow
kubectl -n deepflow get pods,svc,pvc -o wide
kubectl -n deepflow get ds,deploy,sts -o wide
```

PVC가 `sgh-cinder-sc`로 Bound인지 확인합니다.

```bash
kubectl -n deepflow get pvc \
  -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,SC:.spec.storageClassName,VOLUME:.spec.volumeName'
```

기대 상태:

```text
deepflow-agent DaemonSet: desired/current/ready 수가 worker node 수와 일치
deepflow-server: Running
deepflow-app: Running
deepflow-grafana: Running
deepflow-mysql: Running
deepflow-clickhouse: Running
PVC: Bound, SC=sgh-cinder-sc
```

## 7. DeepFlow Agent 설정

이 PoC의 목표는 L4/L7 flow 관측입니다. NKS 환경에서 continuous profiling이 agent 안정성에 영향을 줄 수 있으므로, flow 수집은 유지하고 profiler만 비활성화합니다.

유지되는 기능:

- L4 flow log
- L7 request log
- Flow metrics
- Kubernetes AutoTagging

비활성화되는 기능:

- On-CPU profiling
- Off-CPU profiling
- Memory profiling

터미널 1에서 DeepFlow controller API를 port-forward 합니다.

```bash
kubectl -n deepflow port-forward svc/deepflow-server 20417:20417
```

터미널 2에서 agent group 설정을 적용합니다.

```bash
GROUP_LCUUID="$(
  curl -sS http://127.0.0.1:20417/v1/vtap-groups/ \
    | jq -r '.DATA[] | select(.NAME=="default") | .LCUUID'
)"

test -n "${GROUP_LCUUID}"

cat >/tmp/deepflow-agent-profile-off.yaml <<'YAML'
inputs:
  proc:
    process_matcher:
      - match_regex: .*
        enabled_features: [proc.gprocess_info]
  ebpf:
    profile:
      on_cpu:
        disabled: true
      off_cpu:
        disabled: true
      memory:
        disabled: true
YAML

curl -sS -X POST \
  "http://127.0.0.1:20417/v1/agent-group-configuration/${GROUP_LCUUID}/yaml" \
  -H "Content-Type: application/yaml" \
  --data-binary @/tmp/deepflow-agent-profile-off.yaml

kubectl -n deepflow rollout restart ds/deepflow-agent
kubectl -n deepflow rollout status ds/deepflow-agent --timeout=5m
kubectl -n deepflow get pods -l component=deepflow-agent -o wide
```

기대 상태:

```text
모든 deepflow-agent Pod가 1/1 Running
DaemonSet ready 수가 worker node 수와 일치
```

설정 적용이 끝나면 터미널 1의 port-forward는 종료해도 됩니다.

## 8. web-was-db 앱 배포

이 저장소의 실제 검증 앱은 `k8s-3tier-app`입니다.

DeepFlow 가시성 검증에서 확인한 핵심은 앱 Pod/Gateway가 정상 상태이고, 외부 요청이 `status=200`으로 처리되며, 그 traffic이 DeepFlow ClickHouse/Grafana에서 보이는지입니다.

NGINX Gateway Fabric, Gateway API CRD, cert-manager가 이미 설치되어 있으면 플랫폼 설치 명령은 건너뛰고 앱 manifest 적용부터 진행합니다. 신규 클러스터라면 아래 플랫폼 설치 명령을 먼저 수행합니다.

설치 여부를 먼저 확인합니다.

```bash
kubectl get crd gatewayclasses.gateway.networking.k8s.io
kubectl get gatewayclass nginx
kubectl -n nginx-gateway get pods
kubectl -n cert-manager get pods
```

아직 설치되어 있지 않다면 Gateway API CRD를 설치합니다.

```bash
NGF_VERSION="v2.6.0"
NGF_CHART_VERSION="2.6.0"
CERT_MANAGER_VERSION="v1.20.2"

kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=${NGF_VERSION}" \
  | kubectl apply -f -
```

NGINX Gateway Fabric을 설치합니다.

```bash
helm upgrade --install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
  --namespace nginx-gateway \
  --create-namespace \
  --version "${NGF_CHART_VERSION}" \
  --wait

kubectl -n nginx-gateway get pods,svc -o wide
kubectl get gatewayclass nginx
```

cert-manager를 설치합니다.

```bash
helm upgrade --install cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version "${CERT_MANAGER_VERSION}" \
  --set crds.enabled=true \
  --set config.enableGatewayAPI=true \
  --wait

kubectl -n cert-manager get pods,svc -o wide
kubectl get crd certificates.cert-manager.io
kubectl get crd clusterissuers.cert-manager.io
```

앱 manifest를 적용합니다.

```bash
kubectl apply -f k8s-3tier-app
```

앱 상태를 확인합니다.

```bash
kubectl get pods -n sgh-web-ns -o wide
kubectl get pods -n sgh-was-ns -o wide
kubectl get pods -n sgh-db-ns -o wide
kubectl get gateway,httproute -n sgh-web-ns
kubectl get svc -n sgh-web-ns
```

기대 상태:

```text
sgh-web: Running
sgh-was: Running
sgh-db: Running
Gateway/HTTPRoute: Accepted=True
Gateway Service: EXTERNAL-IP 할당
```

Gateway LoadBalancer IP가 나온 뒤 DNS를 등록합니다. DNS 등록 후 아래처럼 앱 URL을 환경에 맞게 설정합니다.

```bash
APP_URL="https://<your-domain>/sgh/"
```

## 9. 트래픽 발생

외부 URL로 HTTP 요청을 발생시킵니다.

```bash
for i in $(seq 1 20); do
  curl -k -s -o /dev/null \
    -w "request=${i} status=%{http_code} time=%{time_total}\n" \
    "${APP_URL}"
done
```

기대값:

```text
status=200
```

Pod 내부 DNS와 Service 경로도 확인하려면 임시 curl Pod를 사용합니다.

```bash
kubectl run sgh-curl-test \
  -n sgh-web-ns \
  --image=curlimages/curl:8.10.1 \
  --restart=Never \
  --rm -it \
  -- sh -lc 'curl -sS -o /dev/null -w "was=%{http_code}\n" http://sgh-was-svc.sgh-was-ns.svc.cluster.local:8080 || true'
```

## 10. DeepFlow ClickHouse 수집 확인

DeepFlow ClickHouse에 메타데이터, L4/L7 로그, metric이 들어오는지 확인합니다.

```bash
kubectl -n deepflow exec deepflow-clickhouse-0 -- clickhouse-client --query '
SELECT '\''vtap_map'\'' AS table_name, count() AS rows FROM flow_tag.vtap_map
UNION ALL SELECT '\''pod_map'\'', count() FROM flow_tag.pod_map
UNION ALL SELECT '\''pod_service_map'\'', count() FROM flow_tag.pod_service_map
UNION ALL SELECT '\''l4_flow_log'\'', count() FROM flow_log.l4_flow_log
UNION ALL SELECT '\''l7_flow_log'\'', count() FROM flow_log.l7_flow_log
UNION ALL SELECT '\''network_1m'\'', count() FROM flow_metrics.`network.1m`
UNION ALL SELECT '\''network_1s'\'', count() FROM flow_metrics.`network.1s`
UNION ALL SELECT '\''application_1m'\'', count() FROM flow_metrics.`application.1m`
FORMAT PrettyCompact'
```

판단 기준:

```text
vtap_map: worker node 수와 동일한 값
pod_map: 0보다 큰 값
pod_service_map: 0보다 큰 값
l4_flow_log: traffic 발생 후 증가
l7_flow_log: traffic 발생 후 증가
network_1m/network_1s: traffic 발생 후 증가
application_1m: traffic 발생 후 증가
```

## 11. 앱 리소스 태그 확인

DeepFlow가 `sgh-*` Pod/Namespace/Service를 Kubernetes tag로 식별하는지 확인합니다.

```bash
kubectl -n deepflow exec deepflow-clickhouse-0 -- clickhouse-client --query '
SELECT
  p.name AS pod,
  ns.name AS namespace,
  n.name AS node,
  s.name AS service
FROM flow_tag.pod_map AS p
LEFT JOIN flow_tag.pod_ns_map AS ns ON p.pod_ns_id = ns.id
LEFT JOIN flow_tag.pod_node_map AS n ON p.pod_node_id = n.id
LEFT JOIN flow_tag.pod_service_map AS s ON p.pod_service_id = s.id
WHERE p.name LIKE '\''sgh%'\'' OR s.name LIKE '\''sgh%'\''
ORDER BY namespace, pod, service
FORMAT PrettyCompact'
```

기대 항목:

```text
sgh-db-sts-0
sgh-was-dpl-...
sgh-web-dpl-...
sgh-web-gateway-nginx-...
sgh-db-svc
sgh-was-svc
sgh-web-svc
sgh-web-gateway-nginx
```

## 12. L7 로그 확인

`sgh-*` Pod가 포함된 L7 로그를 확인합니다.

```bash
kubectl -n deepflow exec deepflow-clickhouse-0 -- clickhouse-client --query '
SELECT
  l.time,
  p0.name AS client_pod,
  p1.name AS server_pod,
  l.request_type,
  l.request_domain,
  l.request_resource,
  l.response_code,
  l.biz_protocol
FROM flow_log.l7_flow_log AS l
LEFT JOIN flow_tag.pod_map AS p0 ON l.pod_id_0 = p0.id
LEFT JOIN flow_tag.pod_map AS p1 ON l.pod_id_1 = p1.id
WHERE p0.name LIKE '\''sgh%'\'' OR p1.name LIKE '\''sgh%'\''
ORDER BY l.time DESC
LIMIT 20
FORMAT PrettyCompact'
```

기대 기준:

```text
HTTP 요청이 보입니다.
response_code가 200 또는 앱 응답 코드로 보입니다.
client_pod/server_pod 중 하나 이상이 sgh-* Pod로 매핑됩니다.
```

## 13. Grafana 확인

DeepFlow Grafana에 접속합니다.

```bash
kubectl -n deepflow port-forward svc/deepflow-grafana 3000:80
```

브라우저에서 접속합니다.

```text
URL: http://localhost:3000
ID: admin
PW: deepflow
```

확인 항목:

- `sgh-web-ns`, `sgh-was-ns`, `sgh-db-ns` namespace
- `sgh-web-svc`, `sgh-was-svc`, `sgh-db-svc` service
- `sgh-web-gateway-nginx` gateway data plane Pod
- L4 flow
- L7 request log
- HTTP response code
- Kubernetes Pod/Service/Namespace tag

## 14. 문제 해결

### Agent가 Ready가 아닐 때

```bash
kubectl -n deepflow get pods -l component=deepflow-agent -o wide
kubectl -n deepflow logs ds/deepflow-agent --tail=200
```

다음 로그가 보이면 7장의 profiler 비활성화 설정을 적용했는지 확인합니다.

```text
continuous profile staring failed
eBPF load programs failed
bpf load ... failed
```

### PVC가 Pending일 때

```bash
kubectl get storageclass sgh-cinder-sc -o yaml
kubectl -n deepflow get pvc -o wide
kubectl -n deepflow describe pvc
kubectl -n kube-system get pods -o wide | grep -i cinder
```

확인 포인트:

- NKS `csi-cinder` add-on이 설치되어 있는지
- `sgh-cinder-sc` provisioner가 `cinder.csi.openstack.org`인지
- NHN Cloud Block Storage quota가 충분한지

### 데이터가 ClickHouse에 안 들어올 때

```bash
kubectl -n deepflow get pods,svc,pvc -o wide
kubectl -n deepflow logs deploy/deepflow-server --tail=120
kubectl -n deepflow logs ds/deepflow-agent --tail=120
```

확인 포인트:

- `deepflow-agent` ready 수가 worker node 수와 일치하는지
- `vtap_map` count가 worker node 수와 일치하는지
- traffic 발생 후 `l4_flow_log`, `l7_flow_log`, `network.1m`, `application.1m`이 증가하는지

### Grafana Pod Map에 이름 없는 노드가 보일 때

Pod Map에 아이콘은 보이지만 이름이 비어 있는 노드가 있을 수 있습니다. 대부분 traffic은 수집됐지만 DeepFlow의 Kubernetes tag dictionary가 아직 Pod 이름을 반영하지 못한 상태입니다.

먼저 Grafana 원본 데이터에서 `resource_id`는 있는데 `resource`가 비어 있는지 확인합니다.

```text
Pod Map panel
  -> Inspect
  -> Data
```

현재 Pod는 존재하는데 DeepFlow가 이름을 못 붙이면 DeepFlow server를 재시작해 Kubernetes resource gather와 tag dictionary refresh를 다시 유도합니다.

```bash
kubectl -n deepflow rollout restart deploy/deepflow-server
kubectl -n deepflow rollout status deploy/deepflow-server --timeout=5m
```

1분 정도 후 대시보드를 새로고침하거나, 필요하면 tag map을 확인합니다.

```bash
kubectl -n deepflow exec deepflow-clickhouse-0 -- clickhouse-client --query "
SELECT
  id,
  name,
  pod_ns_id,
  pod_node_id,
  pod_service_id
FROM flow_tag.pod_map
WHERE name = '' OR name LIKE 'coredns%'
ORDER BY id
FORMAT PrettyCompact"
```

이 조치는 수동 태깅이 아닙니다. DeepFlow의 자동 Kubernetes tag 동기화를 다시 트리거하는 작업입니다. 애플리케이션 Pod에는 직접 영향이 없지만, 재시작 중 DeepFlow UI/API가 잠시 불안정할 수 있습니다.

## 15. Terraform 위치

NKS Terraform 구성은 이 DeepFlow-only 검증 절차의 선행 조건이 아닙니다. 다음 단계에서 별도로 진행합니다.

```text
DeepFlow-only 검증 성공
  -> web-was-db 검증
  -> CI/CD 정리
  -> NKS/Istio/DeepFlow Terraform 코드화
```

관련 문서:

- `infra/terraform/nhn-nks/README.md`
- `infra/terraform/modules/deepflow/README.md`

## 16. 정리 명령

아래 명령은 리소스를 삭제합니다. 실제 환경에서는 별도 승인 후 실행합니다.

```bash
# helm uninstall deepflow -n deepflow
# kubectl delete namespace deepflow
# kubectl delete storageclass sgh-cinder-sc
```

## 17. 공식 문서

- DeepFlow single K8s install: https://deepflow.io/docs/ce-install/single-k8s/
- DeepFlow agent advanced config: https://deepflow.io/docs/best-practice/agent-advanced-config/
- DeepFlow continuous profiling config: https://deepflow.io/docs/features/continuous-profiling/configuration/
- NHN Cloud NKS user guide: https://docs.nhncloud.com/ko/Container/NKS/ko/user-guide/
