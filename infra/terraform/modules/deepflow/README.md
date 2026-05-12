# Terraform Module Placeholder: DeepFlow

PoC 성공 후 Helm provider 기반으로 DeepFlow를 Terraform 관리 대상으로 전환하기 위한 자리입니다.

초기 검증 단계에서는 `docs/team/build-guide-deepflow-only.md`의 DeepFlow 설치 명령과 `infra/observability/deepflow/values/poc-values.yaml`을 사용합니다.

전환 후보:

- DeepFlow Helm release
- DeepFlow values
- StorageClass 변수
- Grafana 접근 방식
- retention/replica 설정
