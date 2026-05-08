# PoC 하네스 설계안

## 1. 목표

NHN Cloud NKS에서 DeepFlow 단독 관측 경로와 Istio Ambient + Kiali mesh 가시화 경로를 분리 검증합니다. 필요할 때 Istio Ambient + Kiali 뒤에 DeepFlow를 추가해 두 관측 결과를 비교합니다.

최종 목표는 다음 순서입니다.

```text
1. NKS 조건 검증
2A. DeepFlow + ClickHouse + Grafana 단독 구축
2B. Istio Ambient + Prometheus + Kiali 구축
3. smoke web-was-db 검증
4. 필요 시 Kiali 뒤 DeepFlow 추가
5. 실제 web-was-db 배포
6. CI/CD 구성
7. Terraform 코드화
```

## 2. 기준 아키텍처

```text
External / CI runner
  -> kubectl / helm / istioctl / terraform

NHN Cloud NKS
  -> kube-system
       -> Calico-VXLAN or Calico-eBPF
       -> CoreDNS
  -> deepflow
       -> deepflow-agent DaemonSet
       -> deepflow-server
       -> ClickHouse
       -> Grafana

NHN Cloud NKS
  -> istio-system
       -> istiod
       -> istio-cni
       -> ztunnel
       -> waypoint optional
       -> Prometheus
       -> Kiali
  -> sidecarless-smoke
       -> smoke-was
       -> smoke-db
       -> traffic generators
```

## 3. 하네스 구성 원칙

- 클러스터 생성과 클러스터 내부 배포를 분리합니다.
- 초기 단계는 `docs/team/01-build-guide.md`에서 경로를 선택하고, 분리 구축 가이드의 Linux 명령과 Kubernetes manifest/Helm values로 검증합니다.
- Terraform 전환은 마지막 단계로 둡니다.
- Windows PowerShell 실행 래퍼는 유지하지 않습니다.
- DeepFlow 단독 경로에서는 DeepFlow가 제공하는 ClickHouse/Grafana를 사용합니다.
- Istio Ambient 경로에서는 Kiali를 먼저 붙이고, DeepFlow는 선택 확장으로 붙입니다.
- 기존 직접 ClickHouse/Grafana 구성은 비교 또는 fallback으로만 둡니다.

## 4. Phase 0. NKS Preflight

목적:

- NKS가 Ambient/DeepFlow를 수용할 수 있는지 확인합니다.

검증 항목:

- Kubernetes API 접근
- worker node OS/kernel
- StorageClass
- CNI 종류
- Calico/Felix 상태
- privileged DaemonSet 허용
- CRD 설치 권한
- `helm`, `istioctl`, `terraform` 로컬 도구 상태

산출물:

- `docs/team/01-build-guide.md`
- `docs/team/build-guide-deepflow-only.md`
- `docs/team/build-guide-istio-ambient-kiali.md`
- `docs/team/03-validation-checklist.md`
- `infra/terraform/nhn-nks`

## 5. Phase 1. Istio Ambient

목적:

- sidecar 없는 mesh 계층을 구성합니다.

구성:

- Gateway API CRD
- Istio ambient profile
- istiod
- istio-cni
- ztunnel
- optional waypoint

검증 항목:

- `istioctl version`
- `istioctl analyze`
- `kubectl get pods -n istio-system`
- ambient namespace label
- workload Pod에 `istio-proxy` 부재
- Pod 간 통신 성공

성공 기준:

- ztunnel이 모든 대상 노드에서 Ready입니다.
- ambient namespace의 workload가 sidecar 없이 통신합니다.
- L7 기능이 필요한 경우 waypoint를 추가해 HTTP 기준 검증이 가능합니다.

## 6. Phase 2. DeepFlow

목적:

- Pod/Service/Namespace 기준 L4/L7 관측 데이터를 수집하고 Grafana에서 확인합니다.

구성:

- deepflow-agent
- deepflow-server
- ClickHouse
- Grafana

검증 항목:

- Helm release 상태
- Agent DaemonSet Ready
- DeepFlow Server Ready
- ClickHouse/Grafana Ready
- Grafana 접근 경로
- L4 flow log
- L7 request log
- AutoTracing

성공 기준:

- smoke traffic이 DeepFlow UI/Grafana에서 source/destination 기준으로 조회됩니다.
- HTTP와 PostgreSQL 중 최소 하나 이상의 L7 request log가 확인됩니다.

## 7. Phase 3. Smoke web-was-db

목적:

- 실제 애플리케이션 투입 전 최소 호출 구조로 관측 경로를 검증합니다.

구성:

```text
http-client CronJob
  -> smoke-was Service

sql-client CronJob
  -> smoke-db Service
```

검증 항목:

- Deployment Ready
- Service DNS 통신
- HTTP request 성공
- PostgreSQL query 성공
- sidecar 없음
- DeepFlow L4/L7 데이터 확인

## 8. Phase 4. 실제 web-was-db + CI/CD

목적:

- 사용자가 보유한 실제 시스템을 같은 하네스에 얹습니다.

준비 항목:

- 이미지 빌드 방식
- registry
- manifest/Helm/Kustomize 구조
- Secret/ConfigMap
- DB persistence
- 배포 환경 namespace
- rollout/rollback
- pipeline 권한

권장 CI/CD 순서:

```text
build
  -> test
  -> image push
  -> manifest render
  -> kubectl diff
  -> deploy
  -> rollout status
  -> smoke traffic
  -> DeepFlow visibility check
```

## 9. Phase 5. Terraform 전환

목적:

- PoC 성공 구성을 재현 가능한 코드로 고정합니다.

전환 순서:

1. NKS cluster/node group
2. NKS add-on/CNI option
3. Istio Ambient Helm 또는 manifest
4. DeepFlow Helm
5. smoke app
6. 실제 web-was-db
7. CI/CD 변수와 output 연계

주의:

- `terraform apply`는 별도 승인 전 실행하지 않습니다.
- 민감정보는 `terraform.tfvars`, 환경변수, CI secret으로 분리합니다.
- Helm provider로 cluster 내부 배포를 관리할지, Terraform은 infra만 담당하고 배포는 CI/CD가 담당할지 최종 결정해야 합니다.

## 10. 주요 리스크

| 리스크 | 영향 | 대응 |
| --- | --- | --- |
| DeepFlow Agent 권한 제한 | eBPF 수집 실패 | privileged/host 권한 사전 확인 |
| StorageClass 부재 | ClickHouse/PVC 실패 | NKS StorageClass 또는 별도 CSI 확인 |
| Ambient L7 미구성 | L4만 보임 | waypoint 추가 |
| Ambient mTLS/HBONE | DeepFlow L7 복원 제한 가능 | plaintext smoke와 ambient smoke를 비교 |
| 기존 ClickHouse/Grafana 중복 | 데이터 경로 혼란 | DeepFlow 제공 stack 우선 |
| Terraform 범위 과대 | 운영 복잡도 증가 | PoC 성공 후 단계적 코드화 |

## 11. 판정 기준

PoC 성공:

- NKS에서 Istio Ambient가 정상 동작합니다.
- smoke workload가 sidecar 없이 동작합니다.
- DeepFlow가 L4 flow를 수집합니다.
- DeepFlow가 HTTP 또는 PostgreSQL L7 request log를 수집합니다.
- Grafana에서 Pod/Service/Namespace 기준 확인이 가능합니다.

PoC 보류:

- DeepFlow Agent가 NKS worker에서 동작하지 않습니다.
- Ambient와 DeepFlow 조합에서 L7가 전혀 복원되지 않습니다.
- StorageClass/PVC 제약으로 ClickHouse 운영이 불가능합니다.

PoC 실패:

- NKS에서 Istio Ambient 기본 구성 자체가 불가능합니다.
- sidecarless 상태에서 대상 Pod 통신이 안정적으로 유지되지 않습니다.
- 운영 표준으로 삼을 수 없는 권한/보안 예외가 필수입니다.
