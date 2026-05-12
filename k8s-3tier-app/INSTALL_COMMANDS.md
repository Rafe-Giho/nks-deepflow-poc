# SGH 3-Tier App 설치 명령 모음

이 문서는 `k8s-3tier-app` 매니페스트를 NHN Cloud NKS에 배포하기 위한 명령 모음입니다. 기준 경로는 NGINX Gateway Fabric + Gateway API + cert-manager + NKS `csi-cinder`입니다.

## 0. 전제

- 대상 클러스터는 NHN Cloud NKS입니다.
- `kubectl` context는 대상 NKS를 가리킵니다.
- NKS에는 `csi-cinder` add-on이 추가되어 있습니다.
- GatewayClass 이름은 `nginx`입니다.
- 외부 도메인은 `www.jininfra.cloud`입니다.
- DB PVC는 기본적으로 Cinder Block Storage를 사용합니다.
- 기존 Ingress cookie affinity는 NGINX Gateway Fabric OSS 기준 `UpstreamSettingsPolicy`의 `ip_hash`로 대체합니다.

## 1. 작업 변수

```bash
export APP_DIR="k8s-3tier-app"
export NGF_VERSION="v2.6.0"
export NGF_CHART_VERSION="2.6.0"
export CERT_MANAGER_VERSION="v1.20.2"
export APP_HOSTNAME="www.jininfra.cloud"
```

## 2. 클러스터 사전 확인

```bash
kubectl config current-context
kubectl cluster-info
kubectl get nodes -o wide

kubectl get csidriver | grep cinder
kubectl -n kube-system get pods -o wide | grep -i cinder

kubectl auth can-i create gatewayclasses.gateway.networking.k8s.io
kubectl auth can-i create gateways.gateway.networking.k8s.io -n sgh-web-ns
kubectl auth can-i create httproutes.gateway.networking.k8s.io -n sgh-web-ns
kubectl auth can-i create clusterissuers.cert-manager.io
kubectl auth can-i create storageclasses.storage.k8s.io
kubectl auth can-i create networkpolicies.networking.k8s.io -n sgh-web-ns
```

## 3. Gateway API CRD 설치

NGINX Gateway Fabric이 지원하는 Gateway API standard CRD를 설치합니다.

```bash
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=${NGF_VERSION}" \
  | kubectl apply -f -

kubectl get crd gatewayclasses.gateway.networking.k8s.io
kubectl get crd gateways.gateway.networking.k8s.io
kubectl get crd httproutes.gateway.networking.k8s.io
kubectl get crd referencegrants.gateway.networking.k8s.io
```

## 4. NGINX Gateway Fabric 설치

```bash
helm upgrade --install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
  --namespace nginx-gateway \
  --create-namespace \
  --version "${NGF_CHART_VERSION}" \
  --wait

kubectl -n nginx-gateway get pods,svc -o wide
kubectl get gatewayclass nginx
kubectl get crd upstreamsettingspolicies.gateway.nginx.org
kubectl auth can-i create upstreamsettingspolicies.gateway.nginx.org -n sgh-web-ns
```

## 5. cert-manager 설치

Gateway API HTTP-01 solver를 쓰기 위해 `config.enableGatewayAPI=true`를 켭니다.

```bash
helm upgrade --install cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version "${CERT_MANAGER_VERSION}" \
  --set crds.enabled=true \
  --set config.enableGatewayAPI=true \
  --wait

kubectl -n cert-manager get pods,svc -o wide
kubectl get crd certificates.cert-manager.io
kubectl get crd clusterissuers.cert-manager.io
```

이미 cert-manager가 설치된 상태에서 Gateway API CRD를 나중에 설치했다면 재시작합니다.

```bash
kubectl -n cert-manager rollout restart deployment/cert-manager
kubectl -n cert-manager rollout status deployment/cert-manager --timeout=180s
```

## 6. 애플리케이션 전체 적용

아래 명령 한 번으로 `k8s-3tier-app` 루트의 YAML을 파일명 순서대로 적용합니다.

```bash
kubectl apply -f "${APP_DIR}"
```

적용 순서:

```text
00-sgh-namespace.yaml
01-sgh-configMaps.yaml
02-sgh-secret.yaml
03-sgh-storageclass-PVC-BS.yaml
04-sgh-Service.yaml
05-sgh-StatefulSet-db.yaml
06-sgh-Deployment-was.yaml
07-sgh-Deployment-web.yaml
08-sgh-Netpol.yaml
09-sgh-clusterissuer.yaml
10-sgh-Gateway.yaml
```

## 7. 애플리케이션 namespace 확인

```bash
kubectl get ns sgh-web-ns
kubectl get ns sgh-was-ns
kubectl get ns sgh-db-ns
```

## 8. ConfigMap과 Secret 확인

```bash
kubectl -n sgh-web-ns get configmap sgh-web-cm
kubectl -n sgh-was-ns get configmap sgh-was-cm
kubectl -n sgh-db-ns get configmap sgh-db-cm
kubectl -n sgh-db-ns get secret sgh-db-sec
```

## 9. DB StorageClass와 PVC 확인

기본은 NKS Cinder Block Storage입니다.

```bash
kubectl get storageclass sgh-cinder-sc
kubectl -n sgh-db-ns get pvc sgh-db-pvc
kubectl get storageclass sgh-cinder-sc \
  -o jsonpath='{.provisioner}{"\t"}{.volumeBindingMode}{"\t"}{.reclaimPolicy}{"\n"}'
```

## 10. Service 확인

```bash
kubectl -n sgh-db-ns get svc sgh-db-svc
kubectl -n sgh-was-ns get svc sgh-was-svc
kubectl -n sgh-web-ns get svc sgh-web-svc
```

## 11. Workload 확인

```bash
kubectl -n sgh-db-ns rollout status statefulset/sgh-db-sts --timeout=300s

kubectl -n sgh-was-ns rollout status deployment/sgh-was-dpl --timeout=300s

kubectl -n sgh-web-ns rollout status deployment/sgh-web-dpl --timeout=300s

kubectl -n sgh-db-ns get pods,pvc -o wide
kubectl -n sgh-was-ns get pods -o wide
kubectl -n sgh-web-ns get pods -o wide
```

## 12. NetworkPolicy 확인

```bash
kubectl -n sgh-web-ns get networkpolicy
kubectl -n sgh-was-ns get networkpolicy
kubectl -n sgh-db-ns get networkpolicy
kubectl -n sgh-web-ns describe networkpolicy sgh-nginx-gateway-allow
```

## 13. ClusterIssuer 확인

`09-sgh-clusterissuer.yaml`은 Gateway API HTTP-01 solver를 사용합니다.

```bash
kubectl get clusterissuer letsencrypt-prod
kubectl describe clusterissuer letsencrypt-prod
```

## 14. Gateway와 HTTPRoute 확인

```bash
kubectl -n sgh-web-ns get gateway sgh-web-gateway -o wide
kubectl -n sgh-web-ns get httproute
kubectl -n sgh-web-ns get upstreamsettingspolicy sgh-web-session-affinity
kubectl -n sgh-web-ns describe gateway sgh-web-gateway
kubectl -n sgh-web-ns describe httproute sgh-web-route
kubectl -n sgh-web-ns describe httproute sgh-web-http-redirect
kubectl -n sgh-web-ns describe upstreamsettingspolicy sgh-web-session-affinity
```

NGINX Gateway Fabric은 Gateway 생성 후 같은 namespace에 data plane을 만듭니다.

```bash
kubectl -n sgh-web-ns get deploy,svc,pod -l gateway.networking.k8s.io/gateway-name=sgh-web-gateway -o wide
kubectl -n sgh-web-ns get svc sgh-web-gateway-nginx -o wide
kubectl -n nginx-gateway get svc,pod -o wide
```

세션 고정 설정은 다음 명령으로 NGINX 설정에 `ip_hash`가 들어갔는지 확인합니다.

```bash
kubectl -n sgh-web-ns exec deploy/sgh-web-gateway-nginx -- nginx -T \
  | grep -A5 'upstream.*sgh-web-svc'
```

주의:

- `ip_hash`는 client IP 기반 affinity입니다.
- 앞단 Load Balancer나 NAT 때문에 여러 사용자가 같은 source IP로 보이면 같은 backend Pod로 몰릴 수 있습니다.
- 기존 Ingress의 cookie 기반 sticky session과 완전히 동일하지 않습니다.
- cookie 기반 session persistence가 필요하면 NGINX Plus와 Gateway API experimental 기능을 별도로 켜야 합니다.

## 15. DNS Plus 등록

Gateway 외부 주소를 확인한 뒤 DNS Plus에 `A` record를 등록합니다.

```bash
kubectl -n sgh-web-ns get gateway sgh-web-gateway \
  -o jsonpath='{.status.addresses[0].value}{"\n"}'

kubectl -n sgh-web-ns get svc sgh-web-gateway-nginx -o wide
```

DNS Plus에 등록합니다.

```text
www.jininfra.cloud -> <Gateway EXTERNAL-IP>
```

DNS가 전파됐는지 확인합니다.

```bash
dig +short "${APP_HOSTNAME}"
```

## 16. 인증서 발급 확인

```bash
kubectl -n sgh-web-ns get certificate
kubectl -n sgh-web-ns get certificaterequest
kubectl -n sgh-web-ns get order
kubectl -n sgh-web-ns get challenge
kubectl -n sgh-web-ns describe certificate jininfra-tls
kubectl -n sgh-web-ns get secret jininfra-tls
```

문제가 있으면 cert-manager 로그를 확인합니다.

```bash
kubectl -n cert-manager logs deployment/cert-manager --tail=200
kubectl -n cert-manager logs deployment/cert-manager --tail=200 | grep -i 'gateway\|challenge\|error' || true
```

초기 Gateway readiness 문제 등으로 HTTP-01 challenge가 `invalid` 또는 `errored`가 된 경우에는 실패 리소스를 정리해 재시도합니다.

```bash
kubectl -n sgh-web-ns delete certificate jininfra-tls --ignore-not-found
kubectl -n sgh-web-ns delete certificaterequest jininfra-tls-1 --ignore-not-found
kubectl -n sgh-web-ns delete order --all --ignore-not-found
kubectl -n sgh-web-ns delete challenge --all --ignore-not-found

kubectl -n sgh-web-ns get certificate,certificaterequest,order,challenge,secret -o wide
```

## 17. 외부 접속 확인

Gateway 주소를 확인합니다.

```bash
kubectl -n sgh-web-ns get gateway sgh-web-gateway \
  -o jsonpath='{.status.addresses[0].value}{"\n"}'

kubectl -n sgh-web-ns get svc sgh-web-gateway-nginx -o wide
```

DNS 반영 전에는 `curl --resolve`로 먼저 확인합니다.

```bash
export GW_ADDR="$(kubectl -n sgh-web-ns get gateway sgh-web-gateway -o jsonpath='{.status.addresses[0].value}')"

curl -I --resolve "${APP_HOSTNAME}:80:${GW_ADDR}" "http://${APP_HOSTNAME}/sgh/"
curl -k -I --resolve "${APP_HOSTNAME}:443:${GW_ADDR}" "https://${APP_HOSTNAME}/sgh/"
curl -k --resolve "${APP_HOSTNAME}:443:${GW_ADDR}" "https://${APP_HOSTNAME}/sgh/"
```

인증서 발급 후에는 `-k` 없이 확인합니다.

```bash
curl -I "https://${APP_HOSTNAME}/sgh/"
curl "https://${APP_HOSTNAME}/sgh/"
```

## 18. 전체 상태 점검

```bash
kubectl get gatewayclass
kubectl -n nginx-gateway get pods,svc -o wide
kubectl -n cert-manager get pods -o wide

kubectl -n sgh-web-ns get all,gateway,httproute,certificate,secret,networkpolicy -o wide
kubectl -n sgh-was-ns get all,networkpolicy -o wide
kubectl -n sgh-db-ns get all,pvc,networkpolicy -o wide
```

## 19. dry-run 검증

CRD와 cert-manager가 설치된 뒤 실행합니다.

```bash
kubectl apply --dry-run=server -f "${APP_DIR}"
```

## 20. 정리 명령

실제 삭제가 필요한 경우에만 실행합니다.

```bash
# kubectl delete -f "${APP_DIR}/10-sgh-Gateway.yaml"
# kubectl delete -f "${APP_DIR}/09-sgh-clusterissuer.yaml"
# kubectl delete -f "${APP_DIR}/08-sgh-Netpol.yaml"
# kubectl delete -f "${APP_DIR}/07-sgh-Deployment-web.yaml"
# kubectl delete -f "${APP_DIR}/06-sgh-Deployment-was.yaml"
# kubectl delete -f "${APP_DIR}/05-sgh-StatefulSet-db.yaml"
# kubectl delete -f "${APP_DIR}/04-sgh-Service.yaml"
# kubectl delete -f "${APP_DIR}/03-sgh-storageclass-PVC-BS.yaml"
# kubectl delete -f "${APP_DIR}/02-sgh-secret.yaml"
# kubectl delete -f "${APP_DIR}/01-sgh-configMaps.yaml"
# kubectl delete -f "${APP_DIR}/00-sgh-namespace.yaml"
```

플랫폼 구성요소까지 제거할 경우:

```bash
# helm uninstall cert-manager -n cert-manager
# kubectl delete namespace cert-manager
# helm uninstall ngf -n nginx-gateway
# kubectl delete namespace nginx-gateway
```

## 21. 공식 문서

- NGINX Gateway Fabric Helm install: https://docs.nginx.com/nginx-gateway-fabric/install/helm/
- NGINX Gateway Fabric data plane: https://docs.nginx.com/nginx-gateway-fabric/install/deploy-data-plane/
- NGINX Gateway Fabric session persistence: https://docs.nginx.com/nginx-gateway-fabric/traffic-management/session-persistence/
- cert-manager Helm install: https://cert-manager.io/docs/installation/helm/
- cert-manager Gateway API HTTP-01: https://cert-manager.io/docs/configuration/acme/http01/
