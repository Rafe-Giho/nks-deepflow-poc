# Terraform Module Placeholder: Istio Ambient

PoC 성공 후 Helm provider 또는 manifest 기반으로 Istio Ambient를 Terraform 관리 대상으로 전환하기 위한 자리입니다.

초기 검증 단계에서는 `docs/team/build-guide-istio-ambient-kiali.md`의 Istio Ambient + Kiali 설치 명령과 `infra/mesh/istio-ambient/istio-operator.yaml`을 사용합니다.

전환 후보:

- Gateway API CRD
- Istio base/control plane
- Istio CNI
- ztunnel
- waypoint Gateway 리소스
