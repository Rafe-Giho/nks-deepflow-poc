# 문서 구조

이 프로젝트 문서는 목적별로 세 구역으로 나눕니다.

## 1. AI 작업용 문서

경로: `docs/ai/`

AI가 사용자의 요청에 맞게 파일과 가이드를 수정할 때 따라야 하는 내부 작업 기준입니다. 팀 배포용 문서가 아닙니다.

주요 파일:

- `00-project-source-of-truth.md`: 프로젝트 단일 기준
- `01-ai-work-harness.md`: AI 작업 절차
- `02-task-playbooks.md`: 반복 작업별 처리 방식
- `03-validation-gates.md`: 단계별 검증 기준
- `04-deprecated-paths.md`: 사용 금지/legacy 경로
- `05-decision-log.md`: 의사결정 기록

## 2. 팀 배포용 구축 문서

경로: `docs/team/`

나중에 엔지니어에게 공유해 그대로 구축하게 할 문서입니다.

주요 파일:

- `01-build-guide.md`: 구축 가이드 선택지
- `build-guide-deepflow-only.md`: DeepFlow 단독 구축 가이드
- `build-guide-istio-ambient-kiali.md`: Istio Ambient + Kiali 구축 가이드
- `02-tool-concepts.md`: 도구와 개념 이론 정리
- `03-validation-checklist.md`: 단계별 체크리스트

## 3. 참고/설계 문서

경로: `docs/reference/`

PoC 배경, 설계안, 기존 분석을 보관하는 참고 문서입니다. 실행 지시의 기준은 `docs/team/`과 `docs/ai/`를 우선합니다.

주요 파일:

- `01-poc-harness-design.md`: PoC 하네스 설계
- `02-project-guide.md`: 프로젝트 가이드
- `03-design-options.md`: 설계안과 방향성
- `04-tool-learning-report.md`: 도구 학습 보고서
