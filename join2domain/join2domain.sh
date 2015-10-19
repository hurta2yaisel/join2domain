#!/bin/bash
#
# join2domain.sh
#
# Copyright 2015 Yaisel Hurtado González <yaiselhg@uci.cu>
#
# This program sdis free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1301, USA.
#
#
clear

echo_warn()
{
    echo -e "\e[1;33m$1\e[0m" && sleep 1
}

echo_warn """
########################################################################
# join2domain.sh                                                       #
#                                                                      #
# Copyright 2015 Yaisel Hurtado González <yaiselhg@uci.cu>             #
#                                                                      #
# This program is free software; you can redistribute it and/or modify #
# it under the terms of the GNU General Public License as published by #
# the Free Software Foundation; either version 2 of the License, or    #
# (at your option) any later version.                                  #
#                                                                      #
# This program is distributed in the hope that it will be useful,      #
# but WITHOUT ANY WARRANTY; without even the implied warranty of       #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the        #
# GNU General Public License for more details.                         #
#                                                                      #
# You should have received a copy of the GNU General Public License    #
# along with this program; if not, write to the Free Software          #
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,           #
# MA 02110-1301, USA.                                                  #
########################################################################"""

echo_error()
{
    echo -e "\e[1;31m$1\e[0m" && sleep 1
}

if ! host $(hostname -f) > /dev/null; then
    if [ $EUID -ne 0 ];then
        echo_error "$USER, you must be root :-/!!!"
        exit 1
    fi
    else
        echo_error "$(hostname -f) is already registred in your DNS server!!!"
        exit $?
fi

echo_info()
{
    echo -e "\e[1;34m$1\e[0m" && sleep 1
}

echo_info "Getting some important information..."

readopt()
{
    prompt="$1 [$2]: "
    if [ $# -gt 2 ]; then
        prompt="$1 ($3)[$2]: "
    fi
    read -p "$prompt" tmp
    tmp=${tmp,,}
    case "x$tmp" in
    xn|xno)
        ;;
    x)
        echo "$2"
        ;;
    *)
        echo "$tmp"
        ;;
    esac
}

get_domain()
{
    egrep "^(search|domain)" /etc/resolv.conf | line | awk '{print $2}' \
    || hostname -d || echo "uci.cu"
}

DOMAIN=$(readopt "Domain name" "$(get_domain)")
WORKGROUP=$(workgroup=$(echo ${DOMAIN,,} | cut -d "." -f1); echo ${workgroup^^})

get_kdcs()
{
    __DCSERVERS=""
    __DCS=$(for li in $(host ${DOMAIN,,} | grep address | awk '{print $4}'); \
    do echo $li; done | sort)
    for __dc in $__DCS; do
        if host $__dc > /dev/null; then
            __ndc=$(host $__dc | awk '{len=length($5);print substr($5,0,len-1)}')
            __DCSERVERS="$__DCSERVERS $__ndc"
        fi
    done
    echo $__DCSERVERS
}

KDCS=$(readopt "Kerberos servers" "$(get_kdcs)")
ADMIN_KDC=$(readopt "Admin Kerberos server" "$(echo $KDCS | cut -d " " -f1)")
NTP_SERVER=$(readopt "NTP Server" "${DOMAIN,,}")
USER_DOMAIN=$(readopt "Domain User" "${USER,,}")
AUTHORIZED_ACCESS=$(readopt "Authorized Users and Groups" \
"domain admins,sec-uci-security,${USER_DOMAIN}")

DEPS="ntpdate samba smbclient samba-common winbind krb5-user libpam-krb5 \
libpam-winbind libnss-winbind"

APTBIN=$(which aptitude)
APTOPTS="--allow-untrusted -y -q"
if  ! test -x "$APTBIN"; then
    APTBIN=$(which apt-get)
    if test -x "$APTBIN"; then
        APTOPTS="--auto-remove --allow-unauthenticated -y -q"
        else
            exit 1
    fi
fi
$APTBIN update || exit 1
$APTBIN $APTOPTS install $DEPS || exit 1

ntpdate -u $NTP_SERVER && hwclock --systohc

KRB_FILE=/etc/krb5.conf
SMB_FILE=/etc/samba/smb.conf
WIN_FILE=/usr/share/pam-configs/winbind
NSS_FILE=/etc/nsswitch.conf
WIN_INIT=/etc/init.d/winbind
SMB_INIT=/etc/init.d/smbd
SUD_FILE=/etc/sudoers.d/10_admins

cp $KRB_FILE{,.bak}
cp $SMB_FILE{,.bak}
mkdir -p $HOME/backup
cp $WIN_FILE  $HOME/backup/winbind.bak

cat > $KRB_FILE <<EOF
[logging]
    default = FILE:/var/log/krb5libs.log
    kdc = FILE:/var/log/krb5kdc.log
    admin_server = FILE:/var/log/kadmind.log

[libdefaults]
    default_realm = ${DOMAIN^^}
    dns_lookup_realm = false
    dns_lookup_kdc = false
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true
    default_ccache_name = KEYRING:persistent:%{uid}

[realms]
    ${DOMAIN^^} = {
EOF

for kdc in $KDCS; do
    cat >> $KRB_FILE <<EOF
        kdc = ${kdc,,}
EOF
done

cat >> $KRB_FILE <<EOF
        admin_server = ${ADMIN_KDC,,}
    }

[domain_realm]
    .${DOMAIN,,} = ${DOMAIN^^}
    ${DOMAIN,,} = ${DOMAIN^^}
EOF

cat > $SMB_FILE <<EOF
[global]
    workgroup = ${WORKGROUP}
    security = ads
    realm = ${DOMAIN,,}
    password server = ${KDCS,,}
    kerberos method = secrets only
    domain logons = no
    template homedir = /home/%U
    template shell = /bin/bash
    winbind enum groups = yes
    winbind enum users = yes
    winbind use default domain = yes
    winbind offline logon = true
    domain master = no
    local master = no
    prefered master = no
    os level = 0
    idmap config *:backend = tdb
    idmap config *:range = 10000-20000
    idmap config ${WORKGROUP}:backend = rid
    idmap config ${WORKGROUP}:range=10000000-20000000
    server string = Welcome to %h server
    log file = /var/log/samba/log.%m
    max log size = 50

[homes]
    comment = Home Directories
    browseable = no
    writable = yes
;   valid users = %S
;   valid users = MYDOMAIN\%S
EOF

cat > $WIN_FILE <<EOF
Name: Winbind NT/Active Directory authentication
Default: yes
Priority: 192
Auth-Type: Primary
Auth:
    [success=end default=ignore]    pam_winbind.so krb5_auth krb5_ccache_type=FILE cached_login [require_membership_of=$AUTHORIZED_ACCESS] try_first_pass
Auth-Initial:
    [success=end default=ignore]    pam_winbind.so krb5_auth krb5_ccache_type=FILE cached_login [require_membership_of=$AUTHORIZED_ACCESS]
Account-Type: Primary
Account:
    [success=end new_authtok_reqd=done default=ignore]  pam_winbind.so
Password-Type: Primary
Password:
    [success=end default=ignore]    pam_winbind.so use_authtok try_first_pass
Password-Initial:
    [success=end default=ignore]    pam_winbind.so
Session-Type: Additional
Session:
    required    pam_mkhomedir.so umask=0022 skel=/etc/skel
    optional    pam_winbind.so
EOF

PASSWD=$(grep -i "winbind" $NSS_FILE | egrep ^passwd | wc -l)
if [ $PASSWD -eq 0 ]; then
    sed -i '/^passwd/s/compat/compat winbind/g' $NSS_FILE
fi
GROUP=$(grep -i "winbind" $NSS_FILE | egrep ^group | wc -l)
if [ $GROUP -eq 0 ]; then
    sed -i '/^group/s/compat/compat winbind/g' $NSS_FILE
fi

SMBD=$(grep -i "smbd" $WIN_INIT | egrep "^# Should-Start" | wc -l)
if [ $SMBD -eq 0 ]; then
    sed -i '/^# Should-Start/s/samba/smbd/g' $WIN_INIT
fi

pam-auth-update

update-rc.d winbind defaults
systemctl enable winbind > /dev/null

$WIN_INIT stop
$SMB_INIT restart
$WIN_INIT start

cat > $SUD_FILE <<EOF
User_Alias ADMIN_GROUP="$AUTHORIZED_ACCESS"
ADMIN_GROUP ALL=(ALL:ALL) ALL
EOF
chmod 0440 $SUD_FILE

net join -U $USER_DOMAIN
net ads testjoin && $WIN_INIT restart > /dev/null
adduser $USER_DOMAIN sudo > /dev/null
