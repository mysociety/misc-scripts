#!/usr/bin/env python
#
# Check if an email address exists in our Google Apps domain.
#
# Returns 0 if address exists
#         1 if address does not exist
#         2 if uncertain (e.g. API doesn't work)
#
# Ian Chard  20/8/2015
#

import sys
from googleapiclient.discovery import build
from googleapiclient import errors
from google.oauth2.service_account import Credentials

SERVICE_ACCOUNT_FILE = '/etc/mysociety/google_apps_api_key.json'
DELEGATE_USER = 'api-target-user@mysociety.org'

def lookup_user( addr ):
    "Look up a user by one of its email addresses."

    credentials = Credentials.from_service_account_file(
        SERVICE_ACCOUNT_FILE,
        scopes=['https://www.googleapis.com/auth/admin.directory.user.readonly'],
        subject=DELEGATE_USER)

    useradmin = build('admin', 'directory_v1', credentials=credentials)

    try:
        response = useradmin.users().get(userKey=addr).execute()
    except errors.HttpError:
        return False

    return True


def lookup_group( addr ):
    "Look up a group by one of its email addresses."

    credentials = Credentials.from_service_account_file(
        SERVICE_ACCOUNT_FILE,
        scopes=['https://www.googleapis.com/auth/admin.directory.group.readonly'],
        subject=DELEGATE_USER)

    groupadmin = build('admin', 'directory_v1', credentials=credentials)

    try:
        response = groupadmin.groups().get(groupKey=addr).execute()
    except errors.HttpError:
        return False

    return True


if len(sys.argv) != 2:
    sys.stderr.write('usage: %s <address to look up>\n' % sys.argv[0])
    sys.stderr.write('       Try to find an email address in our Google Apps account.\n')
    exit(1)

### Test lookup on known address; if this fails, the API isn't working.
### We get a 403 both for failed calls and for unknown users >:-|
if not lookup_user(DELEGATE_USER):
    sys.stderr.write("%s: API not working\n" % sys.argv[0])
    exit(2)

### Try address as a user's email address.
if lookup_user(sys.argv[1]):
    exit(0)

### Try address as a group address.
if lookup_group(sys.argv[1]):
    exit(0)

### Bah, nothing found.
exit(1)
