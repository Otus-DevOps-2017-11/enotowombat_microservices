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

