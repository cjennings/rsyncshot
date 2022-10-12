# rsyncshot - backup with cron, rsync, and hardlinks
install:
	sudo ./rsyncshot setup
	@echo Installing rsyncshot complete.

uninstall:
	sudo rm -f /usr/local/bin/rsyncshot
	sudo rm -rf /etc/rsyncshot
	sudo rm -rf /var/log/rsyncshot.log
