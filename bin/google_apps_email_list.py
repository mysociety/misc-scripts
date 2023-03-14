#!/usr/bin/env python
#
# Fetch list of email addresses in our Google Apps domain.

from collections import defaultdict
from googleapiclient.discovery import build
from google.oauth2.service_account import Credentials

SERVICE_ACCOUNT_FILE = '/etc/mysociety/google_apps_api_key.json'
DELEGATE_USER = 'api-target-user@mysociety.org'

credentials = Credentials.from_service_account_file(
        SERVICE_ACCOUNT_FILE,
        scopes=['https://www.googleapis.com/auth/admin.directory.user.readonly'],
        subject=DELEGATE_USER)

useradmin = build('admin', 'directory_v1', credentials=credentials)

print('<h2>Users</h2>')

sort_order = (
    '/Admins and super admins', '/Staff users', '/Non-staff users',
    '/Non-staff users/Former staff', '/Support mailboxes',
    '/Special-purpose mailboxes')


def sort_in_order(i):
    try:
        return sort_order.index(i)
    except:
        return float('inf')

response = useradmin.users().list(customer='my_customer').execute()
x = defaultdict(list)
[x[r['orgUnitPath']].append(r) for r in response['users']]
for unit in sorted(x, key=sort_in_order):
    print('<h3>%s</h3>' % unit)
    print('<ul>')
    for r in sorted(x[unit], key=lambda a: a['name']['fullName']):
        aliases = ' (' + ' '.join(r['aliases']) + ')' if r.get('aliases') else ''
        print('<li>%s %s%s' % (r['name']['fullName'], r['primaryEmail'], aliases))
    print('</ul>')

credentials = Credentials.from_service_account_file(
        SERVICE_ACCOUNT_FILE,
        scopes=['https://www.googleapis.com/auth/admin.directory.group.readonly'],
        subject=DELEGATE_USER)

groupadmin = build('admin', 'directory_v1', credentials=credentials)

print('<h2>Groups</h2>')

GROUPS_URL = 'https://groups.google.com/a/mysociety.org/forum/#!forum/%s'

response = groupadmin.groups().list(domain='mysociety.org').execute()
for r in response['groups']:
    email = r['email'].replace('@mysociety.org', '')
    url = GROUPS_URL % email
    print('<h3>%s (<a target="_top" href="%s">%s</a>)</h3>' % (r['name'], url, email))
    if r.get('aliases'):
        print('<p>Aliases: %s</p>' % ', '.join(r['aliases']))
    if email in ('mysociety-community', 'fixmystreet', 'theyworkforyou'):
        continue
    members = groupadmin.members().list(groupKey=r['id']).execute()
    print('<ul>')
    for member in members.get('members', []):
        role = '(Owner)' if member['role'] == 'OWNER' else ''
        typ = '(Group)' if member['type'] == 'GROUP' else ''
        print('<li>%s %s %s</li>' % (member['email'], role, typ))
    print('</ul>')
