# 설계안과 방향성

현재 PoC의 설계 우선순위는 DeepFlow 기반 관측 경로를 안정적으로 구축하고, 이후 실제 앱/CI/CD/Terraform으로 확장하는 것입니다.

## 1. 1순위. DeepFlow chart 기본 구성

DeepFlow Helm chart가 제공하는 Agent, Server, ClickHouse, Grafana를 그대로 사용합니다.

장점:

- 구축 속도가 빠릅니다.
- 공식 chart 기준이라 재현성이 높습니다.
- ClickHouse/Grafana 연결을 직접 설계하지 않아도 됩니다.

주의:

- PVC와 StorageClass가 안정적이어야 합니다.
- chart values 변경은 최소화하고 검증된 값만 반영합니다.

## 2. 2순위. NKS Cinder StorageClass 표준화

NKS `csi-cinder` add-on을 전제로 `sgh-cinder-sc`를 사용합니다.

장점:

- DeepFlow ClickHouse/MySQL persistence 기준이 명확합니다.
- 팀 구축 가이드와 실제 매니페스트가 일치합니다.

주의:

- 이미 생성된 StorageClass의 일부 필드는 변경이 제한됩니다.
- quota와 volume type은 NHN Cloud 환경별로 확인해야 합니다.

## 3. 3순위. web-was-db 관측 검증

실제 앱의 web -> was -> db 흐름을 기준으로 DeepFlow dashboard와 ClickHouse query를 검증합니다.

장점:

- PoC 결과가 실제 서비스 구조와 직접 연결됩니다.
- HTTP/DB traffic을 함께 확인할 수 있습니다.

주의:

- 앱 자체 오류와 관측 오류를 분리해야 합니다.
- 트래픽이 충분히 발생해야 Grafana map/metric이 의미 있게 보입니다.

## 4. 4순위. 커스텀 dashboard

DeepFlow 기본 dashboard를 기반으로 web-was-db 전용 dashboard를 추가합니다.

장점:

- 팀이 확인해야 할 정보만 빠르게 볼 수 있습니다.
- namespace/service/pod 단위 비교가 쉬워집니다.

주의:

- DeepFlow datasource query schema에 맞춰야 합니다.
- Grafana map layout은 기본 panel의 제약을 받습니다.

## 5. 5순위. Terraform 전환

검증된 절차를 NKS/Helm/Kubernetes provider로 전환합니다.

장점:

- 재현성과 변경 추적성이 좋아집니다.
- 운영 표준화에 적합합니다.

주의:

- 현재 단계에서는 `plan`까지만 수행합니다.
- 민감정보, kubeconfig, tfstate는 커밋하지 않습니다.
