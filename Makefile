USER_NAME = enot
VERSION = latest

.PHONY: all \
        build build_app build_ui build_comment build_post build_prometheus build_mongodb_exporter build_alertmanager\
        push push_app push_ui push_comment push_post push_prometheus push_mongodb_exporter push_alertmanager\
        restart

all: build push restart
build: build_ui build_comment build_post build_prometheus build_mongodb_exporter build_alertmanager
build_ui:
	cd src/ui && bash docker_build.sh
build_comment:
	cd src/comment && bash docker_build.sh
build_post:
	cd src/post-py && bash docker_build.sh
build_prometheus:
	docker build -t $(USER_NAME)/prometheus:$(VERSION) monitoring/prometheus
build_mongodb_exporter:
	docker build -t $(USER_NAME)/mongodb_exporter:$(VERSION) monitoring/mongodb_exporter
build_alertmanager:
	docker build -t $(USER_NAME)/alertmanager:$(VERSION) monitoring/alertmanager

push: push_ui push_comment push_post push_prometheus push_mongodb_exporter push_alertmanager
push_ui:
	docker push $(USER_NAME)/ui:$(VERSION)
push_comment:
	docker push $(USER_NAME)/comment:$(VERSION)
push_post:
	docker push $(USER_NAME)/post:$(VERSION)
push_prometheus:
	docker push $(USER_NAME)/prometheus:$(VERSION)
push_mongodb_exporter:
	docker push $(USER_NAME)/mongodb_exporter:$(VERSION)
push_alertmanager:
	docker push $(USER_NAME)/alertmanager:$(VERSION)

restart:
	cd docker && docker-compose -f docker-compose.yml -f docker-compose-logging.yml down \
        && docker-compose -f docker-compose.yml -f docker-compose-logging.yml up -d
restart_app:
	cd docker && docker-compose down && docker-compose up -d
restart_monitoring:
	cd docker && docker-compose -f docker-compose.yml -f docker-compose-monitoring.yml down \
	&& docker-compose -f docker-compose.yml -f docker-compose-monitoring.yml up -d
restart_logging:
	cd docker && docker-compose -f docker-compose-logging.yml down \
	&& docker-compose -f docker-compose-logging.yml up -d
