# CTF-команда ШІ-агентів

Команда ізольованих ШІ-агентів (Claude Code), що проходить **авторизовану** навчальну
CTF-машину: один оркестратор делегує задачі спеціалістам (розвідка, веб, експлуатація),
а окремий верифікатор перевіряє кожну знахідку, перш ніж на ній будувати далі.
Поруч — другий контейнер-радник (Antigravity/`agy`) для «свіжого ока», без доступу до
мережі лаби.

Межі агентам ставить **середовище, а не промпт**: контейнер, VPN лише всередині нього,
`iptables`, монтування правил лише на читання і хуки Claude Code.

> ⚠️ Запускати тільки проти цілей, на які є дозвіл (власна лаба, retired HTB, пентест за
> договором). Прапори записуються у `work/state/findings.md` — **сабмітить людина**, не агент.

---

## Вимоги

- Docker + Docker Compose v2
- Залогінений `claude` (Claude Code) — логін підхопиться з домашнього volume контейнера
- Для режиму-радника — залогінений `agy` (Antigravity CLI)
- Для VPN-режиму — ваш `.ovpn` від лаби (напр. HTB)

> На цій машині дефолтний міст `docker0` зламаний, тож якщо треба **перезібрати** образи —
> робіть це з мережею хоста: `docker build --network=host -t ctf-agents-lab .`
> Готові образи вже є, звичайний `docker compose up` цього не потребує.

---

## Структура

```
docker-compose.yml         # VPN-режим (реальна лаба)
docker-compose.novpn.yml   # демо без VPN (ціль — локальний Juice Shop)
Dockerfile                 # образ лаби (Kali + інструменти + claude)
scripts/
  entrypoint.sh            # піднімає VPN, ставить фаєрвол, тримає контейнер
  firewall.sh              # правила iptables (скоуп = рівно одна ціль)
vpn/
  lab.ovpn                 # СЮДИ покласти свій конфіг (root:root 600) — не в git
advisor/                   # контейнер другої думки (agy)
  watch.sh                 # слухає питання, кличе agy, пише відповідь
work/                      # робочий простір агентів (монтується в лабу)
  CLAUDE.md, AGENTS.md     # правила гри (читаються на старті сесії)
  .claude/
    settings.json          # дозволи, хуки, таймаути
    agents/*.md            # по файлу на роль (orchestrator, recon, web, exploit, verifier)
    hooks/*.sh             # scope-guard (межа), log-command (журнал), readonly-state
  scripts/second-opinion.sh# як агент питає радника
  state/notes.md           # «пам'ять» розслідування
  state/findings.md        # підтверджені знахідки / прапори
  advice/                  # обмін із радником (question.txt / answer.md / logs)
demo-watch.sh              # панель спостереження для вебінару
```

---

## Швидкий старт — VPN-режим (реальна лаба / HTB)

Усі команди — з теки проєкту:

```bash
cd ~/webinar/ctf-agents-clean
```

**0. Один раз: покласти ключ і закрити його**

Поклади свій конфіг лаби як `vpn/lab.ovpn`, тоді:

```bash
sudo chown root:root vpn/lab.ovpn && sudo chmod 600 vpn/lab.ovpn
ls -l vpn/lab.ovpn        # має бути: -rw------- root root ...
```

> `root:root 600` — це захист від того, щоб агент прочитав ключ через `cat`.
> Контейнеру це не заважає: `openvpn` там стартує як root.

**1. Якщо лишилися старі контейнери — прибрати**

```bash
docker compose down            # або: docker rm -f ctf-lab ctf-advisor
```

**2. Задати ціль (рівно одна IPv4-адреса)**

```bash
export TARGET_IP=10.129.0.0    # адреса машини лаби
```

**3. Підняти (VPN стартує всередині ctf-lab)**

```bash
docker compose up -d
```

**4. Дочекатись, що VPN встав**

```bash
docker compose logs lab | tail -5      # шукай "VPN up, attacker IP: ..."
```

**5. Запустити оркестратора**

```bash
docker compose exec -u agent -e TARGET_IP lab claude --agent orchestrator
```

**6. Панель для глядачів (другий термінал)**

```bash
cd ~/webinar/ctf-agents-clean && ./demo-watch.sh
```

---

## Альтернатива — без VPN (локальний Juice Shop)

Нічого не монтувати, ключ не потрібен — ціль піднімається поруч у Compose:

```bash
cd ~/webinar/ctf-agents-clean
docker compose -f docker-compose.novpn.yml up -d
docker compose -f docker-compose.novpn.yml exec -u agent lab claude --agent orchestrator
```

Ціль уже прописана (`TARGET_IP=172.30.0.10`, Juice Shop на :3000).

---

## Як цим користуватись

Після `claude --agent orchestrator` оркестратор веде цикл:

1. читає `state/notes.md` + `state/findings.md`;
2. обирає найперспективнішу гіпотезу;
3. делегує її **одному** спеціалісту (`recon` / `web` / `exploit`);
4. кожну заявлену знахідку шле **верифікатору** — той відтворює її з нуля й виносить
   вердикт `CONFIRMED` / `REJECTED` / `INCONCLUSIVE`;
5. оновлює `state/notes.md`;
6. якщо застряг двічі поспіль — питає **радника** через `scripts/second-opinion.sh`.

Йому достатньо дати ціль і сказати, напр., «почни з розвідки». Він навмисно **вербозний**
(проговорює, кого й навіщо кличе) — зручно для демо.

**Що дивитися наживо** (через `./demo-watch.sh` — чотири файли в одному вікні):

| Файл | Що в ньому |
| --- | --- |
| `work/logs/commands.log` | кожна команда агентів (пише хук `log-command`) |
| `work/advice/logs/activity.log` | звернення до радника і його відповіді |
| `work/state/notes.md` | поточна картина розслідування |
| `work/state/findings.md` | підтверджені знахідки та прапори |

**Друга думка (радник):** оркестратор викликає сам; вручну можна так (у лабі):

```bash
docker compose exec -u agent lab scripts/second-opinion.sh "ваше питання"
```

Питання лягає у `work/advice/question.txt`, радник (`ctf-advisor`) читає стан, через `agy`
генерує відповідь і пише у `work/advice/answer.md`. Мережі лаби й радника розділені — радник
цілі не бачить.

**Вартість прогону** видно в самій сесії командою `/cost`; агентів/дозволи/хуки — `/agents`,
`/permissions`, `/hooks`.

---

## Межі безпеки (що тримає агента в скоупі)

- **Фаєрвол (`scripts/firewall.sh`)** — `OUTPUT`/`FORWARD` за замовчуванням `DROP`; у тунель
  пускається **рівно одна** адреса (`TARGET_IP`), назовні — тільки HTTPS (для API моделей),
  IPv6 закритий. CIDR/хостнейм як ціль відхиляється.
- **Хук `scope-guard.sh`** — перед кожною Bash-командою витягає з неї всі IP; чужий або
  діапазон → `Blocked`, агент перепланує (це м'яка рання відмова; жорстку межу тримає ядро).
- **Дозволи (`settings.json`)** — `allow` лише на розвідку/`curl`/`cat`/другу думку; `deny`
  на `iptables`/`openvpn`/`reboot` та `Read` VPN-конфіга; решту Claude Code спитає в людини.
- **Монтування `:ro`** — `.claude`, `AGENTS.md`, `CLAUDE.md`, `scripts` агент переписати не
  може (навіть `curl -o`).
- **Верифікатор** — без права запису + окремий хук блокує будь-який дотик до `state/` з Bash.
- **`no-new-privileges`, лише `NET_ADMIN`** — підвищення привілеїв у контейнері перекрите.

---

## Зупинка і очистка

```bash
docker compose down                               # VPN-режим
docker compose -f docker-compose.novpn.yml down   # режим без VPN
```

Скинути стан між прогонами (щоб агент не «пам'ятав» минулий):

```bash
: > work/logs/commands.log
rm -f work/advice/question.txt work/advice/answer.md work/advice/logs/*.log
git checkout -- work/state/notes.md work/state/findings.md 2>/dev/null \
  || echo "work/state/*.md відредагуй вручну до шаблону"
```

---

## Траблшутінг

| Симптом | Причина / що робити |
| --- | --- |
| `service "lab" is not running` + у логах `cannot open /opt/vpn/lab.ovpn` | немає `vpn/lab.ovpn` — зроби крок 0 |
| `required variable TARGET_IP is missing` | не зроблено `export TARGET_IP=...` перед `docker compose up` |
| `name "/ctf-lab" is already in use` | висить старий контейнер — `docker compose down` або `docker rm -f ctf-lab ctf-advisor` |
| `No route to host` при `docker build` | зламаний `docker0` — збирай із `--network=host` |
| Агент каже `Blocked: <ip> out of scope` | це нормально: хук спіймав адресу поза скоупом |
| Радник не відповідає | `docker logs ctf-advisor` — перевір, що `agy` залогінений |
