DOCKER_IMAGE_NAME = claude-prison-env
DOCKER_CONTAINER_NAME = claude-prison-session
BIN_DIR ?= ~/.local/bin

.PHONY: build build-with-skills run stop shell restart clean logs status cgym

cgym:
	cd claude-gym && go build -o cgym .

build: cgym
	docker build -t $(DOCKER_IMAGE_NAME) .

# Build with all skills: make build-with-skills
# Build with specific skills: make build-with-skills SKILLS="webapp-testing"
build-with-skills: cgym
	@echo ">> Checking for ~/.claude/skills for dependencies..."
	@if [ -d "$$HOME/.claude/skills" ]; then \
		echo ">> Found skills directory. Syncing to temporary build context..."; \
		mkdir -p .tmp-skills && cp -r "$$HOME/.claude/skills/"* .tmp-skills/ || true; \
	else \
		echo ">> Warning: ~/.claude/skills not found. No dependencies will be installed."; \
		mkdir -p .tmp-skills; \
	fi
	@echo ">> Building Docker image..."
	@docker build --build-arg INSTALL_SKILLS="$(or $(SKILLS),all)" -t $(DOCKER_IMAGE_NAME) . || (rm -rf .tmp-skills; exit 1)
	@rm -rf .tmp-skills
	@echo ">> Build complete and temporary files cleaned up."

run:
	./clp

stop:
	docker stop $(DOCKER_CONTAINER_NAME) || true
	docker rm $(DOCKER_CONTAINER_NAME) || true

shell:
	docker exec -it $(DOCKER_CONTAINER_NAME) bash

restart: stop run

clean: stop
	docker rmi $(DOCKER_IMAGE_NAME) || true

logs:
	docker logs -f $(DOCKER_CONTAINER_NAME)

status:
	@docker ps -a --filter name=$(DOCKER_CONTAINER_NAME)

install:
	chmod +x install.sh
	./install.sh "$(BIN_DIR)"

config:
	@echo ">> You can configure the installation directory (default: ~/.local/bin) by running:"
	@echo "   make install BIN_DIR=/your/custom/path"
	@echo ">> If 'clp' is not found after install, add the install directory to your PATH:"
	@echo '   export PATH="$$HOME/.local/bin:$$PATH"'
