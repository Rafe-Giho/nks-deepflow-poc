# Decision Log

## 2026-05-08: Primary 관측 경로를 DeepFlow로 확정

결정:

- 현재 PoC의 primary observability는 DeepFlow입니다.
- DeepFlow가 제공하는 ClickHouse/Grafana를 1차 경로로 사용합니다.

이유:

- 사용자 목표가 `Istio Ambient + DeepFlow + ClickHouse/Grafana`로 명확해졌습니다.
- Pod L4/L7 trace 가시성 검증이 핵심입니다.

영향:

- 직접 ClickHouse/Grafana manifest는 legacy/fallback으로 격리합니다.
- `sidecarless.network_events` 테이블은 현재 primary 성공 기준이 아닙니다.

## 2026-05-08: Mesh 경로를 Istio Ambient로 확정

결정:

- 현재 mesh primary는 Istio Ambient입니다.
- ztunnel 기반 L4 검증 후 필요 시 waypoint로 L7 기능을 검증합니다.

이유:

- 사용자가 NHN Cloud NKS에서 Istio Ambient 구축을 명시했습니다.
- 애플리케이션 Pod에 sidecar를 넣지 않는 것이 핵심입니다.

영향:

- 기존 Istio sidecar는 baseline 비교 항목으로만 둡니다.

## 2026-05-08: Cilium/Hubble을 primary에서 제외

결정:

- Cilium/Hubble은 현재 PoC primary path가 아닙니다.
- 필요 시 별도 비교 실험으로 분리합니다.

이유:

- 현재 목표가 DeepFlow 기반으로 재정의됐습니다.
- NKS의 기본 CNI/add-on 조건과도 별도 검토가 필요합니다.

영향:

- 새 문서/스크립트에서 Cilium/Hubble을 기본 실행 경로로 참조하지 않습니다.

## 2026-05-08: Legacy 경로 격리

결정:

- 이전 direct ClickHouse/Grafana와 echo workload를 legacy 경로로 이동합니다.
- legacy 스크립트는 `-ConfirmLegacy` 없이는 실패하게 합니다.

이유:

- 실행자가 old path를 잘못 실행하면 DeepFlow PoC 결과와 혼동됩니다.

영향:

- primary 실행 흐름은 `scripts/20-install-istio-ambient.ps1`, `scripts/30-install-deepflow.ps1`, `scripts/40-deploy-smoke-app.ps1`, `scripts/50-verify-poc-visibility.ps1`만 사용합니다.

## 2026-05-08: Terraform은 plan-only

결정:

- 현재 단계에서 Terraform은 `fmt`, `init`, `validate`, `plan`까지만 수행합니다.
- `terraform apply`는 별도 승인 전 금지합니다.

이유:

- NHN Cloud 리소스 생성은 비용과 실제 인프라 영향을 발생시킵니다.

영향:

- 문서와 스크립트에서 apply는 기본 흐름에 포함하지 않습니다.
