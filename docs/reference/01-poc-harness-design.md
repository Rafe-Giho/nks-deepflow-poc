# PoC 하네스 설계

## 1. 목적

NHN Cloud NKS에서 DeepFlow를 이용해 web-was-db 애플리케이션의 L4/L7 traffic 가시성을 검증합니다.

하네스의 목적은 단순 설치가 아니라 다음을 반복 가능하게 만드는 것입니다.

```text
NKS 사전 점검
  -> DeepFlow 설치
  -> StorageClass/PVC 확인
  -> k8s-3tier-app 배포
  -> traffic 발생
  -> ClickHouse/Grafana 검증
  -> CI/CD/Terraform 전환 판단
```

## 2. 우선순위

1. NKS와 node/kernel/storage 조건 확인
2. DeepFlow Agent/Server/ClickHouse/Grafana 정상화
3. web-was-db traffic 수집 확인
4. Grafana dashboard와 ClickHouse query 기반 검증
5. Terraform과 CI/CD로 재현성 확보

## 3. 구성 요소

### NKS

- 관리형 Kubernetes 실행 환경
- Calico/Felix 기반 네트워크 확인
- `csi-cinder` add-on과 `sgh-cinder-sc` StorageClass 사용

### DeepFlow

- `deepflow-agent`: node별 eBPF 수집기
- `deepflow-server`: agent 관리와 데이터 처리
- `deepflow-clickhouse`: flow/log/metric 저장소
- `deepflow-grafana`: 시각화

### Application

- `k8s-3tier-app`: 실제 web-was-db 검증 앱

## 4. 성공 기준

- DeepFlow Agent DaemonSet ready 수가 worker node 수와 일치합니다.
- DeepFlow PVC가 `sgh-cinder-sc`로 Bound입니다.
- web-was-db 요청이 정상 응답합니다.
- DeepFlow ClickHouse에서 대상 Pod/Service tag와 L4/L7 데이터가 조회됩니다.
- Grafana에서 namespace/service/pod 기준 흐름이 보입니다.

## 5. 리스크와 대응

| 리스크 | 증상 | 대응 |
| --- | --- | --- |
| node 리소스 부족 | Pod Pending/Evicted | node flavor/수량 조정 |
| eBPF 제한 | agent CrashLoopBackOff | kernel, 권한, agent 설정 확인 |
| PVC Pending | ClickHouse/MySQL Ready 실패 | `csi-cinder`, quota, StorageClass 확인 |
| tag 지연 | Grafana에 이름 없는 노드 표시 | DeepFlow server metadata sync 확인 |
| L7 복원 제한 | L4는 보이나 HTTP/SQL이 부족 | traffic, protocol, 암호화 여부 확인 |

## 6. 산출물

- `docs/team/build-guide-deepflow-only.md`
- `docs/team/03-validation-checklist.md`
- `infra/observability/deepflow`
- `k8s-3tier-app`
- `infra/terraform/nhn-nks`
- `infra/terraform/modules/deepflow`
