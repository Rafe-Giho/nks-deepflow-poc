# AI 작업 하네스

## 1. 목적

이 문서는 AI가 이 PoC를 진행할 때 정확도와 효율을 높이기 위한 작업 프레임워크입니다.

여기서 하네스는 실행 스크립트가 아니라 다음을 고정하는 운영 체계입니다.

```text
요구 해석
  -> 기준 문서 확인
  -> 작업 범위 결정
  -> 파일 수정
  -> 검증
  -> 보고
```

## 2. AI가 항상 지켜야 할 기준

현재 구축 가이드 경로:

```text
1. NHN Cloud NKS -> DeepFlow -> DeepFlow ClickHouse/Grafana -> sidecarless-smoke
2. NHN Cloud NKS -> Istio Ambient -> Prometheus -> Kiali -> sidecarless-smoke -> optional DeepFlow
```

primary가 아닌 것:

- Cilium/Hubble
- 직접 ClickHouse/Grafana manifest
- echo-server sample workload
- `sidecarless-demo`
- `sidecarless-observability`
- `sidecarless.network_events`

이 항목들은 `legacy` 또는 과거 검토 항목으로만 취급합니다.

## 3. 작업 시작 절차

AI는 작업 전 다음 순서로 확인합니다.

1. 사용자 요청이 분석인지 변경인지 구분
2. `docs/ai/00-project-source-of-truth.md` 확인
3. `docs/ai/04-deprecated-paths.md` 확인
4. 관련 코드/문서 검색
5. 변경이 필요한 primary 경로 결정
6. 검증 명령 결정

검색 기본 명령:

```powershell
rg --files
rg -n "Istio|Ambient|DeepFlow|legacy|deprecated|sidecarless-smoke|terraform apply" README.md docs infra
```

## 4. 작업 유형별 원칙

### 분석/리뷰

- 파일 수정 금지
- 읽기 전용 명령만 실행
- stale path, legacy path, source-of-truth 불일치를 우선 확인
- 결과는 문제점, 근거 파일, 조치 제안 순서로 보고

### 문서 수정

- `docs/ai/00-project-source-of-truth.md`와 충돌하지 않게 수정
- 구축 경로 선택 기준은 `docs/team/01-build-guide.md`에 반영
- DeepFlow 단독 명령은 `docs/team/build-guide-deepflow-only.md`에 반영
- Istio Ambient + Kiali 명령은 `docs/team/build-guide-istio-ambient-kiali.md`에 반영
- 이론 설명은 `docs/team/02-tool-concepts.md`에 반영
- AI 작업 기준은 `docs/ai/01-ai-work-harness.md` 또는 `AGENTS.md`에 반영

### Kubernetes 하네스 수정

- primary 경로만 수정
- smoke app은 `infra/apps/smoke`
- Istio Ambient는 `infra/mesh/istio-ambient`
- DeepFlow는 `infra/observability/deepflow`
- Kiali는 팀 가이드 문서 기준으로 설치하고, 별도 manifest를 만들 때만 `infra/`에 추가
- Windows PowerShell 실행 래퍼를 새로 만들지 않음
- legacy 경로를 기본 구축 흐름에 다시 넣지 않음

### Terraform 수정

- `terraform apply` 금지
- provider/resource 문법은 최신 공식 문서 또는 local validate로 확인
- `terraform fmt -check -recursive`
- `terraform validate`
- plan은 실제 변수/자격 증명 조건이 충족될 때만 실행

## 5. 변경 전 체크리스트

- [ ] 사용자의 최신 요청과 맞는가?
- [ ] source-of-truth의 구축 경로 기준인가?
- [ ] legacy 파일을 건드리는 이유가 명확한가?
- [ ] 실제 클러스터 변경 명령이 포함되는가?
- [ ] `apply`, `install`, `upgrade`가 필요한 경우 사용자가 요청했는가?
- [ ] 검증 방법이 있는가?

## 6. 변경 후 체크리스트

- [ ] README 링크가 맞는가?
- [ ] source-of-truth와 충돌하지 않는가?
- [ ] deprecated path에 새 의존성이 생기지 않았는가?
- [ ] Kustomize 렌더링이 통과하는가?
- [ ] Terraform fmt/validate가 통과하는가?
- [ ] 실행하지 못한 검증을 명확히 보고했는가?

## 7. 보고 형식

최종 보고에는 다음을 포함합니다.

```text
무엇을 바꿨는지
검증 결과
남은 리스크
다음 단계
```

불필요한 장문 설명보다 변경된 파일과 판단 근거를 우선합니다.
