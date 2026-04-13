IMAGE_NAME := homebrew/brew
CONTAINER_NAME := dotfiles-test-container
PROJECT_DIR := $(shell pwd)

.PHONY: build run shell bootstrap logs stop rm clean

run:
	docker run --rm -it \
  	--name $(CONTAINER_NAME) \
    -v $(PROJECT_DIR):/home/dev/repo \
    -w /home/dev/repo \
    $(IMAGE_NAME) \
    /bin/bash

shell:
	@if [ -z "$$(docker ps -q -f name=$(CONTAINER_NAME))" ]; then \
        if [ -n "$$(docker ps -aq -f name=$(CONTAINER_NAME))" ]; then \
            echo "Container $(CONTAINER_NAME) exists but is stopped, starting..."; \
            docker start $(CONTAINER_NAME) >/dev/null; \
        else \
            echo "Starting new container $(CONTAINER_NAME)..."; \
            docker run -d \
                --name $(CONTAINER_NAME) \
                -v $(PROJECT_DIR):/home/dev/repo \
                -w /home/dev/repo \
                $(IMAGE_NAME) \
                tail -f /dev/null >/dev/null; \
        fi; \
    else \
        echo "Container $(CONTAINER_NAME) is already running."; \
    fi

brew-version: shell
	docker exec -it $(CONTAINER_NAME) /bin/bash -lc "brew --version"

bootstrap: shell
	docker exec -it $(CONTAINER_NAME) /bin/bash -lc "./bootstrap.sh $(ARGS)"

bash: shell
	docker exec -it $(CONTAINER_NAME) /bin/bash

zsh: shell
	docker exec -it $(CONTAINER_NAME) /home/linuxbrew/.linuxbrew/bin/zsh

logs:
	docker logs -f $(CONTAINER_NAME)

stop:
	- docker stop $(CONTAINER_NAME) || true

rm: stop
	- docker rm $(CONTAINER_NAME) || true

clean: rm
	@echo "Container opgeruimd. Image blijft bestaan (IMAGE_NAME=$(IMAGE_NAME))."
