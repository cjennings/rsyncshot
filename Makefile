# rsyncshot - backup with bash, cron, rsync, and hard links
install:
	sudo ./rsyncshot setup
	@echo Installing rsyncshot complete.

uninstall:
	sudo rm -f /usr/local/bin/rsyncshot
	sudo rm -rf /etc/rsyncshot

