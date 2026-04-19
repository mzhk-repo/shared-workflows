🗺️ Дорожня карта: Міграція на Shared CI/CD

Мета: Проаналізувати вказані локальні директорії репозиторіїв, підготувати для них GitHub Environments та локально згенерувати/оновити файли CI/CD для подальшого ручного коміту та пушу.

Етап 1: Валідація глобального стану (Організація та Центральний репо)

Перевірка базової інфраструктури перед початком масових змін.

[x] 1.1. Перевірка центрального репо: Переконатися, що в репозиторії з шаблонами наявні лише shared-ci-cd.yml та ROADMAP.md.

[x] 1.2. Аудит Organization Secrets (Спільний сервер): Оскільки зараз усі проєкти хостяться на одному сервері, перевірити наявність таких секретів на рівні Організації (в налаштуваннях GitHub):

TS_OAUTH_CLIENT_ID

TS_OAUTH_SECRET

SERVER_HOST (Спільний IP)

SERVER_USER (Спільний юзер)

SERVER_SSH_KEY (Спільний ключ)

SSH_HOST_KEY_PUB

💡 Архітектурна примітка (Future-proof): Коли в майбутньому проєкти переїдуть на власні сервери, достатньо буде створити секрети з такими ж іменами (SERVER_HOST, SERVER_SSH_KEY тощо) у розділі Environments конкретного репозиторію. GitHub Actions автоматично перевизначить (override) організаційний секрет на секрет середовища. Код пайплайну при цьому змінювати не потрібно.

Етап 2: Фаза Discovery (Локальний аудит)

Збір контексту з локальних директорій проєктів.

[ ] 2.1. Цільові директорії: Опрацювати наступний список локальних шляхів по черзі, не всі одразу:

✅ /home/pinokew/cloudflare-tunnel

✅ /home/pinokew/Dspace/DSpace-docker

✅ /home/pinokew/Koha/koha-deploy

✅ /home/pinokew/Matomo-analytics

✅ /home/pinokew/Traefik

✅ /home/pinokew/victoriametrics-grafana

✅ /home/pinokew/kdv-integrator/kdv-integrator-event

/home/pinokew/Koha/koha-docker-build

[ ] 2.2. Аналіз стеку (для кожної директорії):

Перевірити наявність Dockerfile в корені (це впливатиме на параметр build_and_push_docker).

Перевірити наявність старих конфігурацій у .github/workflows/*.yml.

Перед видаленням старих workflow обов'язково проаналізувати `.github/workflows/` на наявність існуючих патернів, кастомних умов та скриптів перевірки/деплою, які мають бути перенесені в локальний `main.yml`.

Окремо проаналізувати наявність pre-deploy/post-deploy скриптів і сформувати/оновити єдиний repo-specific скрипт оркестрації (рекомендований шлях: `scripts/deploy-orchestrator.sh`).

Визначити ім'я репозиторію на GitHub (з файлу .git/config або командою git remote get-url origin).

Етап 3: Налаштування Environments (GitHub)

Підготовка середовищ на GitHub для кожного цільового репозиторію.

Для КОЖНОГО знайденого репозиторію необхідно виконати :

[х] 3.1. ✅ Створення середовища production (виконано):

Створити Environment з назвою production.

Створити секрет DEPLOY_PROJECT_DIR у цьому середовищі. Значення формується на основі назви проєкту (наприклад, /opt/apps/<repo-name>).

[x] 3.2. ✅ Створення середовища development (виконано):

Створити Environment з назвою development.

Створити секрет DEPLOY_PROJECT_DIR для dev-сервера (наприклад, /opt/apps/dev-<repo-name>).


Етап 4: Локальна генерація коду

Фізична зміна файлів на локальному комп'ютері. Коміти та пуші на цьому етапі не виконуються.

Для КОЖНОЇ цільової директорії:

[ ] 4.1. Аналіз перед очищенням: Перед видаленням старих workflow зафіксувати потрібні патерни/кастомні кроки/опціональні скрипти з `.github/workflows/` конкретного репо для перенесення в новий локальний `main.yml`.

[ ] 4.2. Очищення: Після аналізу видалити застарілі файли CI/CD з `.github/workflows/` (наприклад, старі `ci-cd.yml`).

[ ] 4.3. Створення нового пайплайну: Створити новий `.github/workflows/main.yml` на базі шаблону `/home/pinokew/shared-workflows/main.example.yml` з урахуванням виявлених локальних патернів і опціональних скриптів.

Логіка запуску середовищ (оновлено):

- development:
  - PR у гілку dev: запускаються тільки CI-перевірки.
  - Push (merge) у гілку dev: запускаються CI-перевірки + деплой у development.

- production:
  - PR у гілку main (включно з PR dev -> main): запускаються тільки CI-перевірки.
  - Push (merge) у гілку main: запускаються CI-перевірки без деплою.
  - CD у production виконується тільки при створенні релізу з тегом формату vx.x.x (наприклад, v1.2.3).

Шаблон для генерації (Ansible наразі вимкнено):

name: App Pipeline

on:
  push:
    branches: [ dev, main ]
  pull_request:
    branches: [ dev, main ]
  release:
    types: [ published ]

jobs:
  deploy-dev:
    if: github.event_name == 'pull_request' && github.base_ref == 'dev' || github.event_name == 'push' && github.ref == 'refs/heads/dev'
    uses: ВАША_ОРГАНІЗАЦІЯ/shared-workflows/.github/workflows/shared-ci-cd.yml@main
    with:
      environment_name: 'development'
      deploy: ${{ github.event_name == 'push' && github.ref == 'refs/heads/dev' }}
      use_ansible: false # Ansible поки що не використовуємо
      build_and_push_docker: true # Встановити true/false залежно від наявності Dockerfile у проєкті
      docker_image_name: '<назва_репозиторію>'
    secrets: inherit

  deploy-prod:
    if: github.event_name == 'pull_request' && github.base_ref == 'main' || github.event_name == 'push' && github.ref == 'refs/heads/main' || github.event_name == 'release' && startsWith(github.event.release.tag_name, 'v')
    uses: ВАША_ОРГАНІЗАЦІЯ/shared-workflows/.github/workflows/shared-ci-cd.yml@main
    with:
      environment_name: 'production'
      deploy: ${{ github.event_name == 'release' && startsWith(github.event.release.tag_name, 'v') }}
      use_ansible: false # Ansible поки що не використовуємо
      build_and_push_docker: true # Встановити true/false залежно від наявності Dockerfile у проєкті
      docker_image_name: '<назва_репозиторію>'
    secrets: inherit

Примітка: для суворої перевірки саме формату vx.x.x варто додати regex-перевірку тега (наприклад, ^v[0-9]+\.[0-9]+\.[0-9]+$) у кроці валідації всередині пайплайну.

Важливо: repo-specific кроки (`verify-env.sh`, `patch-local.cfg.sh`, `init-volumes.sh` та інші) потрібно консолідувати в єдиний скрипт оркестрації (рекомендовано `scripts/deploy-orchestrator.sh`), який викликається через `shared-ci-cd.yml` опційно.

Оновлена модель опціональних скриптів: локальний `main.yml` не запускає repo-specific скрипти окремими job (щоб не хардкодити тулзи типу `actions/checkout`), а лише передає `orchestration_script_path` у reusable workflow. У `shared-ci-cd.yml` цей скрипт викликається опційно (тільки якщо файл існує), інакше крок пропускається.

Правило централізації тулзів: усі версії GitHub Actions/CI тулзів (`actions/checkout`, `docker/*`, `tailscale/*`, `trivy`, `gitleaks` тощо) мають керуватися в `shared-workflows`; у локальних репозиторіях не хардкодимо ці тулзи, локальний `main.yml` лише оркеструє виклики reusable workflow з `shared-workflows`.

Правило синхронізації шаблону: якщо змінюємо будь-яку логіку в локальному `.github/workflows/main.yml`, таку саму зміну потрібно внести і в `/home/pinokew/shared-workflows/main.example.yml`.


Етап 5: Ручні дії та фіналізація

Завершальний етап міграції.

[ ] 5.1. Фінальна перевірка: Переконатися, що у відповідних репозиторіях на GitHub створено середовища та секрети DEPLOY_PROJECT_DIR, а локально згенеровано нові файли main.yml.

[ ] 5.2. Коміт та пуш: Відкрити термінал, зайти в кожну опрацьовану директорію зі списку та виконати наступні команди:

git add .github/workflows/
git commit -m "chore: migrate to shared CI/CD"
git push


🛠️ Технічні примітки для автоматизації:

Ізоляція змін: Будь-які скрипти автоматизації мають лише модифікувати файли. Виконання git commit або git push повинно залишатися суворо ручним кроком.

Скрипт перевірки типу: ./scripts/verify-env.sh і т.д. для кожно репу повинні бути опційними, повинна бути можливість добавляти унікальні скрипти для кожного репо

## Фаза 8 — CI/CD Integration (Shared GitHub Actions Workflow)

**Пріоритет: P1**

### Мета
Автоматизувати SOPS-based deploy Swarm-стеків через GitHub Actions з дешифруванням `env.dev.enc` / `env.prod.enc` у CI runtime, із скупленням Docker Secrets через Ansible та розгортанням стеків через per-repo orchestration скрипти, з мінімізацією витоку секретів і збереженням source-of-truth в runbooks.

Репо стеків:
1. `/opt/cloudflare-tunnel/` 
2. `/opt/Traefik/`
3. `/opt/kdv-integrator/kdv-integrator-event/`
4. `/opt/Dspace/DSpace-docker/`
5. `/opt/Koha/koha-deploy/`
6. `/opt/Matomo-analytics/`
7. `/opt/victoriametrics-grafana/`

### Архітектурні принципи

1. **Ранбуки = source of truth для manual ops**: `/opt/Ansible/docs/RUNBOOKS/0X-*.md` описують покроково, як розгорнути стек на `dev-manager-01` вручну. CI автоматизує те ж.

2. **Спільний SOPS age key**: один private age key для всіх (dev+prod), зберігається **тільки** у GitHub Environment Secrets, ніколи на сервері.

3. **GitHub Environment Secrets для dev/prod розділення**: 
   - Environment "development" → `SOPS_AGE_KEY`, `SERVER_HOST` (dev), `SSH_*`, etc.
   - Environment "production" → `SOPS_AGE_KEY` (той же ключ), `SERVER_HOST` (prod), `SSH_*`, etc.
   - Кожна job має `environment: ${{ inputs.environment_name }}` → автоматично гранулює секрети

4. **Per-repo orchestration скрипти розділені за режимом деплою**:
   - `scripts/deploy-orchestrator.sh` = legacy compose path.
   - Якщо `scripts/deploy-orchestrator.sh` вже викликає `docker compose`, **його не чіпаємо**.
   - Для Swarm/SOPS додаємо окремий `scripts/deploy-orchestrator-swarm.sh`.
   - Swarm-скрипт відповідає за `ansible --tags secrets`, `docker stack deploy`, smoke-check і rollback logic.
   - **App-specific логіка деплою має бути у per-repo скриптах, не у shared workflow.**

5. **Shared workflows = оркестратори, не виконавці**:
   - `shared-ci-cd.yml` = dispatcher (backward-compatible entrypoint для всіх repo).
   - `shared-ci-cd-compose.yml` = legacy Docker Compose flow.
   - `shared-ci-cd-swarm.yml` = Docker Swarm + SOPS+age flow.

### Що робимо

#### 8.1 GitHub Environment Secrets (налаштувати вручну в GitHub UI)

Для **кожного** Environment (development + production):

| Secret | Значення | Примітка |
|--------|----------|---------|
| `SOPS_AGE_KEY` | Private age key (вихідний текст `AGE-SECRET-KEY-...`) | Один ключ для обох env; маскується у логах |
| `SERVER_HOST` | IP або hostname Swarm manager (dev: dev-manager-01, prod: prod-manager) | Environment-scoped |
| `SERVER_USER` | `ansible_usr` | Environment-scoped |
| `SERVER_SSH_KEY` | Private SSH key (ed25519) для `ansible_usr` | Environment-scoped |
| `SSH_HOST_KEY_PUB` | Public host key сервера (вихід `ssh-keyscan`) | Environment-scoped |
| `DEPLOY_PROJECT_DIR` | Path на сервері (наприклад, `/opt/cloudflare-tunnel`) | Environment-scoped |
| `INFRA_REPO_PAT` | GitHub PAT для клонування `/opt/shared-workflows` | Organization secret, або Environment |
| `TS_OAUTH_CLIENT_ID` | Tailscale OAuth ID | Organization level (shared) |
| `TS_OAUTH_SECRET` | Tailscale OAuth secret | Organization level (shared) |

**Важливо:** GitHub Environment Secrets автоматично **не видим у логах** і зберігаються окремо по Environment. Одне ім'я може мати різні значення у dev vs prod.

#### 8.2 Shared Workflow Enhancement (split на `compose` + `swarm`)

**Цільова структура shared-workflows:**

- `/opt/shared-workflows/.github/workflows/shared-ci-cd.yml` — dispatcher (вхідна точка для backward compatibility).
- `/opt/shared-workflows/.github/workflows/shared-ci-cd-compose.yml` — legacy Docker Compose path.
- `/opt/shared-workflows/.github/workflows/shared-ci-cd-swarm.yml` — Swarm + SOPS+age path.

**Принцип маршрутизації:**
- `use_ansible: false` → викликається `shared-ci-cd-compose.yml`.
- `use_ansible: true` → викликається `shared-ci-cd-swarm.yml`.

```yaml
jobs:
  legacy-compose:
    if: inputs.use_ansible == false
    uses: ./.github/workflows/shared-ci-cd-compose.yml
  swarm-sops:
    if: inputs.use_ansible == true
    uses: ./.github/workflows/shared-ci-cd-swarm.yml
```

#### 8.3 Per-Repo Orchestration Scripts (compose + swarm)

**Правило сумісності для існуючих repo:**
- Якщо `scripts/deploy-orchestrator.sh` уже містить `docker compose` команди — **не модифікувати цей файл**.
- Для Swarm/SOPS створити окремий `scripts/deploy-orchestrator-swarm.sh`.

**Входи для swarm-скрипта (через CI):**
- `DEPLOY_PROJECT_DIR` — локальний шлях репо
- `ENVIRONMENT_NAME` — "development" або "production"
- `DEPLOY_REF` — git commit SHA
- `INFRA_REPO_PATH` — шлях до Ansible repo на manager

**Мінімальний приклад:**
- `scripts/deploy-orchestrator.sh` (legacy): залишаємо як є для `docker compose up -d`.
- `scripts/deploy-orchestrator-swarm.sh` (new): `ansible-playbook --tags secrets` + `docker stack deploy`.

#### 8.4 Per-Repo main.yml (оновлення)

**Вимога backward compatibility:** `main.yml` у кожному repo має лишатися сумісним з обома режимами (`compose` і `swarm`) через dispatcher `shared-ci-cd.yml`.

**Правило:**
- `uses` не змінюємо: `.../.github/workflows/shared-ci-cd.yml@main`.
- Перемикання режиму робимо тільки через `use_ansible` + `orchestration_script_path`.

```yaml
name: App Pipeline

on:
  push:
    branches: [dev, main]
    paths-ignore:
      - '**/*.md'
      - '.env.example'
      - '.gitignore'
  pull_request:
    branches: [dev, main]
    paths-ignore:
      - '**/*.md'
      - '.env.example'
      - '.gitignore'
  release:
    types: [published]

permissions:
  contents: read
  packages: write

jobs:
  deploy-dev:
    if: |
      (github.event_name == 'pull_request' && github.base_ref == 'dev') ||
      (github.event_name == 'push' && github.ref == 'refs/heads/dev')
    uses: mzhk-repo/shared-workflows/.github/workflows/shared-ci-cd.yml@main
    with:
      environment_name: development
      deploy: ${{ github.event_name == 'push' && github.ref == 'refs/heads/dev' }}
      use_ansible: true
      build_and_push_docker: false
      docker_image_name: app-name
      # Swarm path: окремий скрипт, legacy compose script не чіпаємо
      orchestration_script_path: 'scripts/deploy-orchestrator-swarm.sh'
    secrets:
      TS_OAUTH_CLIENT_ID: ${{ secrets.TS_OAUTH_CLIENT_ID }}
      TS_OAUTH_SECRET: ${{ secrets.TS_OAUTH_SECRET }}
      SERVER_HOST: ${{ secrets.SERVER_HOST }}
      SERVER_USER: ${{ secrets.SERVER_USER }}
      SERVER_SSH_KEY: ${{ secrets.SERVER_SSH_KEY }}
      SSH_HOST_KEY_PUB: ${{ secrets.SSH_HOST_KEY_PUB }}
      DEPLOY_PROJECT_DIR: ${{ secrets.DEPLOY_PROJECT_DIR }}
      INFRA_REPO_PAT: ${{ secrets.INFRA_REPO_PAT }}
      SOPS_AGE_KEY: ${{ secrets.SOPS_AGE_KEY }}

  deploy-prod:
    if: |
      github.event_name == 'release' && startsWith(github.event.release.tag_name, 'v')
    uses: mzhk-repo/shared-workflows/.github/workflows/shared-ci-cd.yml@main
    with:
      environment_name: production
      deploy: true
      use_ansible: true
      build_and_push_docker: false
      docker_image_name: app-name
      orchestration_script_path: 'scripts/deploy-orchestrator-swarm.sh'
    secrets:
      TS_OAUTH_CLIENT_ID: ${{ secrets.TS_OAUTH_CLIENT_ID }}
      TS_OAUTH_SECRET: ${{ secrets.TS_OAUTH_SECRET }}
      SERVER_HOST: ${{ secrets.SERVER_HOST }}
      SERVER_USER: ${{ secrets.SERVER_USER }}
      SERVER_SSH_KEY: ${{ secrets.SERVER_SSH_KEY }}
      SSH_HOST_KEY_PUB: ${{ secrets.SSH_HOST_KEY_PUB }}
      DEPLOY_PROJECT_DIR: ${{ secrets.DEPLOY_PROJECT_DIR }}
      INFRA_REPO_PAT: ${{ secrets.INFRA_REPO_PAT }}
      SOPS_AGE_KEY: ${{ secrets.SOPS_AGE_KEY }}
```

#### 8.5 Ansible Playbook (без змін, як є)

Playbook `playbooks/swarm.yml` вже підтримує `--tags secrets`:

```bash
# Фазу 7 уже підготувалась role + playbook
ansible-playbook -i inventories/dev \
                 playbooks/swarm.yml \
                 --tags secrets \
                 -e @/tmp/env.decrypted
```

Role `swarm_cluster` читає env vars (через `-e @file`) і створює Docker Secrets у Swarm.

#### 8.6 Документація: `docs/CI-CD.md` (нова)

Мета: описати end-to-end CI flow для користувачів/операторів.

**Структура `docs/CI-CD.md`:**
- GitHub Environment Secrets setup (manual UI steps)
- Per-repo main.yml примеры
- Orchestration script template
- Troubleshooting: "Why did deploy fail?", "How to manually trigger?", etc.
- Security best practices: "Where is SOPS_AGE_KEY stored?", "Can CI access plaintext?"

### Залежності
- Фази 0–7 завершені
- GitHub Environment Secrets налаштовані для dev + prod (SOPS_AGE_KEY, SERVER_HOST, SSH_*, DEPLOY_PROJECT_DIR)
- Ansible repo доступна через INFRA_REPO_PAT
- SOPS + age встановлено в CI runner (або install step у workflow)
- Per-repo `scripts/deploy-orchestrator.sh` (legacy compose) існує або не потребує змін
- Per-repo `scripts/deploy-orchestrator-swarm.sh` створений для Swarm/SOPS path

### Ризики
| Ризик | Мітигація |
|-------|-----------|
| `SOPS_AGE_KEY` у логах GitHub Actions | GitHub автоматично маскує Environment Secrets; додатково: `no_log: true` на sensitive steps, `--version` для утилітне (не передавати ключ як аргумент) |
| Plaintext env залишається на runner після job | `shred -vfz -n 3 /tmp/env.decrypted` перед exit (cleanup step з `always()`) |
| Diff dev vs prod deploy логіки | Orchestration скрипт отримує `ENVIRONMENT_NAME` і використовує той же код; все контролюється per-repo |
| Ansible repo недоступна або стара версія | `git fetch --all` у shared workflow перед use; перевіста INFRA_REPO_PAT |
| App repo не має `scripts/deploy-orchestrator-swarm.sh` | Fallback у swarm workflow: базовий `docker stack deploy` (але рекомендується мати окремий swarm-скрипт) |

### Definition of Done
- [ ] Спільний SOPS age key передано у GitHub Environment Secrets (dev + prod)
- [ ] Shared workflows розділено: `shared-ci-cd-compose.yml` + `shared-ci-cd-swarm.yml`, а `shared-ci-cd.yml` працює як dispatcher
- [ ] `shared-ci-cd-swarm.yml` дешифрує env.dev.enc / env.prod.enc на runtime (in-memory)
- [ ] Per-repo main.yml backward-compatible з обома режимами через `use_ansible` + `orchestration_script_path`
- [ ] `scripts/deploy-orchestrator.sh` (compose) збережений без змін, якщо містить `docker compose`
- [ ] `scripts/deploy-orchestrator-swarm.sh` присутній (або fallback у swarm workflow)
- [ ] Перший push до dev branch тригерить deploy через CI (все успішно)
- [ ] Перший release tag на main тригерить deploy до prod (все успішно)
- [ ] Дешифрований env не залишається у логах / run artifacts
- [ ] Cleanup step видаляє plaintext з runner перед exit
- [ ] docs/CI-CD.md написано й звіряється з实際workflow

### Чекліст для впровадження

**GitHub UI (manual one-time):**
- [ ] Development Environment: SOPS_AGE_KEY, SERVER_HOST, SERVER_USER, SERVER_SSH_KEY, SSH_HOST_KEY_PUB, DEPLOY_PROJECT_DIR, INFRA_REPO_PAT
- [ ] Production Environment: SOPS_AGE_KEY (один ключ), SERVER_HOST (prod), SERVER_USER, SERVER_SSH_KEY, SSH_HOST_KEY_PUB, DEPLOY_PROJECT_DIR, INFRA_REPO_PAT
- [ ] Organization-level: TS_OAUTH_CLIENT_ID, TS_OAUTH_SECRET (якщо не Environment-specific)

**Shared Workflow repo (`mzhk-repo/shared-workflows`):**
- [ ] Винести legacy flow у `.github/workflows/shared-ci-cd-compose.yml`
- [ ] Винести Swarm/SOPS flow у `.github/workflows/shared-ci-cd-swarm.yml`
- [ ] Оновити `.github/workflows/shared-ci-cd.yml` у dispatcher-mode
- [ ] Перевірити routing `use_ansible=false/true`

**Per-Repo (кожна з 7 stack):**
- [ ] Оновити `.github/workflows/main.yml` з backward-compatible викликом dispatcher (`shared-ci-cd.yml`)
- [ ] Перевірити, що `scripts/deploy-orchestrator.sh` (compose) не змінювався, якщо містить `docker compose`
- [ ] Створити `scripts/deploy-orchestrator-swarm.sh` для Swarm/SOPS path
- [ ] Перевірити `docker-compose.swarm.yml`: secrets/env_file/ labels налаштовані
- [ ] Перевірити `env.dev.enc` + `env.prod.enc` присутні у repo
- [ ] Перевірити `.pre-commit-config.yaml`: SOPS validation hook
- [ ] Тест: `docker compose --env-file env.dev.enc config` має успіти
- [ ] Тест: push на dev branch → CI deploy до dev (очікується success)

**Documentation:**
- [ ] Створити `docs/CI-CD.md` у Ansible repo
- [ ] Додати примеры per-repo main.yml и orchestration script
- [ ] Описати Environment Secrets UI setup
- [ ] Описати troubleshooting (deploy stuck, secret missing, etc.)
- [ ] Оновити ROADMAP.md розділ "Структура docs/" — додати посилання на CI-CD.md

### Артефакти

**Shared Workflow:**
- `/opt/shared-workflows/.github/workflows/shared-ci-cd.yml` (dispatcher)
- `/opt/shared-workflows/.github/workflows/shared-ci-cd-compose.yml` (new/updated)
- `/opt/shared-workflows/.github/workflows/shared-ci-cd-swarm.yml` (new/updated)

**Per-Repo (кожна з 7):**
- `.github/workflows/main.yml` (updated: backward-compatible dispatcher call)
- `scripts/deploy-orchestrator.sh` (legacy compose, unchanged якщо вже `docker compose`)
- `scripts/deploy-orchestrator-swarm.sh` (new/updated)
- `env.dev.enc` + `env.prod.enc` (already exist from Phase 7)
- `docker-compose.swarm.yml` (existing, no changes needed)

**Ansible Repo:**
- `ansible/playbooks/swarm.yml` (no changes: already supports `--tags secrets`)
- `ansible/roles/swarm_cluster/tasks/secrets.yml` (no changes: already handles SOPS vars)
- `docs/CI-CD.md` (new)