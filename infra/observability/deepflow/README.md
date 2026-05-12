# DeepFlow Harness

DeepFlow를 NHN Cloud NKS에 설치해 L4 flow, L7 request log, AutoTracing을 검증하기 위한 하네스입니다.

## 기준

- 공식 DeepFlow Helm chart 사용
- PoC 검증 chart version: `7.1.002`
- DeepFlow chart가 구성하는 ClickHouse/Grafana를 1차 경로로 사용
- NKS `csi-cinder` add-on과 `sgh-cinder-sc` StorageClass 사용

## 설치

DeepFlow 구축은 `docs/team/build-guide-deepflow-only.md`를 기준으로 합니다.

```bash
helm repo add deepflow https://deepflowio.github.io/deepflow --force-update
helm repo update deepflow

kubectl apply -f infra/observability/deepflow/storageclass/sc-cinder.yaml

helm upgrade --install deepflow deepflow/deepflow \
  --namespace deepflow \
  --create-namespace \
  --version "7.1.002" \
  -f infra/observability/deepflow/values/poc-values.yaml \
  --wait \
  --timeout 20m
```

`poc-values.yaml`은 `global.storageClass: sgh-cinder-sc`를 기본값으로 사용합니다.

## 확인

DeepFlow와 Grafana 상태를 확인합니다.

```bash
kubectl -n deepflow get pods,svc,pvc -o wide
kubectl -n deepflow wait --for=condition=Ready pod --all --timeout=900s
kubectl -n deepflow port-forward svc/deepflow-grafana 3000:80
```
