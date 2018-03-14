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
