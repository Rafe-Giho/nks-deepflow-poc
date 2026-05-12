# Decision Log

## 2026-05-08: Primary 관측 경로를 DeepFlow로 확정

결정:

- 현재 PoC의 primary observability는 DeepFlow입니다.
- DeepFlow가 제공하는 ClickHouse/Grafana를 1차 경로로 사용합니다.

이유:

- Pod L4/L7 trace 가시성 검증이 핵심입니다.
- 별도 이벤트 수집기를 만들지 않고 DeepFlow chart가 제공하는 저장소/대시보드를 사용합니다.

영향:

- 직접 ClickHouse/Grafana manifest는 현재 구축 경로에서 제외합니다.
- `sidecarless.network_events` 테이블은 현재 primary 성공 기준이 아닙니다.

## 2026-05-08: Cilium/Hubble을 primary에서 제외

결정:

- Cilium/Hubble은 현재 PoC 구축 경로가 아닙니다.
- 필요 시 별도 비교 실험으로 분리합니다.

이유:

- 현재 목표가 DeepFlow 기반으로 재정의됐습니다.
- NKS의 기본 CNI/add-on 조건과도 별도 검토가 필요합니다.

영향:

- 새 문서에서 Cilium/Hubble을 기본 실행 경로로 참조하지 않습니다.

## 2026-05-08: 과거 manifest 경로 격리

결정:

- 이전 direct ClickHouse/Grafana와 echo workload를 기본 구축 경로에서 제외합니다.

이유:

- 실행자가 old path를 잘못 실행하면 DeepFlow PoC 결과와 혼동됩니다.

영향:

- 구축 흐름은 `docs/team/01-build-guide.md`와 `infra/` 하위 manifest/values를 기준으로 합니다.

## 2026-05-08: PowerShell 실행 래퍼 제거

결정:

- PowerShell 실행 래퍼 파일을 저장소에서 제거합니다.
- 팀 구축 절차는 Linux 기준 `docs/team/01-build-guide.md`와 하위 가이드에 둡니다.

이유:

- Windows PowerShell 래퍼가 팀 구축 가이드와 중복됩니다.
- 과거 실행 경로와 현재 구축 경로 사이에 혼동을 만들 수 있습니다.

영향:

- 실행 절차 변경은 `docs/team/01-build-guide.md`와 하위 가이드에 반영합니다.
- AI 작업 기준은 실행 스크립트가 아니라 source-of-truth와 validation gate 문서로 관리합니다.

## 2026-05-11: Legacy manifest 삭제

결정:

- 이전 direct ClickHouse/Grafana manifest를 삭제합니다.
- 이전 echo-server sample workload를 삭제합니다.

이유:

- DeepFlow chart가 ClickHouse/Grafana를 구성하므로 별도 manifest가 필요하지 않습니다.
- web-was-db가 현재 workload 검증 기준입니다.
- 보존용 legacy 디렉터리가 남아 있으면 실행자가 잘못 사용할 수 있습니다.

영향:

- 삭제된 과거 경로는 `docs/ai/04-deprecated-paths.md`에서 재생성 금지 항목으로만 관리합니다.
- 현재 구축 경로는 `infra/observability/deepflow`, `k8s-3tier-app`입니다.

## 2026-05-12: DeepFlow 단독 경로로 단순화

결정:

- 프로젝트의 현재 실행 경로를 DeepFlow 단독 검증으로 단순화합니다.
- mesh 전용 문서, manifest, Terraform placeholder는 제거합니다.
- 임시 검증 namespace에서도 mesh 편입 라벨을 제거합니다.

이유:

- 사용자가 해당 모드 검증을 진행하지 않겠다고 명시했습니다.
- 현재 목표는 DeepFlow로 web-was-db의 L4/L7 가시성을 확보하는 것입니다.

영향:

- 팀 가이드는 DeepFlow 구축 가이드 하나만 유지합니다.
- validation gate와 AI 작업 기준도 DeepFlow 중심으로 정리합니다.

## 2026-05-12: 임시 검증 앱 제거

결정:

- 임시 검증 앱 경로를 삭제합니다.
- 검증 앱은 `k8s-3tier-app`으로 통일합니다.

이유:

- 실제 검증에 이미 web-was-db 앱을 사용하고 있습니다.
- 별도 임시 검증 앱이 남아 있으면 실행자가 어느 앱을 기준으로 검증해야 하는지 혼동할 수 있습니다.

영향:

- 문서의 검증 기준과 validation gate는 `sgh-web-ns`, `sgh-was-ns`, `sgh-db-ns` 기준으로 정리합니다.

## 2026-05-08: Terraform은 plan-only

결정:

- 현재 단계에서 Terraform은 `fmt`, `init`, `validate`, `plan`까지만 수행합니다.
- `terraform apply`는 별도 승인 전 금지합니다.

이유:

- NHN Cloud 리소스 생성은 비용과 실제 인프라 영향을 발생시킵니다.

영향:

- 문서의 기본 흐름에 apply는 포함하지 않습니다.
