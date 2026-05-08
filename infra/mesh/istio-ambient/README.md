# Istio Ambient Harness

NHN Cloud NKS에서 Istio Ambient를 설치하고 smoke workload namespace를 ambient mesh에 편입하기 위한 하네스입니다.

## 기준

- Istio 공식 ambient profile 사용
- Gateway API CRD 선행 설치
- 애플리케이션 Pod에는 sidecar injection을 사용하지 않음
- L4 검증은 ztunnel 기준
- L7 검증은 필요 시 waypoint 기준

## 파일

- `istio-operator.yaml`: `istioctl install -f`에 사용할 ambient profile 설정

## 설치

팀 구축 가이드의 `Istio Ambient + Kiali` 단계를 기준으로 실행합니다.

상세 절차: `docs/team/build-guide-istio-ambient-kiali.md`

```bash
istioctl install -f infra/mesh/istio-ambient/istio-operator.yaml --skip-confirmation
kubectl -n istio-system rollout status deployment/istiod --timeout=300s
kubectl -n istio-system rollout status daemonset/istio-cni-node --timeout=300s
kubectl -n istio-system rollout status daemonset/ztunnel --timeout=300s
istioctl analyze
```

## waypoint

smoke namespace에서 L7 waypoint를 함께 검증하려면 다음처럼 실행합니다.

```bash
istioctl waypoint apply -n sidecarless-smoke --enroll-namespace --for service
istioctl waypoint list -n sidecarless-smoke
```

waypoint는 `istioctl waypoint apply -n sidecarless-smoke --enroll-namespace --for service` 흐름을 사용합니다.
