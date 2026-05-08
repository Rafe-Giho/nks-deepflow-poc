# PoC 구축 가이드 선택지

이 문서는 팀이 어떤 구축 가이드를 따라야 하는지 고르는 진입점입니다. 실제 복붙 명령은 아래 분리 문서에 둡니다.

## 1. DeepFlow 단독 구축

문서: `docs/team/build-guide-deepflow-only.md`

목적:

- Istio 없이 NKS Pod/Service traffic을 DeepFlow로 관측합니다.
- eBPF Agent, ClickHouse, Grafana, AutoTagging, L4/L7 관측 가능성을 먼저 검증합니다.
- Mesh 기능이 아니라 observability 도구 자체를 검증합니다.

선택 기준:

- "DeepFlow가 NKS에서 동작하는가?"를 먼저 확인해야 할 때
- Istio Ambient 도입 전, 수집 권한/kernel/StorageClass 리스크를 분리하고 싶을 때
- Kiali나 Istio telemetry 없이 DeepFlow의 기본 가시성을 검증하고 싶을 때

## 2. Istio Ambient + Kiali 구축

문서: `docs/team/build-guide-istio-ambient-kiali.md`

목적:

- Istio Ambient로 sidecarless mesh를 구성합니다.
- Kiali로 ambient namespace, ztunnel, waypoint, mesh topology, Istio metric 기반 health를 확인합니다.
- 필요할 때 Kiali 검증 뒤 DeepFlow를 추가해 eBPF 기반 flow/protocol 관측을 비교합니다.

선택 기준:

- "Istio Ambient가 NKS에서 sidecarless mesh로 동작하는가?"를 검증할 때
- mesh 구성/정책/waypoint 상태를 Kiali에서 확인해야 할 때
- Ambient + Kiali 기준선 위에 DeepFlow를 추가했을 때 의미가 있는지 비교해야 할 때

## 3. 결론

- DeepFlow 설치에 Istio는 필수가 아닙니다.
- Kiali는 Istio용 콘솔이므로 DeepFlow 단독 구축 경로에는 필요하지 않습니다.
- Istio Ambient + Kiali 뒤에 DeepFlow를 추가하는 것은 의미가 있습니다. 단, Kiali 안에 DeepFlow를 붙이는 통합이 아니라 두 관측 경로를 병렬로 비교하는 방식입니다.
- Kiali는 Istio telemetry/Prometheus 기반 mesh 관점, DeepFlow는 eBPF/packet/Kubernetes metadata 기반 infra 및 protocol 관점입니다.

## 4. 공통 문서

- 도구 개념: `docs/team/02-tool-concepts.md`
- 검증 체크리스트: `docs/team/03-validation-checklist.md`
- AI 작업 기준: `docs/ai/00-project-source-of-truth.md`

## 5. 공식 문서

- Istio Ambient Helm install: https://istio.io/latest/docs/ambient/install/helm/
- Istio waypoint: https://istio.io/latest/docs/ambient/usage/waypoint/
- Kiali Helm install: https://kiali.io/docs/installation/installation-guide/install-with-helm/
- Kiali Ambient Mesh: https://kiali.io/docs/features/ambient/
- Kiali Prometheus config: https://kiali.io/docs/configuration/p8s-jaeger-grafana/prometheus/
- DeepFlow single K8s install: https://deepflow.io/docs/ce-install/single-k8s/
