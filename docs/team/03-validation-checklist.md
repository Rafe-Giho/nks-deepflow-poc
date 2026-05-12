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
- [ ] NKS `csi-cinder` add-on 추가 확인
- [ ] `sgh-cinder-sc` StorageClass 확정
- [ ] `kubectl`, `helm`, `terraform` 준비

## 1. NKS / CNI / Kernel

- [ ] `kubectl config current-context` 확인
- [ ] worker node OS 확인
- [ ] worker node kernel version 확인
- [ ] Calico mode 확인
- [ ] Calico/Felix Pod 상태 확인
- [ ] CoreDNS 정상 동작 확인
- [ ] `cinder.csi.openstack.org` CSIDriver 확인
- [ ] `sgh-cinder-sc` StorageClass provisioner/binding 확인
- [ ] DeepFlow Agent에 필요한 privileged/host/eBPF 수집 조건 확인
- [ ] DeepFlow용 StorageClass가 `sgh-cinder-sc`인지 확인

## 2. DeepFlow

- [ ] Helm repo `deepflow` 추가 가능
- [ ] DeepFlow chart 설치 성공
- [ ] `deepflow-agent` DaemonSet Ready
- [ ] `deepflow-server` Ready
- [ ] DeepFlow ClickHouse Ready
- [ ] DeepFlow Grafana Ready
- [ ] DeepFlow PVC가 `sgh-cinder-sc`로 Bound
- [ ] Kubernetes resource AutoTagging 확인
- [ ] L4 flow log 조회 가능
- [ ] 가능한 경우 L7 request log 조회 가능
- [ ] Grafana 접속 경로 확인

## 3. web-was-db 앱

- [ ] `sgh-web-ns`, `sgh-was-ns`, `sgh-db-ns` namespace 생성
- [ ] web Pod Ready
- [ ] was Pod Ready
- [ ] db Pod Ready
- [ ] Gateway/HTTPRoute Accepted
- [ ] 외부 HTTP 요청 정상 응답
- [ ] DeepFlow에서 HTTP/SQL 흐름 확인
- [ ] Grafana에서 source/destination service 관계 확인

## 4. 실제 web-was-db 준비

- [ ] web/was/db 이미지 빌드 방식 확정
- [ ] NHN Container Registry 또는 대상 registry 확정
- [ ] Kubernetes manifest, Helm, Kustomize 중 배포 방식 확정
- [ ] Secret/ConfigMap 관리 방식 확정
- [ ] DB persistence 방식 확정
- [ ] Gateway/API Gateway 노출 방식 확정
- [ ] rollout/rollback 기준 확정
- [ ] DeepFlow에서 web -> was -> db 흐름 확인

## 5. CI/CD

- [ ] repository branch 전략 확정
- [ ] image build job 작성
- [ ] image scan 필요 여부 결정
- [ ] registry push job 작성
- [ ] deploy job 작성
- [ ] `kubectl diff` 또는 dry-run 검증 추가
- [ ] rollout status 검증 추가
- [ ] 배포 후 DeepFlow 확인 절차 추가

## 6. Terraform 전환

- [ ] NKS cluster Terraform plan 성공
- [ ] NKS node group Terraform plan 성공
- [ ] Calico add-on option plan 확인
- [ ] Helm provider로 DeepFlow 관리 가능성 확인
- [ ] Kubernetes provider로 app 리소스 관리 가능성 확인
- [ ] 민감정보 tfvars/env 처리 방식 확정
- [ ] `terraform apply` 승인 절차 확정

## 7. 비교/보고

- [ ] Pod container 수 비교
- [ ] CPU/memory overhead 비교
- [ ] request latency 비교
- [ ] L4/L7 가시성 범위 비교
- [ ] DeepFlow dashboard/ClickHouse query 결과 정리
- [ ] NKS 적용 제약사항 정리
