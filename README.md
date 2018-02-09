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

