# PoC #1 NHN Cloud NKS 검증 체크리스트

## 사전 조건

- [ ] 대상 환경이 NHN Cloud NKS인지 확인
- [ ] NHN Cloud API 계정, Tenant ID, API Password 준비
- [ ] Terraform provider `nhn-cloud/nhncloud` 사용 가능
- [ ] VPC network UUID 확인
- [ ] VPC subnet UUID 확인
- [ ] worker flavor UUID 확인
- [ ] NKS worker node image UUID 확인
- [ ] key pair 준비
- [ ] Kubernetes 버전 확정
- [ ] Calico add-on 버전 확정

## NKS / CNI

- [ ] Terraform plan 성공
- [ ] NKS 클러스터 생성 성공
- [ ] Calico add-on 설치 확인
- [ ] Calico mode가 `ebpf`인지 확인
- [ ] Calico-eBPF 지원 OS 이미지인지 확인
- [ ] `kube-proxy` DaemonSet 부재 또는 비활성 조건 확인
- [ ] CoreDNS 정상 동작 확인

## Sidecarless 워크로드

- [ ] 샘플 workload 배포 성공
- [ ] 애플리케이션 Pod에 sidecar 없음
- [ ] Service DNS 통신 성공
- [ ] Pod 간 통신 성공
- [ ] NodePort/LoadBalancer 필요 시 보안 그룹 조건 확인

## 저장/시각화

- [ ] ClickHouse StatefulSet Ready
- [ ] `sidecarless.network_events` 테이블 생성
- [ ] Grafana Deployment Ready
- [ ] Grafana ClickHouse datasource 연결 성공
- [ ] 네트워크 이벤트 대시보드 조회 가능

## 네트워크 이벤트 수집원 결정

- [ ] NHN Cloud Network Flow Log 사용 가능성 확인
- [ ] Calico metrics 기반 수집 가능성 확인
- [ ] 별도 eBPF collector DaemonSet 허용 여부 확인
- [ ] pod-level / node-level / VPC-level 중 필요한 관측 범위 확정
- [ ] ClickHouse 적재 스키마 최종 보정

## 비교/보고

- [ ] 기존 Istio/Envoy sidecar baseline 확보
- [ ] CPU/memory/request latency 비교
- [ ] Pod spec 복잡도 비교
- [ ] 운영 장애 지점 비교
- [ ] NKS 적용 제약사항 정리

