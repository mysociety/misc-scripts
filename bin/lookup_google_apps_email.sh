#!/bin/bash

PYTHON=$(which python)
if [ -e /opt/virtualenvs/google_legacy_oauth ]; then
    PYTHON="/opt/virtualenvs/google_legacy_oauth/.venv/bin/python"
fi

$PYTHON /data/mysociety/bin/lookup_google_apps_email.py $1
