# AI 작업용 문서

이 디렉터리는 AI가 사용자의 명령에 맞게 프로젝트 파일과 가이드를 수정할 때 사용하는 내부 문서입니다.

팀 배포용 구축/학습 문서는 `docs/team/`에 둡니다.

## 읽는 순서

1. `00-project-source-of-truth.md`
2. `01-ai-work-harness.md`
3. `04-deprecated-paths.md`
4. `02-task-playbooks.md`
5. `03-validation-gates.md`
6. `05-decision-log.md`

## 원칙

- 현재 구축 경로는 DeepFlow 단독과 Istio Ambient + Kiali로 분리합니다.
- legacy 경로를 기본 실행 흐름으로 되돌리지 않습니다.
- 구축 경로 선택 기준은 `docs/team/01-build-guide.md`에 반영합니다.
- 실제 실행 명령은 `docs/team/build-guide-deepflow-only.md` 또는 `docs/team/build-guide-istio-ambient-kiali.md`에 반영합니다.
- 도구/개념 설명은 `docs/team/02-tool-concepts.md`에 반영합니다.
