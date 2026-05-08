# PoC #1 프로젝트 가이드

## 1. 프로젝트 정의

이 프로젝트의 현재 목표는 NHN Cloud NKS에서 **DeepFlow 단독 관측 경로**와 **Istio Ambient + Kiali mesh 가시화 경로**를 분리 검증하는 것입니다. 필요하면 Istio Ambient + Kiali 뒤에 DeepFlow를 추가해 두 관측 결과를 비교합니다.

1차 검증 구성:

```text
1. NHN Cloud NKS
   -> DeepFlow
   -> DeepFlow ClickHouse/Grafana

2. NHN Cloud NKS
   -> Istio Ambient
        -> ztunnel L4 mesh
        -> waypoint optional L7 policy/routing
   -> Prometheus
   -> Kiali
   -> optional DeepFlow
```

후속 단계:

1. smoke `web-was-db` 하네스로 가시성 검증
2. 실제 보유 `web-was-db` 배포
3. CI/CD 파이프라인 구성
4. 전체 구성을 Terraform 코드로 전환

## 2. 검증 우선순위

### 1순위. NHN Cloud NKS 조건 검증

NKS는 최종 실행 환경입니다. Istio Ambient와 DeepFlow가 요구하는 CNI, kernel, 권한, StorageClass 조건을 먼저 확인해야 합니다.

검증 목표:

- NKS worker node OS/kernel 확인
- Calico-VXLAN 또는 Calico-eBPF CNI 확인
- kube-system 권한과 CRD 설치 권한 확인
- default StorageClass 또는 DeepFlow용 StorageClass 확인
- privileged DaemonSet, hostNetwork, eBPF 수집 허용 여부 확인

### 2순위. Istio Ambient 구축

Ambient는 애플리케이션 Pod에 Envoy sidecar를 넣지 않고 mesh 기능을 적용하기 위한 핵심 계층입니다.

검증 목표:

- Gateway API CRD 설치
- `istioctl install --set profile=ambient` 기반 설치
- `istiod`, `istio-cni`, `ztunnel` Ready 확인
- namespace 라벨 `istio.io/dataplane-mode=ambient` 적용
- workload Pod에 `istio-proxy` sidecar가 없는지 확인
- L7 검증이 필요할 경우 waypoint 추가

주의할 점:

- Ambient의 기본 계층은 ztunnel 기반 L4입니다.
- L7 정책/라우팅/세밀한 HTTP 처리는 waypoint가 있어야 합니다.
- namespace에 `istio-injection=enabled`와 `istio.io/dataplane-mode=ambient`를 동시에 쓰면 안 됩니다.

### 3순위. DeepFlow 구축

DeepFlow는 PoC의 주 관측 도구입니다. eBPF 기반으로 L4 flow, L7 request log, AutoTracing을 수집하고 ClickHouse/Grafana로 저장/시각화합니다.

검증 목표:

- Helm chart 기반 DeepFlow 설치
- `deepflow-agent` DaemonSet Ready 확인
- `deepflow-server`, ClickHouse, Grafana Ready 확인
- Kubernetes resource AutoTagging 확인
- Pod/Service/Namespace 기준 flow 조회
- HTTP/PostgreSQL 등 L7 request log 조회
- Istio Ambient 적용 전후 trace/flow 차이 확인

주의할 점:

- DeepFlow는 자체 ClickHouse/Grafana 구성을 포함합니다.
- 기존 독립 ClickHouse/Grafana는 1차 경로가 아니라 참고 또는 대체 경로입니다.
- Ambient mTLS/HBONE 경로에서 DeepFlow가 L7를 어디까지 복원하는지는 실제 트래픽으로 검증해야 합니다.

### 4순위. Smoke web-was-db 검증

실제 애플리케이션 투입 전 최소한의 흐름을 재현합니다.

구성:

```text
http-client -> smoke-was HTTP service
sql-client  -> smoke-db PostgreSQL service
```

검증 목표:

- sidecar 없는 Pod 통신
- Ambient namespace 편입
- ztunnel 경유 여부
- DeepFlow에서 L4 flow 확인
- DeepFlow에서 HTTP/PostgreSQL L7 log 확인
- Grafana에서 서비스 간 호출 관계 확인

### 5순위. 실제 web-was-db + CI/CD

smoke 검증이 성공하면 사용자가 보유한 실제 `web-was-db`를 배포합니다.

진행 방향:

- 이미지 빌드
- NHN Container Registry 또는 지정 registry push
- Kubernetes manifest/Helm/Kustomize 배포
- CI/CD에서 `kubectl diff`, `kubectl apply`, rollout 검증
- DeepFlow Grafana에서 실제 호출 경로 확인

### 6순위. Terraform 전환

마지막 단계에서 재현 가능한 IaC로 묶습니다.

Terraform 관리 후보:

- NHN Cloud VPC/Subnet/Security Group
- NKS cluster/node group/add-on
- StorageClass 관련 설정
- Istio Ambient Helm/manifest 배포
- DeepFlow Helm 배포
- smoke/web-was-db Kubernetes 리소스

단, 현재 단계에서는 `terraform plan`까지만 검증하고 `apply`는 별도 승인 후 진행합니다.

## 3. 현재 하네스 판단

이전 구성은 Cilium/Hubble 중심 문서와 독립 ClickHouse/Grafana 골격이 중심이었습니다. 현재 목표 기준으로는 다음처럼 재정렬합니다.

| 영역 | 기존 상태 | 새 기준 |
| --- | --- | --- |
| Flow 수집 | Cilium/Hubble 문서 중심 | DeepFlow 중심 |
| Mesh | 기존 Istio sidecar 비교 대상으로만 언급 | Istio Ambient가 핵심 |
| 저장 | 직접 ClickHouse StatefulSet | DeepFlow ClickHouse 우선 |
| 시각화 | 직접 Grafana Deployment | DeepFlow Grafana 우선 |
| NKS CNI | Calico/Felix 대안 검토 | NKS 조건 확인 항목 |
| 앱 검증 | echo sample | smoke web-was-db |
| 최종 IaC | NKS Terraform만 존재 | NKS + Ambient + DeepFlow + app 순차 전환 |

## 4. 성공 기준

- NKS에서 Istio Ambient 구성 요소가 정상 동작한다.
- smoke workload Pod에 sidecar가 없다.
- Ambient namespace에서 Pod 간 통신이 정상이다.
- DeepFlow Agent가 모든 worker node에서 수집한다.
- DeepFlow ClickHouse/Grafana에 L4 flow가 보인다.
- HTTP 또는 PostgreSQL L7 request log가 보인다.
- 실제 `web-was-db` 배포 전 CI/CD와 Terraform 전환 범위가 명확하다.

## 5. 공식 문서 기준

- Istio Ambient: https://istio.io/latest/docs/ambient/
- Istio Ambient install with istioctl: https://istio.io/latest/docs/ambient/install/istioctl/
- Istio Ambient workload label: https://istio.io/latest/docs/ambient/usage/add-workloads/
- DeepFlow single K8s install: https://deepflow.io/docs/ce-install/single-k8s/
- DeepFlow features: https://deepflow.io/docs/about/features/
- NHN Cloud NKS user guide: https://docs.nhncloud.com/ko/Container/NKS/ko/user-guide/
