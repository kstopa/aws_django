#!/bin/bash

# Install packages
sudo apt-get update
sudo apt-get -y -qq install fail2ban git rdiff-backup libpq-dev uwsgi uwsgi-plugin-python3 nginx python3-pip python3-venv postgresql-client
