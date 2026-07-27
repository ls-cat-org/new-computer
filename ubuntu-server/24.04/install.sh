#!/bin/bash
if [ $UID -ne 0 ]; then
    echo "Please rerun this script with elevated privileges" >&2
    exit 1
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
LSCAT_NFS_OPTS='defaults,_netdev,nofail,noatime'
LSCAT_LUSTRE_OPTS='noatime,checksum,flock,acl,lruresize,lazystatfs,nouser_fid2path,verbose,encrypt,statfs_project,_netdev,nofail,x-systemd.requires=lnet.service'
DM_NFS_OPTS='relatime,vers=4.2,namlen=255,rsize=524288,wsize=524288,hard,fatal_neterrors=none,proto=tcp,timeo=600,retrans=2,sec=sys,local_lock=none,_netdev,nofail'

mkdir -p    /pf /lustre0 /lustre1 /lustre2 /opt/dm /dmOpt
chmod 1777  /pf /lustre0 /lustre1 /lustre2 /opt/dm /dmOpt
mount -t nfs -o ${LSCAT_NFS_OPTS},rw ldap1.ls-cat.net:/pf /pf

mount -t lustre -o ${LSCAT_LUSTRE_OPTS},rw 10.1.0.13@tcp:/bdfs /lustre2
mount -t lustre -o ${LSCAT_LUSTRE_OPTS},rw 10.1.0.11@tcp:/adfs /lustre1
mount -t lustre -o ${LSCAT_LUSTRE_OPTS},ro 10.1.252.229@tcp:/sffs /lustre0

mount -t nfs4 -o ${DM_NFS_OPTS},ro s21dserv.ls.aps.anl.gov:/export/dm  /opt/dm
mount -t nfs4 -o ${DM_NFS_OPTS},ro catfiles.xray.aps.anl.gov:/dmOpt    /dmOpt

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

# Mount our two lustre filesystems.
#
# lustre2 is our test environment lustre filesystem.
#
# lustre1 is our latest and greatest production env lustre filesystem.
#
# lustre0 is our old lustre filesystem where data produced by lsnode
#   goes (formerly known as /pf). It is read-only for machines outside
#   the legacy lsnode ecosystem.
#
10.1.0.13@tcp:/bdfs /lustre2 lustre    ${LSCAT_LUSTRE_OPTS},rw 0 0
10.1.0.11@tcp:/adfs /lustre1 lustre    ${LSCAT_LUSTRE_OPTS},rw 0 0
10.1.252.229@tcp:/sffs /lustre0 lustre ${LSCAT_LUSTRE_OPTS},ro 0 0

#
# Mount the directories where APS "Data Management" utilities are located.
# The manual overrides for rsize and wsize were recommended by the APS
# from their own documentation on DM.
#
s21dserv.ls.aps.anl.gov:/export/dm /opt/dm nfs4  ${DM_NFS_OPTS},ro 0 0
catfiles.xray.aps.anl.gov:/dmOpt   /dmOpt  nfs4  ${DM_NFS_OPTS},ro 0 0

EOF

echo
echo "Finished installing config files for LDAP-based user authentication."
echo "Please run the following commands in order to allow this updated configuration to take effect:"
echo
echo "  systemctl daemon-reload"
echo "  systemctl disable --now nslcd"
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
