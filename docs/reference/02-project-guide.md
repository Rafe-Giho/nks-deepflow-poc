# 프로젝트 가이드

## 1. 프로젝트 목표

이 프로젝트의 현재 목표는 NHN Cloud NKS에서 DeepFlow로 Pod/Service/Namespace 기준 L4/L7 trace 가시성을 확보하는 것입니다.

```text
NHN Cloud NKS
  -> DeepFlow
  -> DeepFlow ClickHouse/Grafana
  -> web-was-db workload
```

## 2. 진행 순서

### 1순위. NKS 사전 검증

확인 항목:

- kubeconfig context
- worker node Ready
- node OS/kernel
- Calico/Felix 상태
- NKS `csi-cinder` add-on
- `sgh-cinder-sc` StorageClass
- DeepFlow 설치 권한

### 2순위. DeepFlow 구축

확인 항목:

- Helm chart 설치
- Agent DaemonSet Ready
- Server/App/MySQL/ClickHouse/Grafana Ready
- PVC Bound
- Grafana 접속

### 3순위. web-was-db 검증

확인 항목:

- Gateway/API 노출
- web/was/db Pod Ready
- 게시글 생성/조회 등 실제 기능 정상
- web -> was -> db traffic 발생
- DeepFlow ClickHouse/Grafana에서 traffic 확인

### 4순위. 자동화 전환

확인 항목:

- CI/CD pipeline 설계
- 배포 후 검증 traffic 생성
- DeepFlow visibility check
- NKS/DeepFlow Terraform plan

## 3. 현재 파일 기준

- 팀 구축 가이드: `docs/team/build-guide-deepflow-only.md`
- 도구 개념: `docs/team/02-tool-concepts.md`
- 검증 체크리스트: `docs/team/03-validation-checklist.md`
- DeepFlow manifest/values: `infra/observability/deepflow`
- NKS Terraform: `infra/terraform/nhn-nks`
- 실제 앱: `k8s-3tier-app`

## 4. 완료 정의

- DeepFlow가 NKS에서 안정적으로 동작합니다.
- 실제 web-was-db traffic이 DeepFlow에 수집됩니다.
- Grafana dashboard에서 업무 흐름을 설명할 수 있습니다.
- 구축 절차가 문서대로 재현 가능합니다.
- Terraform과 CI/CD 전환 범위가 명확합니다.

## 5. 참고

- DeepFlow single K8s install: https://deepflow.io/docs/ce-install/single-k8s/
- DeepFlow deployment overview: https://deepflow.io/docs/ce-install/overview/
- NHN Cloud NKS user guide: https://docs.nhncloud.com/ko/Container/NKS/ko/user-guide/
