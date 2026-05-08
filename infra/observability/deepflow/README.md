# DeepFlow Harness

DeepFlow를 NHN Cloud NKS에 설치해 L4 flow, L7 request log, AutoTracing을 검증하기 위한 하네스입니다.

## 기준

- 공식 DeepFlow Helm chart 사용
- PoC 기본 chart version: `6.6.018`
- DeepFlow chart가 구성하는 ClickHouse/Grafana를 1차 경로로 사용
- 별도 ClickHouse/Grafana manifest는 fallback 또는 비교용

## 설치

```powershell
.\scripts\30-install-deepflow.ps1
.\scripts\31-check-deepflow.ps1
```

StorageClass를 명시해야 하면 다음처럼 실행합니다.

```powershell
.\scripts\30-install-deepflow.ps1 -StorageClass "<storage-class-name>"
```

## 확인

DeepFlow Grafana 접속 명령은 검증 스크립트가 출력합니다.

```powershell
.\scripts\31-check-deepflow.ps1
```
