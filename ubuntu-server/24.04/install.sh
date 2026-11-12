#!/bin/bash
if [ $UID -ne 0 ]; then
    echo "Please rerun this script with elevated privileges" >&2
    exit 1
fi

# The local group name "staff" w/ GID 50 conflicts with the LDAP group
# named "staff" w/ GID 9100.
staff_gid=$(getent group staff | awk 'BEGIN{FS=":"} {print $3}')
if [ -n "$staff_gid" ] && [ $staff_gid -eq 50 ]; then
    groupdel staff
fi

umount /pf      >/dev/null 2>&1
umount /lustre2 >/dev/null 2>&1
umount /lustre1 >/dev/null 2>&1
umount /lustre0 >/dev/null 2>&1
umount /opt/dm  >/dev/null 2>&1
umount /dmOpt   >/dev/null 2>&1

set -ue
cfg_install() {
    if [ $# -ne 2 ]; then
	echo "usage: cfg_install <file_relpath> <permissions>" >&2
	return 1
    elif [ -z "$1" ]; then
	echo "ERROR: filepath arg is emptystring" >&2
	return 1
    elif [ -z "$2" ]; then
	echo "ERROR: permissions arg is emptystring" >&2
	return 1
    fi
    src=$1 # the relative path under git repo
    dst=/$1
    og=/$1.default
    permissions=$2
    if [ -f "$src" ]; then
	if [ -f "$dst" ]; then
	    cp -n "$dst" "$og"
	fi
	cp -f "$src" "$dst"
	chmod "$permissions" "$dst"
    fi
    echo "$dst updated (vanilla OS installation file located at $og)"
}
cfg_install etc/sssd/sssd.conf       0600
cfg_install etc/sudoers              0440
cfg_install etc/pam.d/common-auth    0644
cfg_install etc/pam.d/common-account 0644
cfg_install etc/pam.d/common-session 0644

# Mount special LS-CAT and APS shared filesystems, update fstab if successful.
<<<<<<< HEAD
LSCAT_NFS_OPTS='defaults,_netdev,x-systemd.mount-timeout=infinity,x-systemd.automount,noatime'
LSCAT_LUSTRE_OPTS='defaults,_netdev,x-systemd.requires=lnet.service,x-systemd.mount-timeout=infinity,x-systemd.automount,checksum,lruresize,lazystatfs,nouser_fid2path,verbose,noatime'
DM_NFS_OPTS='relatime,vers=4.2,namlen=255,rsize=524288,wsize=524288,hard,fatal_neterrors=none,proto=tcp,timeo=600,retrans=2,sec=sys,local_lock=none,x-systemd.mount-timeout=infinity,x-systemd.automount'
=======
LSCAT_NFS_OPTS='defaults,_netdev,nofail,noatime'
LSCAT_LUSTRE_OPTS='noatime,checksum,flock,lruresize,lazystatfs,nouser_fid2path,verbose,_netdev,nofail,x-systemd.requires=lnet.service'
DM_NFS_OPTS='relatime,vers=4.2,namlen=255,rsize=524288,wsize=524288,hard,proto=tcp,timeo=600,retrans=2,sec=sys,local_lock=none,_netdev,nofail'
>>>>>>> 021926c3aaf5d5a8df2f9225838c87cce98b2a0a

mkdir -p    /pf /lustre0 /lustre1 /lustre2 /opt/dm /dmOpt
chmod 1777  /pf /lustre0 /lustre1 /lustre2 /opt/dm /dmOpt
mount -t nfs -o ${LSCAT_NFS_OPTS},rw ldap1.ls-cat.net:/pf /pf

cp -n /etc/fstab /etc/fstab.default
grep -q "LS-CAT site-specific" /etc/fstab || cat <<EOF >> /etc/fstab

#
# LS-CAT site-specific mounts.
#

# Mount our NFS directory for general-purpose shared data where
# home dirs also reside. The obtuse name "/pf" was chosen to
# retain backward compatibility with long-standing hardcoded
# EPICS scripts.
ldap1.ls-cat.net:/pf /pf nfs ${LSCAT_NFS_OPTS},rw 0 0


#
# Mount the NFS directories
#
10.1.252.43:/eiger_temp  /eiger_temp_D  nfs4  rw,noatime,vers=4.2,hard,proto=tcp  0 0
10.1.252.42:/eiger_temp  /eiger_temp_F  nfs4  rw,noatime,vers=4.2,hard,proto=tcp  0 0

# Mount our two lustre filesystems.
#
# lustre2 is our lustre filesystem where legacy lsnode data is stored.
#
# lustre1 is our latest and greatest production env lustre filesystem.
#
# lustre0 is our old lustre filesystem where legacy lsnode data was
#   formerly stored.
#
#10.1.0.13@tcp:/bdfs /lustre2 lustre    ${LSCAT_LUSTRE_OPTS},rw 0 0
#10.1.0.11@tcp:/adfs /lustre1 lustre    ${LSCAT_LUSTRE_OPTS},rw 0 0
#10.1.252.229@tcp:/sffs /lustre0 lustre ${LSCAT_LUSTRE_OPTS},rw 0 0

#
# Mount the directories where APS "Data Management" utilities are located.
# The manual overrides for rsize and wsize were recommended by the APS
# from their own documentation on DM.
#
#s21dserv.ls.aps.anl.gov:/export/dm /opt/dm nfs4  ${DM_NFS_OPTS},ro 0 0
#catfiles.xray.aps.anl.gov:/dmOpt   /dmOpt  nfs4  ${DM_NFS_OPTS},ro 0 0

EOF

echo
echo "Finished installing config files for LDAP-based user authentication."
echo "Please run the following commands in order to allow this updated configuration to take effect:"
echo
echo "  systemctl daemon-reload"
echo "  systemctl disable --now nslcd"
echo "  systemctl disable --now nscd"
echo "  systemctl restart sssd"
echo "  sss_cache -E"
echo
echo "Once you have done that, please update /etc/ssh/sshd_config to listen only on localhost and" \
     "internal network addresses and then run the following commands to ensure that sshd honors" \
     "our config file:"
echo
echo "  systemctl disable --now ssh.sock && systemctl enable --now ssh.service"
echo "  systemctl restart ssh"
echo
echo
echo "If you wish to mount the APS Data Management NFS shares and LS-CAT's lustre filesystems," \
     "please install the Lustre client, then run the following commands with elevated privileges," \
     "and uncomment the corresponding lines in /etc/fstab."
echo
echo "  mount -t lustre -o ${LSCAT_LUSTRE_OPTS},rw 10.1.0.13@tcp:/bdfs /lustre2"
echo "  mount -t lustre -o ${LSCAT_LUSTRE_OPTS},rw 10.1.0.11@tcp:/adfs /lustre1"
echo "  mount -t lustre -o ${LSCAT_LUSTRE_OPTS},ro 10.1.252.229@tcp:/sffs /lustre0"

echo "  mount -t nfs4 -o ${DM_NFS_OPTS},ro s21dserv.ls.aps.anl.gov:/export/dm  /opt/dm"
echo "  mount -t nfs4 -o ${DM_NFS_OPTS},ro catfiles.xray.aps.anl.gov:/dmOpt    /dmOpt"
echo
