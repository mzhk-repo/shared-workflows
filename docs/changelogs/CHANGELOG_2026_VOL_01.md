# CHANGELOG 2026 VOL 01

Статус: `active`
Відкрито: `2026-04-19`
Контекст: продовження Фази 8.


## 2026-04-17 — ROADMAP Phase 8 rewritten: CI/CD Integration with SOPS decrypt in GitHub Actions + per-repo orchestration scripts

- **Context:** На основі детального аналізу requirement-ів для Фази 8 (voir Phase 8 CI/CD flow) потрібно було переписати ROADMAP Фаза 8, щоб явно описати архітектуру: спільний SOPS age key у GitHub Environment Secrets, дешифрування env.dev.enc/env.prod.enc в CI runtime в-memory, Ansible playbook --tags secrets для Docker Secrets, per-repo orchestration скрипти як місце для app-specific логіки, та ранбуки як source of truth для manual ops.
- **Change:** Повністю переписано розділ "## Фаза 8 — CI/CD Integration (Shared GitHub Actions Workflow)" у `docs/ROADMAP.md` з наступними деталями:
  - **Архітектурні принципи:** 5 пунктів про розподіл відповідально (runbooks + CI automation, SOPS key scoping, Environment Secrets для dev/prod розділення, per-repo scripts vs shared workflow orchestration)
  - **8.1 GitHub Environment Secrets:** явна таблиця з dev + prod Environment mappings (SOPS_AGE_KEY як спільний, SERVER_HOST як різний)
  - **8.2 Shared Workflow Enhancement:** new bash код для SOPS install + decrypt step, Ansible checkout, per-repo orchestration script invocation через SSH, cleanup step для rm /tmp/env.decrypted
  - **8.3 Per-Repo Orchestration Script:** детальний template bash-скрипт (git fetch/checkout, Ansible --tags secrets invocation, docker compose config + stack deploy, force service update, smoke-check, cleanup)
  - **8.4 Per-Repo main.yml:** YAML приклад з `use_ansible: true` і параметрами для dev/prod jobs
  - **8.5 Ansible Playbook:** примітка що `playbooks/swarm.yml --tags secrets` вже готова (no changes)
  - **8.6 Documentation: docs/CI-CD.md:** нова документація (須創 в Фазі 8)
  - **Залежності, ризики, DoD, чекліст:** узгоджено з узгодженими вимогами (БЕЗ apt update/upgrade, force redeploy як per-repo logic, no duplication runbooks-CI)
- **Verification:** Оновлений ROADMAP містить: явну diff від попередньої версії (более коротке описання SOPS流 у старій версії), детальні YAML/bash приклади для CI integraton, посилання на per-repo orchestration як місце для app-specific деплою-логіки, 5 архітектурних принципів, явні GitHub UI steps та per-repo поточання.
- **Docs:** Оновлено також таблицю у розділі "Структура docs/" для явного посилання на `CI-CD.md` (Фаза 8) із деталізованим описом flow.
- **Notes:** Це чисто планова/документаційна зміна без інфраструктурних модифікацій; фактична імплементація (Ansible playbook updates, shared-ci-cd.yml rewrite, per-repo script creation) залишається на рівні Фази 8 under DoD execution notes.

## 2026-04-18 — Phase 8 step 1 (`/opt/cloudflare-tunnel`): додано per-repo orchestration script і підключено його в app workflow без switch на `use_ansible`

- **Context:** Розпочато фактичне виконання Фази 8 строго інкрементально з репозиторію `/opt/cloudflare-tunnel/`; перший крок мав бути безпечним і не ламати поточний shared workflow, який ще працює у legacy-режимі для `use_ansible`.
- **Change:** У `/opt/cloudflare-tunnel/scripts/deploy-orchestrator.sh` додано новий оркестратор із режимами `noop` (дефолт) та `swarm` (`ORCHESTRATOR_MODE=swarm`), з рендером `docker compose ... config` + `docker stack deploy`, fallback для env-файлу (`/tmp/env.decrypted` -> `.env`) і автодефолтами `CF_TUNNEL_TOKEN_SECRET_NAME` за `ENVIRONMENT_NAME`; у `/opt/cloudflare-tunnel/.github/workflows/main.yml` для `deploy-dev` і `deploy-prod` додано явний `orchestration_script_path: 'scripts/deploy-orchestrator.sh'`.
- **Verification:** `bash -n /opt/cloudflare-tunnel/scripts/deploy-orchestrator.sh` проходить успішно; `git -C /opt/cloudflare-tunnel status --short` показує лише очікувані зміни (`M .github/workflows/main.yml`, `?? scripts/deploy-orchestrator.sh`); `use_ansible` залишено `false` в обох jobs, тобто поточний CI поведінково не переведено на ризиковий path.
- **Risks:** Поки `shared-ci-cd.yml` не оновлено до SOPS-runtime flow з roadmap (SOPS decrypt + cleanup + Ansible `--tags secrets`), увімкнення `use_ansible: true` у repo не можна робити без ризику зламу деплою.
- **Rollback:** Видалити `/opt/cloudflare-tunnel/scripts/deploy-orchestrator.sh`, прибрати `orchestration_script_path` з `/opt/cloudflare-tunnel/.github/workflows/main.yml`.

## 2026-04-19 — Phase 8 step 2 (`/opt/shared-workflows`): `shared-ci-cd.yml` переведено з legacy Vault/apt path на SOPS runtime deploy-path для `use_ansible=true`

- **Context:** Після кроку 1 (підготовка `cloudflare-tunnel` оркестратора) потрібно було закрити головний blocking-gap: у shared workflow `use_ansible=true` ще використовував legacy flow (`ANSIBLE_VAULT_PASSWORD` + `apt install ansible`) і не відповідав новій архітектурі Фази 8.
- **Change:** У `/opt/shared-workflows/.github/workflows/shared-ci-cd.yml` для `workflow_call` додано `inputs.infra_repo_path` (default `/opt/Ansible`) і `secrets.SOPS_AGE_KEY`; повністю замінено legacy-блок `use_ansible == true` на Phase 8 runtime flow: валідація `SOPS_AGE_KEY`, інсталяція `sops` + `age` (без `apt update/upgrade`), decrypt `env.dev.enc`/`env.prod.enc` у `/tmp/env.decrypted`, передача env на remote host через `scp`, запуск repo-specific оркестратора в `ORCHESTRATOR_MODE=swarm` (або fallback `docker stack deploy`), cleanup plaintext на remote і runner.
- **Verification:** YAML проходить парсинг (`YAML_OK` через `yaml.safe_load`); diff показує очікувану заміну legacy Ansible/Vault блоку на SOPS runtime блок; `git -C /opt/shared-workflows status --short` містить лише `M .github/workflows/shared-ci-cd.yml`.
- **Risks:** Новий path для `use_ansible=true` тепер вимагає наявності `SOPS_AGE_KEY` і `env.dev.enc`/`env.prod.enc` у app repo; якщо repo не має `scripts/deploy-orchestrator.sh` з swarm-логікою, спрацює fallback deploy; інтеграція `ansible-playbook --tags secrets` поки делегується на per-repo orchestration script і не виконується централізовано в shared workflow.
- **Rollback:** Відкотити `/opt/shared-workflows/.github/workflows/shared-ci-cd.yml` до попередньої ревізії з legacy-блоком.

## 2026-04-19 — Phase 8 step 3 (`/opt/shared-workflows`): монолітний `shared-ci-cd.yml` розділено на два профільні reusable workflow

- **Context:** Після оновлення SOPS-path у кроці 2 файл `/opt/shared-workflows/.github/workflows/shared-ci-cd.yml` виріс до ~472 рядків і містив дві різні стратегії деплою в одному місці; потрібно було фізично розділити legacy compose та swarm+sops логіку.
- **Change:** Додано два нові workflow-файли: `/opt/shared-workflows/.github/workflows/shared-ci-cd-compose.yml` (тільки legacy deploy через `docker compose`) і `/opt/shared-workflows/.github/workflows/shared-ci-cd-swarm.yml` (Swarm + SOPS+age path); поточний `/opt/shared-workflows/.github/workflows/shared-ci-cd.yml` перетворено на тонкий dispatcher (117 рядків), який маршрутизує у відповідний файл за `inputs.use_ansible`, щоб не ламати існуючі виклики repo-ів (`uses: .../shared-ci-cd.yml@main`).
- **Verification:** `yaml.safe_load` успішно парсить усі три файли (`YAML_OK_ALL`); поточні розміри: dispatcher `117` рядків, compose `305` рядків, swarm `374` рядки; `git -C /opt/shared-workflows status --short` показує очікувано `M .github/workflows/shared-ci-cd.yml` + `?? .github/workflows/shared-ci-cd-compose.yml` + `?? .github/workflows/shared-ci-cd-swarm.yml`.
- **Risks:** CI-checks секція наразі дублюється у двох профільних workflow (compose/swarm); при майбутніх змінах перевірок потрібно оновлювати обидва файли синхронно.
- **Rollback:** Видалити `/opt/shared-workflows/.github/workflows/shared-ci-cd-compose.yml` і `/opt/shared-workflows/.github/workflows/shared-ci-cd-swarm.yml`, повернути попередню версію `/opt/shared-workflows/.github/workflows/shared-ci-cd.yml`.

## 2026-04-19 — Phase 8 roadmap alignment: зафіксовано split workflows + правило окремого swarm-оркестратора + backward compatibility для per-repo `main.yml`

- **Context:** Після фактичного split shared workflow на `shared-ci-cd-compose.yml` і `shared-ci-cd-swarm.yml` потрібно було синхронізувати сам `docs/ROADMAP.md`, щоб план і реалізація Фази 8 не розходились.
- **Change:** У `docs/ROADMAP.md` (розділ Фази 8) оновлено: 1) архітектурні принципи і секцію `8.2` під трифайлову модель (`shared-ci-cd.yml` dispatcher + `shared-ci-cd-compose.yml` + `shared-ci-cd-swarm.yml`); 2) секцію `8.3` з явним правилом: якщо `scripts/deploy-orchestrator.sh` вже викликає `docker compose`, його не змінювати, а для Swarm/SOPS створювати окремий `scripts/deploy-orchestrator-swarm.sh`; 3) секцію `8.4` і чеклісти/DoD/артефакти під вимогу backward compatibility per-repo `main.yml` через dispatcher (`use_ansible` + `orchestration_script_path`).
- **Verification:** Перевірено цілісний блок Фази 8 після редагування (`sed -n '734,1165p' docs/ROADMAP.md`): присутні нові назви workflow-файлів, правило незмінності compose-скрипта та вимога backward compatibility для `main.yml`; зміни суто документаційні, без інфраструктурного деплою.
- **Risks:** У roadmap-прикладі `main.yml` показано Swarm-варіант (`use_ansible: true`); для repo, що ще не мігрували на Swarm path, потрібно тимчасово тримати `use_ansible: false` і `orchestration_script_path: scripts/deploy-orchestrator.sh` до окремого інкрементного переходу.
- **Rollback:** Відкотити зміни в `docs/ROADMAP.md` до попередньої ревізії Фази 8.

## 2026-04-19 — Phase 8 step 4 (`/opt/cloudflare-tunnel`): `main.yml` переключено на `use_ansible: true` під split shared workflow

- **Context:** Після split shared workflow і синхронізації roadmap потрібно було виконати запланований крок 3 для `cloudflare-tunnel`: переключити app pipeline на Swarm/SOPS path і додати необхідні параметри виклику.
- **Change:** У `/opt/cloudflare-tunnel/.github/workflows/main.yml` для `deploy-dev` і `deploy-prod` встановлено `use_ansible: true`; додано `infra_repo_path: '/opt/Ansible'`; у секцію `secrets` додано `SOPS_AGE_KEY`; збережено `orchestration_script_path: 'scripts/deploy-orchestrator.sh'` для сумісності з наявним оркестратором repo.
- **Verification:** YAML синтаксис валідний (`YAML_OK`); `git diff` показує очікувані зміни лише в `main.yml`; `git -C /opt/cloudflare-tunnel status --short` показує `M .github/workflows/main.yml` і наявний раніше `?? scripts/deploy-orchestrator.sh`.
- **Risks:** Поточний `scripts/deploy-orchestrator.sh` у cloudflare-tunnel не викликає `ansible-playbook --tags secrets`; при відсутньому/простроченому Docker Secret `cf_tunnel_token_*` deploy може потребувати окремого кроку з оновленням secret або переходу на `scripts/deploy-orchestrator-swarm.sh`.
- **Rollback:** Повернути `use_ansible: false` у `deploy-dev`/`deploy-prod` і прибрати додані `infra_repo_path` + `SOPS_AGE_KEY` з `/opt/cloudflare-tunnel/.github/workflows/main.yml`.
