.PHONY: test build-web serve clean game db db-stop db-reset api api-build dev stop

GODOT := godot
BUILD_DIR := build
BROWSER := firefox

# ── Game ──

game:
	$(GODOT) --path .

test:
	$(GODOT) --headless -s addons/gut/gut_cmdln.gd

build-web:
	mkdir -p $(BUILD_DIR)
	$(GODOT) --headless --export-release "Web" $(BUILD_DIR)/index.html

serve: build-web
	$(BROWSER) http://localhost:8060 &
	python3 serve.py

clean:
	rm -rf $(BUILD_DIR)

# ── Database ──

db:
	docker compose up -d db
	@echo "Waiting for PostgreSQL..."
	@docker compose exec db sh -c 'until pg_isready -U tycoon -d consultancy_tycoon; do sleep 0.5; done' 2>/dev/null
	@echo "Database ready on localhost:5432"

db-stop:
	docker compose down

db-reset:
	docker compose down -v
	$(MAKE) db

# ── Backend API ──

api-build:
	cd backend && cargo build

api: db
	cd backend && cargo run

# ── Full dev stack ──

dev: db
	@echo "Starting API server in background..."
	cd backend && cargo run &
	@sleep 2
	@echo "Starting Godot..."
	$(GODOT) --path .

stop:
	-docker compose down
	-pkill -f consultancy-tycoon-api || true
