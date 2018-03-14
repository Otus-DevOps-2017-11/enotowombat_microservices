USER_NAME = enot
VERSION = latest

.PHONY: all \
        build build_ui build_comment build_post build_prometheus build_mongodb_exporter \
        push push_ui push_comment push_post push_prometheus push_mongodb_exporter \

all: build push restart

build: build_ui build_comment build_post build_prometheus build_mongodb_exporter

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

push: push_ui push_comment push_post push_prometheus push_mongodb_exporter

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

restart:
	cd docker && docker-compose down && docker-compose up -d
