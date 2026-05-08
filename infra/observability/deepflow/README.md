# DeepFlow Harness

DeepFlow를 NHN Cloud NKS에 설치해 L4 flow, L7 request log, AutoTracing을 검증하기 위한 하네스입니다.

## 기준

- 공식 DeepFlow Helm chart 사용
- PoC 기본 chart version: `6.6.018`
- DeepFlow chart가 구성하는 ClickHouse/Grafana를 1차 경로로 사용
- 별도 ClickHouse/Grafana manifest는 fallback 또는 비교용

## 설치

DeepFlow 단독 구축은 `docs/team/build-guide-deepflow-only.md`를 기준으로 합니다. Istio Ambient + Kiali 뒤에 추가하는 경우는 `docs/team/build-guide-istio-ambient-kiali.md`의 선택 단계를 따릅니다.

```bash
helm repo add deepflow https://deepflowio.github.io/deepflow --force-update
helm repo update deepflow

helm upgrade --install deepflow deepflow/deepflow \
  --namespace deepflow \
  --create-namespace \
  --version "$DEEPFLOW_VERSION" \
  -f infra/observability/deepflow/values/poc-values.yaml
```

StorageClass를 명시해야 하면 다음처럼 실행합니다.

```bash
helm upgrade --install deepflow deepflow/deepflow \
  --namespace deepflow \
  --create-namespace \
  --version "$DEEPFLOW_VERSION" \
  -f infra/observability/deepflow/values/poc-values.yaml \
  --set global.storageClass="<storage-class-name>"
```

## 확인

DeepFlow와 Grafana 상태를 확인합니다.

```bash
kubectl -n deepflow get pods,svc,pvc -o wide
kubectl -n deepflow wait --for=condition=Ready pod --all --timeout=900s
kubectl -n deepflow port-forward svc/deepflow-grafana 3000:80
```
