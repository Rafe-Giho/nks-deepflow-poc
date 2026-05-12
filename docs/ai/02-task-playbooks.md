# Task Playbooks

반복 작업을 AI가 일관되게 처리하기 위한 플레이북입니다.

## 1. "현재 상태 점검해"

읽을 파일:

```powershell
Get-Content -Raw .\docs\ai\00-project-source-of-truth.md
Get-Content -Raw .\docs\ai\04-deprecated-paths.md
rg --files
git status --short
```

확인할 것:

- 현재 구축 경로와 삭제된 과거 경로 혼동 여부
- README 링크 정합성
- 새 변경이 source-of-truth와 충돌하는지

## 2. "NKS 사전 점검해"

확인 명령:

```powershell
kubectl config current-context
kubectl get nodes -o wide
kubectl get storageclass
kubectl -n kube-system get pods -o wide
kubectl auth can-i create daemonsets.apps -n deepflow
```

보고:

- context
- node OS/kernel
- StorageClass
- Calico mode 추정
- 권한 가능 여부
- DeepFlow/Istio 리스크

## 3. "Istio Ambient 설치 준비해"

수정 대상:

- `infra/mesh/istio-ambient`
- `docs/team/build-guide-istio-ambient-kiali.md`

검증:

```powershell
istioctl version --remote=false
kubectl get crd gateways.gateway.networking.k8s.io
```

실제 설치는 사용자가 요청한 경우에만 수행합니다.

## 4. "DeepFlow 설치 준비해"

수정 대상:

- `infra/observability/deepflow`
- `docs/team/build-guide-deepflow-only.md`
- `docs/team/build-guide-istio-ambient-kiali.md`

검증:

```powershell
helm repo add deepflow https://deepflowio.github.io/deepflow --force-update
helm search repo deepflow/deepflow --versions
```

네트워크가 필요한 검증은 사용자 승인 또는 환경 허용이 필요합니다.

## 5. "smoke app 수정해"

수정 대상:

- `infra/apps/smoke`
- `docs/team/build-guide-deepflow-only.md`
- `docs/team/build-guide-istio-ambient-kiali.md`
- `docs/team/03-validation-checklist.md`

금지:

- echo-server sample을 기본 경로로 되돌리지 않음
- `sidecarless-demo`를 primary namespace로 사용하지 않음

검증:

```powershell
kubectl kustomize .\infra\apps\smoke
```

## 6. "문서 최신화해"

수정 우선순위:

1. `docs/ai/00-project-source-of-truth.md`
2. `docs/team/01-build-guide.md`
3. `docs/team/build-guide-deepflow-only.md`
4. `docs/team/build-guide-istio-ambient-kiali.md`
5. `docs/team/02-tool-concepts.md`
6. `docs/team/03-validation-checklist.md`
7. `docs/README.md`
8. `README.md`

확인:

```powershell
rg -n "Cilium|Hubble|sidecarless-demo|sidecarless-observability|network_events|legacy" README.md docs
```

legacy 언급은 삭제된 과거 산출물, 비범위, 이전 구성 맥락에서만 허용합니다.

## 7. "Terraform 구성해"

수정 대상:

- `infra/terraform/nhn-nks`
- `infra/terraform/modules`

검증:

```powershell
C:\terraform\terraform.exe fmt -check -recursive
C:\terraform\terraform.exe validate
```

금지:

- 승인 없는 `terraform apply`
- 민감정보 커밋
- tfstate 커밋

## 8. "리뷰해"

관점:

- 현재 구축 경로와 삭제된 과거 경로 혼동
- 실제 apply/install이 문서 기본 흐름에 들어갔는지
- 검증 기준이 DeepFlow/Ambient 기준인지
- Kiali가 필요한 경로와 DeepFlow-only 경로가 섞이지 않았는지
- Terraform apply 금지 위반 여부
- 오래된 namespace/table/script 참조

보고:

- findings 우선
- 파일/라인 근거
- 잔여 리스크
