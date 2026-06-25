#!/bin/bash
if [ $UID -ne 0 ]; then
    echo "Please rerun this script with elevated privileges" >&2
    exit 1
fi

umount /pf >/dev/null 2>&1
umount /lustre2 >/dev/null 2>&1
umount /lustre1 >/dev/null 2>&1
umount /lustre0 >/dev/null 2>&1

set -ue
cfg_install() {
    src=$1 # the relative path under git repo
    dst=/$1
    prev=/$1.default
    permissions=$2
    if [ -f $src ]; then
	cp -n $dst $prev
	cp -f $src $dst
	chmod $permissions $dst
    fi
    echo "$dst updated (vanilla OS installation file located at $prev)"
}

cfg_install etc/sssd/sssd.conf 0600
cfg_install etc/sudoers 0440
cfg_install etc/pam.d/common-auth 0644
cfg_install etc/pam.d/common-account 0644
cfg_install etc/pam.d/common-session 0644

# Append to fstab special LS-CAT shared filesystems.
[ -f /etc/fstab.default ] || cp -f /etc/fstab /etc/fstab.default
cat <<EOF >> /etc/fstab

# Mount our NFS directory for general-purpose shared data where
# home dirs also reside. The obtuse name "/pf" was chosen to
# retain backward compatibility with long-standing hardcoded
# EPICS scripts.
ldap1.ls-cat.net:/pf /pf nfs defaults,_netdev,nofail,noatime,ro

# Mount our two lustre filesystems.
#
# lustre2 is our test environment lustre filesystem.
#
# lustre1 is our latest and greatest production env lustre filesystem.
#
# (DISABLED)
# lustre0 is our old lustre filesystem where data produced by lsnode
#   goes (formerly known as /pf). It is read-only for machines outside
#   the legacy lsnode ecosystem. You may uncomment the corresponding
#   fstab line for any machine involved in legacy data migration.
#
10.1.0.13@tcp:/bdfs /lustre2 lustre rw,noatime,checksum,flock,nouser_xattr,lruresize,lazystatfs,nouser_fid2path,verbose,encrypt,statfs_project,nofail,_netdev,x-systemd.requires=lnet.service 0 0
10.1.0.11@tcp:/adfs /lustre1 lustre rw,noatime,checksum,flock,nouser_xattr,lruresize,lazystatfs,nouser_fid2path,verbose,encrypt,statfs_project,nofail,_netdev,x-systemd.requires=lnet.service 0 0
#10.1.252.229@tcp:/sffs /lustre0 lustre ro,noatime,checksum,flock,nouser_xattr,lruresize,lazystatfs,nouser_fid2path,verbose,noencrypt,nofail,_netdev,x-systemd.requires=lnet.service 0 0

EOF

echo
echo "Finished installing config files for LDAP-based user authentication."
echo "Please run the following commands in order to allow this updated configuration to take effect:"
echo
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
