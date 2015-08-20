#!/usr/bin/python
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
sys.path.insert(0, '/data/mysociety/lib/google')

from oauth2client.client import SignedJwtAssertionCredentials
from apiclient.discovery import build
from apiclient import errors
from httplib2 import Http


client_id = '975835307765-3kutvru2fg13jvjj38mrst5r0iilt9od@developer.gserviceaccount.com'
sub_user = 'api-target-user@mysociety.org'
api_key_file = '/etc/mysociety/google_apps_api_key.p12'


def lookup_user( addr ):
    "Look up a user by one of its email addresses."

    credentials = SignedJwtAssertionCredentials(client_id, private_key,
        'https://www.googleapis.com/auth/admin.directory.user.readonly',
        sub=sub_user)

    http_auth = credentials.authorize(Http())
    useradmin = build('admin', 'directory_v1', http=http_auth)

    try:
        response = useradmin.users().get(userKey=addr).execute()
    except errors.HttpError:
        return False

    return True


def lookup_group( addr ):
    "Look up a group by one of its email addresses."

    credentials = SignedJwtAssertionCredentials(client_id, private_key,
        'https://www.googleapis.com/auth/admin.directory.group.readonly',
        sub=sub_user)

    http_auth = credentials.authorize(Http())
    groupadmin = build('admin', 'directory_v1', http=http_auth)

    try:
        response = groupadmin.groups().get(groupKey=addr).execute()
    except errors.HttpError:
        return False

    return True


if len(sys.argv) != 2:
    sys.stderr.write('usage: %s <address to look up>\n' % sys.argv[0])
    sys.stderr.write('       Try to find an email address in our Google Apps account.\n')
    exit(1)

### Read private key
with open(api_key_file) as f:
    private_key = f.read()

### Test lookup on known address; if this fails, the API isn't working.
### We get a 403 both for failed calls and for unknown users >:-|
if not lookup_user(sub_user):
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
