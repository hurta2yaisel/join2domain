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

echo_info()
{
    echo -e "\e[1;36m$1\e[0m" && sleep 1
}

echo_info """
########################################################################
# join2domain.sh                                                       #
#                                                                      #
# Copyright 2015-2017 Yaisel Hurtado González <yaiselhg@uci.cu>        #
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
    echo -e "\e[1;31m$1\e[0m"
    if [ "$2" != "" ]; then
        exit $2
    fi
    exit 1
}

if [ $EUID -ne 0 ];then
    echo_error "$USER, you must be root!"
fi

if [ -f "/etc/debian_version" -a -f "/etc/lsb-release" ]; then
    LINUX_VERSION=$(grep "^DISTRIB_ID=" /etc/lsb-release | cut -d '=' -f2 | sed 's/"//g')
    OS_VERSION=$(grep "^DISTRIB_RELEASE=" /etc/lsb-release | cut -d '=' -f2)
    OS_FULLNAME=$(grep "^DISTRIB_DESCRIPTION=" /etc/lsb-release | cut -d '=' -f2 | sed 's/"//g')
elif [ -f "/etc/debian_version" ]; then
    OS_VERSION=$(cat /etc/debian_version)
    OS_FULLNAME="Debian ${OS_VERSION}"
    LINUX_VERSION="Debian"
elif [ -f "/etc/redhat-release" ]; then
    FIND=$(grep "CentOS" /etc/redhat-release)
    if [ ! "${FIND}" = "" ]; then
        OS_FULLNAME=$(grep "CentOS" /etc/redhat-release)
        LINUX_VERSION="CentOS"
        OS_VERSION="$OS_FULLNAME"
        for osv in $OS_FULLNAME; do
            if [[ $osv =~ [0-9] ]]; then
                OS_VERSION=$osv
                break
            fi
    done
    fi
fi

MAJOR_VERSION=$(echo $OS_VERSION | cut -d "." -f1)
ASK_USER=0
if [ "${LINUX_VERSION,,}" = "debian" ]; then
    case $MAJOR_VERSION in
        8)
            ASK_USER=1
            ;;
        *)
            ;;
    esac
elif [ "${LINUX_VERSION,,}" = "kali" ]; then
    case $MAJOR_VERSION in
        2)
            ASK_USER=1
            ;;
        *)
            ;;
    esac
elif [ "${LINUX_VERSION,,}" = "ubuntu" ]; then
    case $MAJOR_VERSION in
        14|15|16)
            ASK_USER=1
            ;;
        *)
            ;;
    esac
elif [ "${LINUX_VERSION,,}" = "linuxmint" ]; then
    case $MAJOR_VERSION in
        17|18)
            ASK_USER=1
            ;;
        *)
            ;;
    esac
elif [ "${LINUX_VERSION,,}" = "nova" ]; then
    case $MAJOR_VERSION in
        5)
            ASK_USER=1
            ;;
        *)
            ;;
    esac
elif [ "${LINUX_VERSION,,}" = "centos" ]; then
    case $MAJOR_VERSION in
        7)
            ASK_USER=1
            ;;
        *)
            ;;
    esac
else
        echo_error "Sorry but $OS_FULLNAME is a linux distribution not supported by join2domain!"
fi

echo_warn()
{
    echo -e "\e[1;33m$1\e[0m" && sleep 1
}

echo_prompt()
{
    echo -e "\e[1;35m$1\e[0m"
}

readopt()
{
    prompt=$(echo_prompt "$1 [$2]: ")
    if [ $# -gt 2 ]; then
        prompt=$(echo_prompt "$1 ($3)[$2]: ")
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

if [ $ASK_USER -eq 0 ]; then
    GO_AHEAD=$(readopt "$OS_FULLNAME is a version of $LINUX_VERSION not supported by join2domain. Do you want to continue?" "n")
    case ${GO_AHEAD,,} in
        y|s|yes|si)
            ;;
        *)
            echo_error "Bye bye!"
            ;;
    esac
fi

echo_section()
{
    echo -e "\e[1;34m* $1\e[0m" && sleep 1
}

echo_section "Getting some important informations before you begin..."

get_domain()
{
    __DOMAIN=$(egrep "^(search|domain)" /etc/resolv.conf | line | awk '{print $2}')
    if [ "$__DOMAIN" = "" ]; then
        __DOMAIN=$(hostname -d || echo "uci.cu")
    fi
    echo $__DOMAIN
}

DOMAIN=$(readopt "Domain name" "$(get_domain)")
if host "$(hostname).${DOMAIN,,}" > /dev/null; then
    GO_AHEAD=$(readopt "$(hostname).${DOMAIN,,} is already registered in your DNS server! Do you want to continue?" "n")
    case ${GO_AHEAD,,} in
        y|s|yes|si)
            ;;
        *)
            echo_error "Bye bye!"
            ;;
    esac
fi
WORKGROUP=$(workgroup=$(echo ${DOMAIN,,} | cut -d "." -f1); echo ${workgroup^^})

get_kdcs()
{
    __DCSERVERS=""
    __DCS=$(for li in $(host ${DOMAIN,,} | grep address | awk '{print $4}'); \
    do echo $li; done | sort)
    for __dc in $__DCS; do
        if host $__dc > /dev/null; then
            __ndc=$(host $__dc | awk '{print $5}')
            if [ "${__ndc: -1}" = "." ]; then
                __ndc=$(echo $__ndc | sed 's/.$//g')
            fi
            __DCSERVERS="$__DCSERVERS $__ndc"
        fi
    done
    echo $__DCSERVERS
}

KDCS=$(readopt "Kerberos servers" "$(get_kdcs)")
ADMIN_KDC=$(readopt "Admin Kerberos server" "$(echo $KDCS | cut -d ' ' -f1)")
NTP_SERVER=$(readopt "NTP Server" "${DOMAIN,,}")
USER_DOMAIN=$(readopt "Domain User" "${USER,,}")
AUTHORIZED_ACCESS=$(readopt "Authorized Users and Groups" \
"domain admins,sec-${WORKGROUP,,}-security,${USER_DOMAIN}")

if [ "$AUTHORIZED_ACCESS" != "" ]; then
    __ALIAS="$AUTHORIZED_ACCESS"
    AUTHORIZED_ACCESS="=${AUTHORIZED_ACCESS}"
fi

if [[ "${LINUX_VERSION,,}" == "centos" ]]; then
    DEPS="authconfig samba samba-winbind samba-winbind-clients pam_krb5 oddjob oddjob-mkhomedir ntpdate"
    YUMBIN=$(which yum)
    YUMOPTS="-y -q"
    if  ! test -x "$YUMBIN"; then
        echo_error "Sorry but without yum we can do nothing!"
    fi
    echo_section "Installing dependencies..."
    $YUMBIN $YUMOPTS update  > /dev/null
    $YUMBIN $YUMOPTS install $DEPS || echo_error "Sorry but if we can't install the dependencies we can do nothing!" $?
else
    DEPS="ntpdate samba smbclient samba-common winbind krb5-user libpam-krb5 \
    libpam-winbind libnss-winbind sudo"

    APTBIN=$(which aptitude)
    APTOPTS="--allow-untrusted -y -q"
    if  ! test -x "$APTBIN"; then
        APTBIN=$(which apt || which apt-get)
        if test -x "$APTBIN"; then
            APTOPTS="--auto-remove --allow-unauthenticated -y -q"
            else
                echo_error "Sorry but without aptitude, apt or apt-get we can do nothing!"
        fi
    fi

    echo_section "Installing dependencies..."
    $APTBIN update > /dev/null
    $APTBIN $APTOPTS install $DEPS || echo_error "Sorry but if we can't install the dependencies we can do nothing!" $?
fi

echo_section "Synchronizing date and time via NTP..."
ntpdate -u $NTP_SERVER > /dev/null && hwclock --systohc

if [[ "${LINUX_VERSION,,}" == "centos" ]]; then
    WIN_FILE=/etc/security/pam_winbind.conf
    echo_section "Making backups of some files..."
    cp $WIN_FILE $HOME/$(basename $WIN_FILE).$$.bak

    echo_section "Enabling automatic beginning of oddjob, samba y winbind..."
    if test -x "$(which systemctl)"; then
        systemctl enable oddjobd; systemctl start oddjobd
        systemctl enable smb; systemctl start smb
        systemctl enable winbind; systemctl start winbind
    else
        chkconfig oddjobd on; systemctl start oddjobd
        chkconfig smb on; systemctl start smb
        chkconfig winbind on; systemctl start winbind
    fi

    echo_section "Setting up pam, kerberos, samba, nsswitch y winbind..."

    grep -rl pam_mkhomedir.so /etc/pam.d/ | xargs sed -i 's/pam_mkhomedir.so/pam_oddjob_mkhomedir.so/g'

    authconfig --disablekrb5 --enablewinbind --enablewinbindauth \
    --smbsecurity=ads --smbrealm=${DOMAIN^^} --smbworkgroup=${WORKGROUP^^} \
    --smbservers="${KDCS,,}" \
    --winbindtemplatehomedir=/home/%U --winbindtemplateshell=/bin/bash \
    --enablemkhomedir --enablewinbindusedefaultdomain --update

    cat > $WIN_FILE <<EOF
[global]
cached_login = yes
require_membership_of = ${__ALIAS}
mkhomedir = yes
EOF
else
KRB_FILE=/etc/krb5.conf
SMB_FILE=/etc/samba/smb.conf
WIN_FILE=/usr/share/pam-configs/winbind
NSS_FILE=/etc/nsswitch.conf
WIN_INIT=/etc/init.d/winbind
SMB_INIT=/etc/init.d/smbd
SUD_FILE=/etc/sudoers.d/10_admins

echo_section "Making backups of some files..."
cp $KRB_FILE{,$$.bak}
cp $SMB_FILE{,$$.bak}
cp $WIN_FILE $HOME/$(basename $WIN_FILE).$$.bak

echo_section "Setting up kerberos..."
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

echo_section "Setting up samba..."
cat > $SMB_FILE <<EOF
[global]
    workgroup = ${WORKGROUP^^}
    security = ads
    realm = ${DOMAIN^^}
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
    valid users = ${USER_DOMAIN,,}
EOF

echo_section "Setting up nsswitch..."
PASSWD=$(grep -i "winbind" $NSS_FILE | egrep ^passwd | wc -l)
if [ $PASSWD -eq 0 ]; then
    sed -i '/^passwd/s/compat/compat winbind/g' $NSS_FILE
fi
GROUP=$(grep -i "winbind" $NSS_FILE | egrep ^group | wc -l)
if [ $GROUP -eq 0 ]; then
    sed -i '/^group/s/compat/compat winbind/g' $NSS_FILE
fi

echo_section "Setting up winbind..."
cat > $WIN_FILE <<EOF
Name: Winbind NT/Active Directory authentication
Default: yes
Priority: 192
Auth-Type: Primary
Auth:
    [success=end default=ignore]    pam_winbind.so krb5_auth krb5_ccache_type=FILE cached_login [require_membership_of$AUTHORIZED_ACCESS] try_first_pass
Auth-Initial:
    [success=end default=ignore]    pam_winbind.so krb5_auth krb5_ccache_type=FILE cached_login [require_membership_of$AUTHORIZED_ACCESS]
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
if [ -d  /usr/share/lightdm/lightdm.conf.d ]; then
    echo_section "Setting up lightdm..."
    for dd in $(ls /usr/share/lightdm/lightdm.conf.d | line); do
        cat >> /usr/share/lightdm/lightdm.conf.d/$dd <<EOF
greeter-show-manual-login=true
EOF
    done
fi
echo_section "Enabling automatic beginning of winbind..."
SMBD=$(grep -i "smbd" $WIN_INIT | egrep "^# Should-Start" | wc -l)
if [ $SMBD -eq 0 ]; then
    sed -i '/^# Should-Start/s/samba/smbd/g' $WIN_INIT
fi
if test -x "$(which update-rc.d)"; then
    update-rc.d -f winbind remove > /dev/null
    update-rc.d winbind defaults > /dev/null
fi
if test -x "$(which insserv)"; then
    insserv -r winbind > /dev/null
    insserv winbind > /dev/null
fi
SYSTEMCTL_CMD=1
if test -x "$(which systemctl)"; then
    systemctl disable winbind > /dev/null
    systemctl enable winbind > /dev/null
    SYSTEMCTL_CMD=0
fi


echo_section "Dissabling Kerberos authentication..."
pam-auth-update --remove krb5 --force
reset_services()
{
    ALL_SERVICES=true
    [ "$1" = "smbd" ] && ALL_SERVICES=false
    if [ $SYSTEMCTL_CMD -eq 0 ]; then
        systemctl restart smbd > /dev/null
        $ALL_SERVICES && systemctl restart winbind > /dev/null
    elif test -x "$(which service)"; then
        service smbd restart > /dev/null
        $ALL_SERVICES && service winbind restart > /dev/null
    else
        $SMB_INIT restart > /dev/null
        $ALL_SERVICES && $WIN_INIT restart > /dev/null
    fi
    $ALL_SERVICES && sleep 5
}

reset_services smbd
fi

echo_section "Joining this machine to ${DOMAIN^^}..."

join_pc(){
    net ads join -U $USER_DOMAIN || echo_error "If previous errors said \
    something like -> Failed to set account flags for machine account \
    (NT_STATUS_ACCESS_DENIED) <- please, pick a diferent name for your \
    machine a tray again!" $?
    return 0
}
JOINED=1
if [[ "${LINUX_VERSION}" == "centos" ]]; then
    join_pc && id $USER_DOMAIN > /dev/null && JOINED=0
else
    join_pc && reset_services && id $USER_DOMAIN > /dev/null && JOINED=0
fi

if [ $JOINED -eq 0 ]; then
    echo_section "Setting up sudoers file..."
    ALIAS=""
    OLD_IFS="$IFS"
    IFS=','
    for acc in $__ALIAS; do
        acc="${acc##*( )}"
        acc="${acc%%*( )}"
        if wbinfo -g | grep "^$acc$" > /dev/null; then
            if [ "$ALIAS" != "" ]; then
                ALIAS="$ALIAS, %$acc"
            else
                ALIAS="%$acc"
            fi
        elif wbinfo -u | grep "^$acc$" > /dev/null; then
            if [ "$ALIAS" != "" ]; then
                ALIAS="$ALIAS, $acc"
            else
                ALIAS="$acc"
            fi
        fi
    done
    IFS="$OLD_IFS"
    cat > $SUD_FILE <<EOF
User_Alias ADMIN_GROUP="$ALIAS"
ADMIN_GROUP ALL=(ALL:ALL) ALL
EOF
    chmod 0440 $SUD_FILE
    adduser $USER_DOMAIN sudo > /dev/null
    echo_info "$(net ads testjoin). Enjoy it!!!"
    exit 0
fi
echo_error "The join to the domain ${DOMAIN^^} failed!!!"
