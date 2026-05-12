# NHN Cloud NKS Sidecarless Observability PoC

NHN Cloud NKS에서 **DeepFlow 기반 L4/L7 trace 가시성**과 **Istio Ambient + Kiali 기반 sidecarless mesh 가시화**를 분리 검증하기 위한 PoC 작업 공간입니다.

현재 PoC의 검증 경로는 두 가지입니다.

```text
1. NHN Cloud NKS
   -> DeepFlow
   -> DeepFlow ClickHouse/Grafana
   -> smoke web-was-db workload

2. NHN Cloud NKS
   -> Istio Ambient
   -> Prometheus
   -> Kiali
   -> smoke web-was-db workload
   -> optional DeepFlow
```

성공 기준은 애플리케이션 Pod에 Envoy sidecar를 넣지 않고도 Pod/Service/Namespace 기준 L4 이상 가시성을 확보하고, 이후 실제 `web-was-db` 배포와 CI/CD, Terraform 전환으로 이어갈 수 있는 하네스를 만드는 것입니다.

정확한 기준은 다음과 같습니다. DeepFlow 설치 자체에 Istio는 필수가 아닙니다. Kiali는 Istio용 콘솔이므로 DeepFlow 단독 경로에는 포함하지 않습니다. Istio Ambient + Kiali 뒤에 DeepFlow를 추가하는 것은 Kiali mesh 관점과 DeepFlow eBPF/protocol 관점을 비교하기 위한 선택 확장입니다.

## PoC 범위

- NHN Cloud NKS 조건 검증
- DeepFlow 단독 설치 및 eBPF/Agent 동작 검증
- DeepFlow 내 ClickHouse/Grafana 기반 시각화 검증
- Istio Ambient 설치 및 ztunnel 동작 검증
- Prometheus + Kiali 기반 Ambient mesh 시각화 검증
- namespace 단위 ambient mesh 편입 검증
- waypoint 기반 L7 처리 가능성 검증
- smoke `web-was-db` 워크로드로 HTTP/PostgreSQL 흐름 검증
- 실제 `web-was-db` 애플리케이션 배포 전 CI/CD 준비 항목 정리
- 마지막 단계에서 Terraform 코드화할 범위 분리

## 디렉터리 구성

```text
.
|-- AGENTS.md
|-- docs/
|   |-- README.md
|   |-- ai/          # AI 작업용 내부 기준
|   |-- team/        # 팀 배포용 구축/학습 문서
|   `-- reference/   # 설계/분석 참고 문서
|-- infra/
|   |-- apps/
|   |   `-- smoke/
|   |-- mesh/
|   |   `-- istio-ambient/
|   |-- observability/
|   |   `-- deepflow/
|   |-- terraform/
|   |   |-- nhn-nks/
|   |   `-- modules/
|   |       |-- deepflow/
|   |       `-- istio-ambient/
```

현재 관측 경로는 DeepFlow Helm chart가 배포하는 ClickHouse/Grafana와 `infra/apps/smoke`입니다. 이전 direct ClickHouse/Grafana manifest와 echo-server sample은 저장소에서 제거했습니다.

## 구축 기준

팀 기준 구축 절차와 복붙 가능한 Linux 명령은 `docs/team/01-build-guide.md`에서 선택합니다. 이 저장소에는 Windows PowerShell 실행 래퍼를 두지 않습니다.

진행 순서:

```text
1. DeepFlow 단독 구축: `docs/team/build-guide-deepflow-only.md`
2. Istio Ambient + Kiali 구축: `docs/team/build-guide-istio-ambient-kiali.md`
3. Istio Ambient + Kiali 뒤 DeepFlow 추가: `docs/team/build-guide-istio-ambient-kiali.md`의 선택 단계
4. 실제 web-was-db 배포 준비
5. CI/CD와 Terraform 전환
```

확인할 핵심 조건은 다음과 같습니다.

- 대상 클러스터가 NHN Cloud NKS인지
- worker node OS/kernel이 DeepFlow eBPF 수집에 적합한지
- 기본 StorageClass 또는 DeepFlow용 StorageClass가 있는지
- NKS CNI가 Calico-VXLAN 또는 Calico-eBPF인지
- Istio CNI/ztunnel 배포에 필요한 권한이 있는지

smoke workload는 다음 흐름을 만듭니다.

```text
http-client -> smoke-was HTTP service
sql-client  -> smoke-db PostgreSQL service
```

검증 포인트:

- workload Pod에 `istio-proxy` sidecar가 없는지
- namespace가 `istio.io/dataplane-mode=ambient`로 편입됐는지
- ztunnel이 Ready인지
- DeepFlow Agent가 각 노드에서 Ready인지
- DeepFlow Grafana에서 L4 flow, L7 request log, service map 또는 trace를 확인할 수 있는지

현재 단계에서는 `terraform plan`까지만 수행합니다. `terraform apply`는 명시 승인 전 실행하지 않습니다.

## 문서 구분

- 문서 구조 안내: `docs/README.md`
- AI 작업 기준: `AGENTS.md`, `docs/ai/`
- 팀 배포용 구축/학습 문서: `docs/team/`
- 설계/분석 참고 문서: `docs/reference/`
- NKS Terraform 하네스: `infra/terraform/nhn-nks/README.md`

팀에 먼저 공유할 문서는 `docs/team/01-build-guide.md`, `docs/team/build-guide-deepflow-only.md`, `docs/team/build-guide-istio-ambient-kiali.md`, `docs/team/02-tool-concepts.md`, `docs/team/03-validation-checklist.md`입니다.

## 공식 기준

- Istio Ambient 공식 문서: https://istio.io/latest/docs/ambient/
- Istio Ambient 설치: https://istio.io/latest/docs/ambient/install/istioctl/
- Istio Ambient workload 편입: https://istio.io/latest/docs/ambient/usage/add-workloads/
- Kiali Ambient Mesh: https://kiali.io/docs/features/ambient/
- DeepFlow single K8s 설치: https://deepflow.io/docs/ce-install/single-k8s/
- DeepFlow 기능 개요: https://deepflow.io/docs/about/features/
- NHN Cloud NKS 사용 가이드: https://docs.nhncloud.com/ko/Container/NKS/ko/user-guide/
