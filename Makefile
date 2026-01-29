# rsyncshot - backup with bash, cron, rsync, and hard links

.PHONY: all help install uninstall test test-quick test-verbose lint check clean deps

all: help

help:
	@echo "Targets:"
	@echo "  install       Install rsyncshot and configure cron"
	@echo "  uninstall     Remove rsyncshot and config"
	@echo "  test          Run full test suite"
	@echo "  test-quick    Run quick tests (skip backup/cron)"
	@echo "  test-verbose  Run tests with verbose output"
	@echo "  lint          Run shellcheck on scripts"
	@echo "  check         Run lint and full test suite"
	@echo "  deps          Install dependencies"
	@echo "  clean         Remove test artifacts"

install:
	sudo ./rsyncshot setup

uninstall:
	sudo rm -f /usr/local/bin/rsyncshot
	sudo rm -rf /etc/rsyncshot

test:
	sudo ./tests/test_rsyncshot.sh

test-quick:
	sudo ./tests/test_rsyncshot.sh --quick

test-verbose:
	sudo ./tests/test_rsyncshot.sh --verbose

lint:
	shellcheck rsyncshot tests/*.sh tests/**/*.sh

check: lint test

deps:
	@echo "Installing dependencies..."
	@if [ "$$(uname)" = "Darwin" ]; then \
		brew install rsync shellcheck util-linux openssh; \
	elif command -v apt >/dev/null 2>&1; then \
		sudo apt update && sudo apt install -y rsync util-linux shellcheck openssh-client cron; \
	elif command -v dnf >/dev/null 2>&1; then \
		sudo dnf install -y rsync util-linux ShellCheck openssh-clients cronie; \
	elif command -v yum >/dev/null 2>&1; then \
		sudo yum install -y rsync util-linux ShellCheck openssh-clients cronie; \
	elif command -v pacman >/dev/null 2>&1; then \
		sudo pacman -S --noconfirm rsync util-linux shellcheck openssh cronie; \
	elif command -v zypper >/dev/null 2>&1; then \
		sudo zypper install -y rsync util-linux ShellCheck openssh cronie; \
	elif command -v apk >/dev/null 2>&1; then \
		sudo apk add rsync util-linux shellcheck openssh dcron; \
	else \
		echo "Unknown package manager. Please install manually: rsync, flock, shellcheck, ssh, cron"; \
		exit 1; \
	fi
	@echo "Dependencies installed."

clean:
	@echo "Nothing to clean"
