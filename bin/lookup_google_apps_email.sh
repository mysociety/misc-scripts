#!/bin/bash

if [ -e /opt/virtualenvs/google_legacy_oauth ]; then
    . /opt/virtualenvs/google_legacy_oauth/.venv/bin/activate
fi

/data/mysociety/bin/lookup_google_apps_email.py $1

