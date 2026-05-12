# PoC 구축 가이드

이 문서는 팀이 따라야 할 구축 가이드의 진입점입니다. 실제 복붙 명령은 `docs/team/build-guide-deepflow-only.md`에 둡니다.

## 1. DeepFlow 구축

문서: `docs/team/build-guide-deepflow-only.md`

목적:

- NHN Cloud NKS Pod/Service traffic을 DeepFlow로 관측합니다.
- eBPF Agent, ClickHouse, Grafana, AutoTagging, L4/L7 관측 가능성을 검증합니다.
- `k8s-3tier-app` web-was-db 흐름을 기준으로 실제 서비스 가시성을 확인합니다.

선택 기준:

- "DeepFlow가 NKS에서 동작하는가?"를 확인해야 할 때
- 수집 권한, kernel, StorageClass 리스크를 검증해야 할 때
- Pod/Service/Namespace 기준 traffic map과 request log를 확인해야 할 때
- 이후 CI/CD와 Terraform 전환의 기준 구축 절차가 필요할 때

## 2. 공통 문서

- 도구 개념: `docs/team/02-tool-concepts.md`
- 검증 체크리스트: `docs/team/03-validation-checklist.md`
- AI 작업 기준: `docs/ai/00-project-source-of-truth.md`

## 3. 공식 문서

- DeepFlow single K8s install: https://deepflow.io/docs/ce-install/single-k8s/
- DeepFlow deployment overview: https://deepflow.io/docs/ce-install/overview/
- DeepFlow agent advanced config: https://deepflow.io/docs/best-practice/agent-advanced-config/
- NHN Cloud NKS user guide: https://docs.nhncloud.com/ko/Container/NKS/ko/user-guide/
