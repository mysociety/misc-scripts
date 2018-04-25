#!/bin/bash

# This isn't perfect, but it at least captures some of the needed steps
# to prepare a new Bytemark physical server.
#
# Check out https://wiki.mysociety.org/wiki/Provisioning for more info.

my_hostname=$1
short_hostname=$( hostname -s )

if [ "$my_hostname" != "$short_hostname" ]; then
  echo "Check Hostname! Usage: $0 short-hostname"
  exit 1
fi

echo "Setting static hostname to $my_hostname"
hostnamectl --static set-hostname $my_hostname
hostnamectl
echo

echo "Installing required packages"
apt-get install -y emacs-nox wget lsb-release git make gcc man less >/dev/null
echo

echo "Setting DNS search Path"
sed -i -e 's/domain.*/search ukcod\.org\.uk/' /etc/resolv.conf
cat /etc/resolv.conf
echo

echo "Prefer IPv4"
echo 'precedence ::ffff:0:0/96  100' >> /etc/gai.conf
tail /etc/gai.conf
echo

echo "Generating root SSH key"
/usr/bin/ssh-keygen -q -t rsa -f ~/.ssh/id_rsa -N ''
cat ~/.ssh/id_rsa.pub
echo

echo "Installing Puppet"
wget https://apt.puppetlabs.com/puppetlabs-release-pc1-$(lsb_release -c | awk '{print $NF}').deb
dpkg -i puppetlabs-release-pc1-$(lsb_release -c | awk '{print $NF}').deb
apt-get update
apt-get install -y puppet-agent >/dev/null
echo

echo "Done"
