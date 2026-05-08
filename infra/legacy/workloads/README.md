# Legacy Echo Workload

이 디렉터리는 이전 `echo-server + traffic-generator` sample workload를 보존합니다.

현재 primary workload는 `infra/apps/smoke`의 smoke web-was-db입니다.

필요 시에만 다음 legacy script로 실행합니다.

```powershell
.\scripts\legacy\30-deploy-legacy-echo-workload.ps1 -ConfirmLegacy
```
