# PoC #1 NHN Cloud NKS 검증 체크리스트

## 0. 사전 조건

- [ ] 대상 환경이 NHN Cloud NKS인지 확인
- [ ] NHN Cloud API 계정, Tenant ID, API Password 준비
- [ ] Terraform provider `nhn-cloud/nhncloud` 사용 가능
- [ ] VPC network UUID 확인
- [ ] VPC subnet UUID 확인
- [ ] worker flavor UUID 확인
- [ ] NKS worker node image UUID 확인
- [ ] key pair 준비
- [ ] Kubernetes 버전 확정
- [ ] StorageClass 확정
- [ ] `kubectl`, `helm`, `istioctl`, `terraform` 준비

## 1. NKS / CNI / Kernel

- [ ] `kubectl config current-context` 확인
- [ ] worker node OS 확인
- [ ] worker node kernel version 확인
- [ ] Calico-VXLAN 또는 Calico-eBPF 확인
- [ ] Calico/Felix Pod 상태 확인
- [ ] CoreDNS 정상 동작 확인
- [ ] Istio Ambient 설치에 필요한 CRD/cluster-admin 권한 확인
- [ ] DeepFlow Agent에 필요한 privileged/host/eBPF 수집 조건 확인
- [ ] default StorageClass 또는 DeepFlow용 StorageClass 확인

## 2. Istio Ambient

- [ ] Gateway API CRD 설치 확인
- [ ] `istioctl install --set profile=ambient` 성공
- [ ] `istiod` Ready
- [ ] `istio-cni-node` Ready
- [ ] `ztunnel` Ready
- [ ] ambient 대상 namespace에 `istio.io/dataplane-mode=ambient` 라벨 적용
- [ ] ambient namespace에 `istio-injection=enabled` 라벨이 없는지 확인
- [ ] workload Pod에 `istio-proxy` sidecar가 없는지 확인
- [ ] Pod 간 통신 성공
- [ ] waypoint 필요 여부 판단
- [ ] waypoint 적용 시 L7 route/policy 동작 확인

## 3. DeepFlow

- [ ] Helm repo `deepflow` 추가 가능
- [ ] DeepFlow chart 설치 성공
- [ ] `deepflow-agent` DaemonSet Ready
- [ ] `deepflow-server` Ready
- [ ] DeepFlow ClickHouse Ready
- [ ] DeepFlow Grafana Ready
- [ ] Kubernetes resource AutoTagging 확인
- [ ] L4 flow log 조회 가능
- [ ] L7 request log 조회 가능
- [ ] AutoTracing 화면 또는 API에서 trace 조회 가능
- [ ] Grafana 접속 경로 확인

## 4. Smoke web-was-db

- [ ] `sidecarless-smoke` namespace 생성
- [ ] namespace ambient label 적용
- [ ] `smoke-was` HTTP service Ready
- [ ] `smoke-db` PostgreSQL service Ready
- [ ] HTTP traffic generator 실행
- [ ] SQL traffic generator 실행
- [ ] 모든 smoke Pod에 sidecar 없음
- [ ] DeepFlow에서 `http-client -> smoke-was` HTTP 흐름 확인
- [ ] DeepFlow에서 `sql-client -> smoke-db` PostgreSQL 흐름 확인
- [ ] Grafana에서 source/destination service 관계 확인

## 5. 실제 web-was-db 준비

- [ ] web/was/db 이미지 빌드 방식 확정
- [ ] NHN Container Registry 또는 대상 registry 확정
- [ ] Kubernetes manifest, Helm, Kustomize 중 배포 방식 확정
- [ ] Secret/ConfigMap 관리 방식 확정
- [ ] DB persistence 방식 확정
- [ ] Ingress/Gateway/API Gateway 노출 방식 확정
- [ ] rollout/rollback 기준 확정

## 6. CI/CD

- [ ] repository branch 전략 확정
- [ ] image build job 작성
- [ ] image scan 필요 여부 결정
- [ ] registry push job 작성
- [ ] deploy job 작성
- [ ] `kubectl diff` 또는 dry-run 검증 추가
- [ ] rollout status 검증 추가
- [ ] DeepFlow smoke query 또는 dashboard 확인 절차 추가

## 7. Terraform 전환

- [ ] NKS cluster Terraform plan 성공
- [ ] NKS node group Terraform plan 성공
- [ ] Calico add-on option plan 확인
- [ ] Helm provider로 Istio Ambient 관리 가능성 확인
- [ ] Helm provider로 DeepFlow 관리 가능성 확인
- [ ] Kubernetes provider로 smoke/app 리소스 관리 가능성 확인
- [ ] 민감정보 tfvars/env 처리 방식 확정
- [ ] `terraform apply` 승인 절차 확정

## 8. 비교/보고

- [ ] 기존 sidecar 방식 대비 Pod container 수 비교
- [ ] CPU/memory overhead 비교
- [ ] request latency 비교
- [ ] L4/L7 가시성 범위 비교
- [ ] Ambient L4-only와 waypoint L7 적용 차이 정리
- [ ] DeepFlow가 mTLS/HBONE 환경에서 L7를 어디까지 볼 수 있는지 정리
- [ ] NKS 적용 제약사항 정리
