# 팀 배포용 구축 문서

이 디렉터리는 엔지니어에게 공유할 구축/학습 문서만 둡니다.

AI 내부 작업 규칙이나 deprecated 경로 판단 기준은 `docs/ai/`에 둡니다.

## 배포 대상 문서

1. `01-build-guide.md`
   - 구축 가이드 선택지입니다.

2. `build-guide-deepflow-only.md`
   - Istio 없이 DeepFlow만 설치해 관측 경로를 검증하는 가이드입니다.

3. `build-guide-istio-ambient-kiali.md`
   - Istio Ambient와 Kiali를 구축하고, 필요 시 DeepFlow를 추가하는 가이드입니다.

4. `02-tool-concepts.md`
   - NHN NKS, Istio Ambient, Kiali, DeepFlow, ClickHouse, Grafana, Terraform 개념 정리입니다.

5. `03-validation-checklist.md`
   - 실제 진행 시 체크해야 할 단계별 완료 기준입니다.

## 팀 안내 기준

팀에는 이 디렉터리만 먼저 공유합니다. 상세 설계 배경이 필요한 경우 `docs/reference/`를 추가로 공유합니다.
