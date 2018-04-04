# enotowombat_microservices
# HW14 Docker-1

### Установка
Устанавливаем Docker по инструкции, проверяем версию: `Docker version 17.12.0-ce`
Чтобы не делать sudo docker, создаем группу docker и добавляем туда своего пользователя 

### Задание
Проходим по инструкции в задании. Не копирую сюда действия, они именно такие, как там написано
Вывод `docker images` в docker-1.log
Удаляем образы и контейнеры

### Задание со *
Сравниваем docker inspect <u_container_id> и docker inspect <u_image_id>
Вообще, разница image и container, как понял:
Image - набор RO слоев, каждый новый содержит diff с предыдущим. Слои связываются указателями на id родителя. Union FS представляет набор слоев как один 
Container - image + верхний RW слой, для записи. Можно его закоммитить, слой станет RO, получим новый образ. При удалении контейера удалится только этот верхний RW слой, остальные - образ - останутся

`docker inspect` - получаем метаданные верхнего слоя image/container

Параметры(некоторые)
- Image
Parent - указатель на id образа родителя - нижележащего предыдущего слоя
Container - id контейера, из которого создан образ
ContainerConfig - совпадает с Config контейнера, видимо там хранится кофиг контейнера, из которого этот образ был создан. Не содержит NetworkSettings
Architecture, Os, список слоев (Layers) 

- Container
State (Status, Pid, StartedAt, FinishedAt)
Параметры создания контейнера Image, Env, Cmd, Entrypoint, пути (ResolvConfPath, HostnamePath, HostsPath, LogPath), HostConfig (Memory/CPU/IO limits и другие параметры cgroups, PidMode, UsernsMode, namespace параметры). 
NetworkSettings. В остановленном контейнере параметры (IPAddress, Gateway, MacAddress) будут пустыми

# HW 15 Docker-2

- docker-machine установлен
- новый проект создан, gcloud сконфигурирован
- docker-хост создан

### Сравнение команд:
`docker run --rm -ti tehbilly/htop` - htop показывает результат только для контейнера, контейнер ограничен своим namespace
`docker run --rm --pid host -ti tehbilly/htop` - для хоста. можем видеть htop для всего хоста (инстанса gce), т.к. работаем в namespace хоста

- `Dockerfile`, `mongod.conf`, `db_config`, `start.sh`
- собираем образ
- запускаем контейнер
- добавляем правило фаервола
- логинимся в docker hub, загружаем образ


# HW 16 Docker-3


Использовался linter hadolint
Изменения в Dockerfiles для следования рекомендациям:
- Delete the apt-get lists after installing something, добавил `apt-get clean && rm -rf /var/lib/apt/lists/*`
- Avoid additional packages by specifying `--no-install-recommends`
- Замена ADD на COPY
- Замена ENV на ARG для переменной, нужной только на время сборки образа

Новая структура приложения скопирована, образы созданы

### "Cборка ui началась не с первого шага" 
Первый шаг Step 1/13 : FROM ruby:2.2 --> id образа, уже созданного при сборке comment, используем его, также для других шагов использовались кэши с прошлой сборки 

Сеть создана, контейнеры запущены, работает

### "Запустите контейнеры с другими сетевыми алиасами"
Меняем алиасы, передаем новые названия в `--env`
`docker run -d --network=reddit --network-alias=post_db2 --network-alias=comment_db2 mongo:latest`
`docker run -d --network=reddit --network-alias=post2 --env POST_DATABASE_HOST=post_db2 enot/post:1.0 `
`docker run -d --network=reddit --network-alias=comment2 --env COMMENT_DATABASE_HOST=comment_db2  enot/comment:1.0`
`docker run -d --network=reddit -p 9292:9292 --env POST_SERVICE_HOST=post2 --env COMMENT_SERVICE_HOST=comment2 enot/ui:1.0`
Работает

Меняем `ui/Dockerfile`
### "Пересоберем ui (с какого шага началась сборка?)"
C первого, на первом шаге используем новый образ, кэш не используется

### Образ на основе alpine linux
- Отключаем кэш `--no-cache`. С этой опцией не нужно делать `--update` и после установки чистить кэш apk 
- Выясняем, какие пакеты минимально необходимы, получилось так: ruby, build-base, ruby-dev, ruby-bundler. И еще ruby-json 
- Используем Virtual Packages, `--virtual` или `-t`. Включаем пакеты, нужные только на время сборки, в виртуальную группу, потом удаляем группу. Просто для удобства
- Временно добавляем `apk add bash`, чтобы подключиться к контейнеру и посмотреть что еще можно почистить (нашелся /root/.bundle/cache который судя по названию нам не нужен)
- Всю установку и чистку собираем в один RUN 
- Размер уменьшился:
`REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
enot/ui             4.0                 35f376dec6cf        11 seconds ago      37MB`

Используем docker volume, проверяем, работает


# HW 17


- Запускаем контейнер с none-драйвером. Доступен только loopback
- Запускаем контейнер с host-драйвером. Доступны все интерфейсы докер хоста

### Сравните выводы команд: `> docker exec -ti net_test ifconfig` `> docker-machine ssh docker-host ifconfig`
Одинаково, контейнер использует netns хоста

### Запустите несколько раз (2-4) `> docker run --network host -d nginx` Каков результат? 
Работает только один контейнер (первый). Потому что `[emerg] 1#1: bind() to 0.0.0.0:80 failed (98: Address already in use)`. Сетевые ресурсы для контейнеров не изолированы, находятся в одном netns, соответственно два сервиса в разных котейнерах, но на одном порту запустить нне получится.

### Повторите запуски контейнеров с использованием драйверов none и host и посмотрите, как меняется список namespace-ов
Для none-драйвер контейнера создается новый netns, для host-драйвер - нет, использутся default netns хоста

- Создаем bridge-сеть, запускаем в ней контейнеры, останавливаем, присваеваем network алиасы, запускаем
- Запускам проект в двух сетях
- Смотрим на сеть

### docker-compose
- Изменить docker-compose под кейс с множеством сетей, сетевых алиасов. Добавляем в сервисы `networks:` и `aliases:`
- Параметризуйте с помощью переменных окружений:
порт публикации сервиса ui: `${UI_PORT}`
версии сервисов: `${UI_VERSION}`, `${POST_VERSION}`, `${COMMENT_VERSION}`

### Узнайте как образуется базовое имя проекта. Можно ли его задать? Если можно то как? 
Образуется по имени проектной директории, задать можно установкой переменной `COMPOSE_PROJECT_NAME`
`COMPOSE_PROJECT_NAME. Sets the project name. This value is prepended along with the service name to the container on start up. If you do not set this, the COMPOSE_PROJECT_NAME defaults to the basename of the project directory`

### docker-compose.override.yml 

### - Изменять код каждого из приложений, не выполняя сборку образа:
Вариант деплоя приложений на удаленный докер хост с использованием docker-machine, docker-compose упоминается в документации docker:
https://docs.docker.com/machine/reference/scp/#specifying-file-paths-for-remote-deployments 
Так и делаем. Копируем приложения с помощью `docker-machine scp`:
`$ docker-machine scp -r post-py/ docker-host:~/apps/post-py/`
`$ docker-machine scp -r comment/ docker-host:~/apps/comment/`
`$ docker-machine scp -r ui/ docker-host:~/apps/ui/`
Используем bind mounts, добавляем в `docker-compose.override.yml` `volumes`:
`- "/home/docker-user/apps/ui:/app"`
`- "/home/docker-user/apps/post-py:/app"`
`- "/home/docker-user/apps/comment:/app"`
Проверяем, `docker-compose up -d` - done, `docker ps`: все появились, сервис работает

### - Запускать puma для руби приложений в дебаг режиме с двумя воркерами: 
добавляем в `docker-compose.override.yml`:
`command: ["puma", "--debug", "-w", "2"]`

# HW19 Docker-6

- создаем ВМ (1 vCPU, 5.5 GB memory), для удобства берем static ip
- ставим docker
- запускаем Gitlab CI, настраиваем
- запускаем runner, регистрируем
- джобы работают, тесты проходят


### Auto runners setup

У меня был вариант создания нужного количества раннеров с `--non-interactive` регистрацией ансиблом, количество раннеров, токен задавать вручную. Но, увидев, что коллеги пользуются runner autoscaling, понял, что держать десятки все время поднятых раннеров - не очень хорошая идея, нужно делать именно autoscaling

Настраиваем

- Все окружение готовим в уже созданной ВМ gitlab-ci
- Запускаем в контейнерах Docker Registry и Cache Server (registry чтобы не тащить каждый раз образы с Dockerhub, cache для кэширования данных сборок местно, в gce):
`docker run -d -p 6000:5000 \
    -e REGISTRY_PROXY_REMOTEURL=https://registry-1.docker.io \
    --restart always \
    --name registry registry:2`
`docker run -it --restart always -p 9005:9000 \
        -v /.minio:/root/.minio -v /export:/export \
        --name minio \
        minio/minio:latest server /export`
Можно их добавить в docker-compose.yml
- Ставим Docker Machine, cоздаем и регистрируем новый runner, указываем executor docker+machine
- Настраиваем runner 
`config.toml`:
```
concurrent = 5
check_interval = 5

[[runners]]
  name = "my-autoscale-runner"
  url = "CI_SERVER_URL"
  token = "REGISTRATION_TOKEN"
  executor = "docker+machine"
  limit = 6
  [runners.docker]
    tls_verify = false
    image = "ruby:2.1"
    privileged = false
    disable_cache = false
    volumes = ["/cache"]
    shm_size = 0
  [runners.cache]
    Type = "s3"
    ServerAddress = "MY_CACHE_IP:9005"
    AccessKey = "ACCESS_KEY"
    SecretKey = "SECRET_KEY"
    BucketName = "runner"
    Insecure = true
  [runners.machine]
    IdleCount = 1
    MachineDriver = "google"
    MachineName = "gitlab-runner-%s"
    MachineOptions = [
      "google-project=docker-xxxxxx",
      "google-machine-type=g1-small",
      "google-machine-image=ubuntu-os-cloud/global/images/ubuntu-1604-xenial-v20180126",
      "google-tags=default-allow-ssh",
      "google-preemptible=true",
      "google-zone=europe-west1-b",
      "google-use-internal-ip=true"
    ]
    OffPeakTimezone = ""
    OffPeakIdleCount = 0
    OffPeakIdleTime = 0
```
- генерим ключ для gce service account, копируем в gilab-ci ВМ, монтируем volume с ключем в runner контейнер, путь указываем в GOOGLE_APPLICATION_CREDENTIALS
`docker-compose.yml`:
```
web:
  image: 'gitlab/gitlab-ce:latest'
  restart: always
  hostname: 'gitlab.example.com'
  environment:
    GITLAB_OMNIBUS_CONFIG: |
      external_url 'CI_SERVER_URL'
      # Add any other gitlab.rb configuration here, each on its own line
  ports:
    - '80:80'
    - '443:443'
    - '2222:22'
  volumes:
    - '/srv/gitlab/config:/etc/gitlab'
    - '/srv/gitlab/logs:/var/log/gitlab'
    - '/srv/gitlab/data:/var/opt/gitlab'

runner:
  image: 'gitlab/gitlab-runner:latest'
  container_name: 'gitlab-runner'
  restart: always
  environment:
    - GOOGLE_APPLICATION_CREDENTIALS=/etc/gitlab-runner/gce-credentials.json
  volumes:
    - '/srv/gitlab-runner/config:/etc/gitlab-runner'

```
- запускаем, проверяем. С виду работает, на несколько пушей подряд создаются новые машины с названиями типа `runner-be2265a1-gitlab-runner-1519281417-b8c4439c`, джобы выполняются, если слишком много сразу то лишние становились canceled


### Интеграция со Slack
Добавил Incoming WebHook, вписал его в Slack notifications, скриншот добавлю в PR


# Homework 20 docker-7


### Основное
- создаем новый проект example2
- включаем раннер
- stage deploy -> review, deploy_job -> deploy_dev_job, + environment. Появился dev Environment, джобы отработали
- +stage, production stages. В пайплайне появились Stage и Production. Когда выполнился Review, в Environments появились stage и production
- добавляем ограничение only. Без тега stage и production в pipeline нет, с тегом - есть
- добавлям динамичское окружение. Создаем два новых бранча, в Environments появляются сгруппированные branch/bugfix и branch/new-feature


### * и **

- Используем docker-in-docker (dind):
```
image: docker:latest
services:
    - docker:dind
```
- Using the privileged mode to start the build and service containers
`config.toml`: `privileged = true`
- В build_job собираем образ из `docker-monolith`, все в одном. И делаем push в repository (docker docker hub)
- В branch review делаем pull ранее сохраннного образа и запускаем в GCE инстансе (с помощью docker-machine)
- Для остановки review окружения добавляем джоб `stop_review`. Удаляем созданный ранее GCE инстанс gcloud'ом, для этого используем контейнер с образом `google/cloud-sdk:latest`, но можно взять образ поменьше, cloud-sdk:alpine. 
Нужно убедиться, что GCE инстанс с ранером имеет права на удаление ВМ. У меня раннер работал на ВМ c gitlab-ci, статически, поэтому `Cloud API access scopes` проставил вручную. Для динамически создавамых ВМ с раннерами видимо нужно указывать права при создании в опции --scopes (возможно, compute-rw, https://www.googleapis.com/auth/compute, но не проверял)
- Сделать в review окружении url = vm_ip:9292, получив ip сразу после создания vm, не получилось, потому что `You however cannot use variables defined under script or on the Runner's side`
- Использованные Secret variables:
`DOCKER_USER`
`DOCKER_PASSWORD`
`GCE_PROJECT_ID`
`GOOGLE_APPLICATION_CREDENTIALS`


- `config.toml':
```
concurrent = 5
check_interval = 3

[[runners]]
  name = "runner2"
  url = "http://104.199.54.44/"
  token = "02e19f153582e4a3f172615b2bbeea"
  executor = "docker"
  [runners.docker]
    tls_verify = false
    image = "docker:latest"
    privileged = true
    disable_cache = false
    volumes = ["/var/run/docker.sock:/var/run/docker.sock", "/srv/gitlab-runner/config:/etc/gitlab-runner", "/cache"]
    shm_size = 0
  [runners.cache]
```

Во время тестов наплодилось множество коммитов, по итогам просто все изменения сделал как один коммит, иначе плохо выглядит


# HW 21. Monitoring-1

- Готовим окружение
- Запускаем Prometheus, смотрим на него
- Меняем структуру директорий
- Собираем образы (в Dockerfile prometheus нерекомендованный `ADD` поменял на `COPY`)
- Тестируем healthcheck'и
docker-compose stop post_db -> comment_health=0 -> comment_health_mongo_availability=0 -> 
docker-compose start post_db -> comment_health_mongo_availability=1 -> comment_health=1
- Добавляем node-exporter
- Добавляем сети:
```
networks:
  - back_net
  - front_net
```
- Docker hub: https://hub.docker.com/u/enot/ 


### * MongoDB exporter

Взял этот: https://github.com/dcu/mongodb_exporter
Есть еще, например, такой: https://github.com/percona/mongodb_exporter, форк dcu/mongodb_exporter, но у меня первый сразу заработал, не стал другие тестить

Небольшой нюанс. Надо немного поправить Makefile, `perl -p -i -e 's/{{VERSION}}/$(TAG)/g' mongodb_exporter.go`, экранировать скобку
Раньше это видимо работало с deprecation warning, в новых версиях perl уже ошибка, `Unescaped left brace in regex is illegal`

Сначала просто собрал образ и положил на docker hub, в microservices репозиторий ничего не добавлял: 
`git clone https://github.com/dcu/mongodb_exporter.git`
`docker build -t enot/mongodb_exporter .`
`docker push enot/mongodb_exporter`

Но в последнем задании нужно было делать билд всех используемых образов, поэтому сделал Dockerfile 
Пришлось добавить туда немного sed'а, наверно это не очень хорошо
`RUN cd /go/src/github.com/dcu/mongodb_exporter && sed -i 's!{V!\\{V!' Makefile && make release`

`docker-compose.yml`:
```
  mongo-exporter:
    image: ${USERNAME}/mongodb_exporter:${MONGO_EXPORTER_VERSION}
    networks:
      - back_net
    command:
      - '-mongodb.uri=mongodb://post_db:27017'
```

`prometheus.yml`:
```
  - job_name: 'mongo'
    static_configs:
      - targets:
        - 'mongo-exporter:9001'
```

Появились mongodb-метрики


### * Blackbox exporter

- Добавляем сервис из стандартного образа
`docker-compose.yml`:
```
  blackbox-exporter:
    image: prom/blackbox-exporter
    networks:
      - front_net
    ports:
      - '9115:9115'
```
- Копируем из документации пример конфига, подставляем наши ip и порты (`COMMENT_SERVICE_PORT 9292`, `POST_SERVICE_PORT 5000`)
`prometheus.yml`:
```
  - job_name: 'blackbox'
    metrics_path: /probe
    params:
      module: [http_2xx]  # Look for a HTTP 200 response.
    static_configs:
      - targets:
        - http://ui:9292/healthcheck    # Target to probe with http.
        - http://comment:9292/healthcheck
        - http://post:5000/healthcheck
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115  # The blackbox exporter's real hostname:port.
```

```
probe_http_status_code{instance="http://comment:9292/healthcheck",job="blackbox"} = 200
probe_http_status_code{instance="http://post:5000/healthcheck",job="blackbox"} = 200
probe_http_status_code{instance="http://ui:9292/healthcheck",job="blackbox"} = 200
```

### * Makefile

build - билдит все образы
build_ui, build_comment, build_post, build_prometheus, build_mongodb_exporter - билдит по отдельности
push - пушит все 
push_ui, push_comment, push_post, push_prometheus, push_mongodb_exporter - пушит по отдельности
restart - пересоздает сервисы
Без параметров все билдит, пушит и рестартит

Жаль не догадался сделать это задание в первую очередь, стало очень удобно


# Homework 23 Monitoring-2


- Готовим окружение
- Билдим образы сервисов
- Добавляем docker-compose-monitoring.yml, выносим туда мониторинговые сервисы, дополняем Makefile
- Добавляем cadvisor. Сервис в docker-compose-monitoring.yml, джоб в prometheus.yml, правило фаервола allow tcp:8080
- Добавляем Grafana. Сервис в docker-compose-monitoring.yml, правило фаервола allow tcp:3000. Настраиваем
- Настраиваем дашборд
- Добавляем rate для ui_request_count, `rate(ui_request_count[1m])`
- Добавляем comment_count. Сохраняем дашборды
- Настраиваем Alertmanager. Dockerfile (+ADD->COPY), docker-compose-monitoring.yml, config.yml, slack, Makefile, prometheus.yml allow tcp::9093
- Проверяем. Скриншот алерта в слаке будет в PR
- Docker hub: https://hub.docker.com/u/enot/ 

### * 

- Makefile дополнял по ходу основного задания

- Сбор Docker метрик 
Настраиваем по инструкции, но не совсем
На докер хосте добавляем демону настройку `/etc/docker/daemon.json`:
```
{
  "metrics-addr" : "0.0.0.0:9323",
  "experimental" : true
}
```
Не 127.0.0.1, а 0.0.0.0. Перезапускам демона
Можно задавать эти параметры для docker-machine при создании докер хоста:
`--engine-opt experimental --engine-opt metrics-addr=0.0.0.0:9323`
Открываем порт
Добавляем джоб в prometheus.yml:
```
  - job_name: 'docker'
    static_configs:
      - targets: ['172.18.0.1:9323']
```
В targes не localhost, а адрес бриджа
Пересобираем prometheus, перезапускаем, проверяем, что новый Target UP, смотрим новые метрики типа engine_daemon_

Перцентиль 95:
``` 
    - alert: UILatency
      expr: histogram_quantile(0.95, sum(rate(ui_request_latency_seconds_bucket[5m])) by (le)) > 0.01
      for: 1m
      labels:
        severity: critical
      annotations:
        description: '{{ $labels.instance }} of job {{ $labels.job }} has 95 percentile slow UI responces for more than 1 minute'
        summary: 'Instance {{ $labels.instance }} down'
```

- Отправка e-mail алертов
Оказыватся, GCE блокирует smtp (25, 465, 587), Google Compute Engine does not allow outbound connections on ports 25, 465, and 587
Но mail.ru позволяет обойти, принимает на порт 2525, для тестов так и сделаем

Про ** написано, что займет много времени, тогда может потом допишу  


# Homework 25 Logging-1

- Обновляем src
- Собираем образы приложений (+немного поправим Dockerfile)
- Сервисы для логирования: `docker-compose-logging.yml`
- Настраиваем fluentd
- `ConnectionError: HTTPConnectionPool(host='zipkin', port=9411)` - пора переходить к настройке zipkin. Пока только запускаем
- Смотрим Kibana


### * fluentd парсинг
Дополнительно парсим сообщения вида: 
`message: service=ui | event=request | path=/healthcheck | request_id=137f330f-c266-4b44-8561-822b22e6a08e | remote_addr=172.18.0.4 | method= GET | response_status=200`
`fluent.conf`:
```
<filter service.ui>
  @type parser
  format grok
  grok_pattern service=%{WORD:service} \| event=%{WORD:event} \| path=%{URIPATH:path} \| request_id=%{GREEDYDATA:request_id} \| remote_addr=%{IP:remote_addr} \| method=\s%{WORD:method} \| response_status=%{NUMBER:response_status}
  key_name message
</filter>
```

### * Zipkin трейсинг

Берем новый src, добавлям нужные ENV в докерфайлы
Тормозит здесь: `3.014s : /post/<id>`, потому что в `post_app.py` `find_post` есть `time.sleep(3)`
При этом в интерфейсе зипкина span 'db_find_single_post' не отображается, только уровем выше '/post/<id>'
Поменял `span_name` (на то же имя, что у функции), отображается
`@zipkin_span(service_name='post', span_name='db_find_single_post')` ->
`@zipkin_span(service_name='post', span_name='find_post')`


# Homework 27 Docker Swarm


- Основное задание по инструкции
- Логирование из прошлого ДЗ пока закомментил
- `post` без zipkin стартует, но не работает
- `node-exporter` перенес временно из `docker-compose-monitoring.yml` в `docker-compose.yml`


### Задание
1. Добавить в кластер еще 1 worker машину
- Done
2. Проследить какие контейнеры запустятся на ней
-  DEV_node-exporter
3. Увеличить число реплик микросервисов (3 - минимум)
- Done
4. Проследить какие контейнеры запустятся на новой машине. Сравнить с пунктом 2 
- Остался запущенным `DEV_node-exporter`
- Добавились `DEV_post.3`, `DEV_comment.3`, `DEV_ui.3`


### *
`node-exporter` запускается в `global mode`, должен быть запущен на каждой ноде, при появлении новой ноды запускатся там сразу
`post`, `comment`, `ui` запускаются в `replicated mode` с ограничением `node.role == worker`, распределяются равномерно только по воркерам. Когда нужно запустить дополнительные экземпляры, они запускаются в том воркере, где их еще нет


### Задание
Определить update_config для сервисов post и comment так, чтобы они обновлялись группами по 2 сервиса с разрывом в 10 секунд, а в случае неудач осуществлялся rollback.

post, comment:
```
      update_config:
        delay: 10s
        parallelism: 2
        failure_action: rollback
```


### Задание
Задать ограничения ресурсов для сервисов post и comment, ограничив каждое в 300 мегабайт памяти и в 30% процессорного времени. 
```
      resources:
        limits:
          cpus: '0.30'
          memory: 300M
```


### Задание
Задайте политику перезапуска для comment и post сервисов так, чтобы Swarm пытался перезапустить их при падении с ошибкой 10-15 раз с интервалом в 1 секунду. 
```
restart_policy: 
  condition: on-failure 
  max_attempts: 10
  delay: 1s
```


### Задание `docker-compose.monitoring.yml`
- Уже было сделано в ДЗ про мониторинг, только название не `docker-compose.monitoring.yml`, а `docker-compose-monitoring.yml`
- `node-exporter` убрал из `docker-compose.yml`, добавлял временно


### Задание *** Управление несколькими окружениями

- Новые параметры

Добавил только порты сервисов и количество реплик. В остальном явной необходимости пока не увидел, думаю, чем меньше различий между окружениями, тем лучше
```
PROMETHEUS_PORT
GRAFANA_PORT
CADVISOR_PORT
BLACKBOX_PORT
ALERTMANAGER_PORT
UI_REPLICAS
POST_REPLICAS
COMMENT_REPLICAS
```

- Окружения для примера два: DEV, PROD, соответственно файлы: `.env.dev`, `.env.prod` 

Передавать переменные в docker stack deploy можно, например, `cp .env.dev .env` перед `docker-compose`, но я пользовался тем, что в `docker-compose` можно передать переменые среды (в docker stack deploy - нельзя, https://docs.docker.com/compose/compose-file/#variable-substitution):
`docker stack deploy --compose-file=<(export $(cat .env.dev | xargs) && docker-compose -f docker-compose-monitoring.yml -f docker-compose.yml config 2>/dev/null)  DEV`
`docker stack deploy --compose-file=<(export $(cat .env.prod | xargs) && docker-compose -f docker-compose-monitoring.yml -f docker-compose.yml config 2>/dev/null)  PROD`

Получилось так:
```
ID                  NAME                     MODE                REPLICAS            IMAGE                           PORTS
0x21gtu0ozde        DEV_alertmanager         replicated          1/1                 enot/alertmanager:latest        *:9094->9093/tcp
rmkgoziae70f        DEV_blackbox-exporter    replicated          1/1                 prom/blackbox-exporter:latest   *:9116->9115/tcp
auko1uddq7q4        DEV_cadvisor             replicated          1/1                 google/cadvisor:v0.29.0         *:8181->8080/tcp
dagtphu5iyp6        DEV_comment              replicated          1/1                 enot/comment:latest             
63n2mcmlzlmz        DEV_grafana              replicated          1/1                 grafana/grafana:5.0.0           *:3001->3000/tcp
14b7guzquzd2        DEV_mongo-exporter       replicated          1/1                 enot/mongodb_exporter:latest    
dfypo8we52qb        DEV_node-exporter        global              4/4                 prom/node-exporter:v0.15.2      
90azkgqh0iac        DEV_post                 replicated          1/1                 enot/post:latest                
el24eeex1t8z        DEV_post_db              replicated          1/1                 mongo:3.2                       
upc0jh8e3c1m        DEV_prometheus           replicated          1/1                 enot/prometheus:latest          *:9191->9090/tcp
wnlgasuanwdm        DEV_ui                   replicated          1/1                 enot/ui:latest                  *:9292->9292/tcp
dfq6bc8220qv        PROD_alertmanager        replicated          1/1                 enot/alertmanager:latest        *:9093->9093/tcp
j1x790iqn5uu        PROD_blackbox-exporter   replicated          1/1                 prom/blackbox-exporter:latest   *:9115->9115/tcp
c9pciu8spmdc        PROD_cadvisor            replicated          1/1                 google/cadvisor:v0.29.0         *:8080->8080/tcp
ichfkah137z9        PROD_comment             replicated          3/3                 enot/comment:latest             
1kpiu5ocovgk        PROD_grafana             replicated          1/1                 grafana/grafana:5.0.0           *:3000->3000/tcp
ugcmefb0buyo        PROD_mongo-exporter      replicated          1/1                 enot/mongodb_exporter:latest    
wxh3v3bv2gx2        PROD_node-exporter       global              4/4                 prom/node-exporter:v0.15.2      
4z96f2sid6a8        PROD_post                replicated          3/3                 enot/post:latest                
yktau3d9cfhh        PROD_post_db             replicated          1/1                 mongo:3.2                       
j1dh8k83n7na        PROD_prometheus          replicated          1/1                 enot/prometheus:latest          *:9990->9090/tcp
mjfe4nditskf        PROD_ui                  replicated          3/3                 enot/ui:latest                  *:9293->9292/tcp
```

Сервисы доступны на dev и prod на 9292 и 9293


# HW 28 Kubernetes-1


Пройдено


```
NAME                                  READY     STATUS    RESTARTS   AGE
busybox-855686df5d-sk2q9              1/1       Running   0          11m
comment-deployment-6b897c4694-mx2sx   1/1       Running   0          1m
mongo-74cccfb8-rdg6m                  1/1       Running   0          1m
nginx-8586cf59-496tm                  1/1       Running   0          8m
post-deployment-cf4d48f44-47bgl       1/1       Running   0          1m
ui-deployment-7544646b88-jb7pd        1/1       Running   0          1m
```


### Kubernetes The Hard Way в виде Ansible-плейбуков 

Задача интересная, но не уверен, что правильно понял цель. Если просто автоматизировать The Hard Way в виде Ansible-плейбуков, то можно скопировать все в bash скрипт и запустить ансиблом, но проще без ансибла. Kubespray для автоматизации The Hard Way использовать не стал, там структура под универсальность, а у нас только gce и набор готовых команд.
Если бывает необходимость делать очень многонодовые кластеры, тогда есть смысл параметризовать количество нод. Так и сделал.
Inventory сначала использовал статический, скрипт при создании инстанса просто дописывал хост в нужную группу в inventory. Но как-то не очень заработал обход в цикле groups -> host_vars, перешел на dynamic inventory, там немного иначе, заработало. 

Smoke test проходит, промежуточные проверки тоже, все работает. 
Cleanup.yml чистит все, включая nginx rule для smoke test.
Есть нюанс, после создания инстанса ансибл очень долго не может получать его группу и следующий плейбук фейлится на попытке получить `"{{ groups['tag_worker'] }}"`. Пробовал sleep, но непонятно сколько ждать, на несколько минут оказалось недостаточно. Приходится сначала выполнять первую часть, до gce_provision включительно, через некоторое время остальное. Оставил пока так.

Еще можно добавить параметров (сети, адреса) и добавить идемпотентности, делать проверки при создании и удалении ресурсов.
Т.к. есть сомнения в сделанном, буду благодарен за комментарии


# Homework 29 Kubernetes-2


Пройдено по инструкции
Образы собраны со старыми версиями приложений, до зипкина
Конфигурация для развертывания Reddit приложения в kubernetes собрана в kubernetes/kube
Ссылка на веб-интерфейс: больше не работает
Скриншот в PR

Второй кластр развернут терраформом, скрипты здсь: kubernetes/terraform
YAML-манифесты для включения dashboard здесь: kubernetes/dashboard


# Homework 30 Kubernetes-3


Все пройдено по инструкции
На применение изменений иногда уходило до 10 минут
После применения network policy сами пересоздались все поды
При попытке удаления mongo получил:
`Error from server (NotFound): error when stopping "mongo-deployment.yml": deployments.extensions "mongo" not found'
Старый под так и остался висеть в Unknown
```
mongo-77dcb74cd5-mskwz     1/1       Running   0          6s
mongo-77dcb74cd5-tgr9d     1/1       Unknown   0          10m
```
73 слайд а gist `storageClassName:slow`, надо fast

### задание *
`$ kubectl get secret ui-ingress -n dev -o yaml` сохранено в `ui-ingress-secret.yml`

https://35.186.252.21/


# HW 31 kubernetes-4 

Пройдено основное задание и связка пайплайнов gitlab-ci *. Связал просто триггерами, после сборки релизов приложний триггер запускает деплой reddit
Не уверен правда, что правильно понял задание. Написано "запускался деплой уже новой версии приложения на production", как это сразу на production, так нельзя, сначала stage, потом по кнопке prod. Оставил в общем такой порядок 

Нод в кластер пришлось добавить до части gilab-ci, больше двух подов с приложениями запустить не получалось
