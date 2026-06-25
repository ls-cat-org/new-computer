#!/bin/bash
if [ $UID -ne 0 ]; then
    echo "Please rerun this script with elevated privileges" >&2
    exit 1
fi

umount /pf >/dev/null 2>&1
umount /lustre2 >/dev/null 2>&1
umount /lustre1 >/dev/null 2>&1
umount /lustre0 >/dev/null 2>&1

set -uex
mv -f /etc/sudoers /etc/sudoers.default
cp -f etc/sudoers /etc/sudoers
chmod 0440 /etc/sudoers

mkdir -m 0644 -p /etc/pam.d.default
cp -f /etc/pam.d/* /etc/pam.d.default

mv -f etc/pam.d/common-auth /etc/pam.d/common-auth
mv -f etc/pam.d/common-account /etc/pam.d/common-account
mv -f etc/pam.d/common-session /etc/pam.d/common-session

# Append to fstab special LS-CAT shared filesystems.
cat <<EOF >> /etc/fstab

# Mount our NFS directory for general-purpose shared data where
# home dirs also reside. The obtuse name "/pf" was chosen to
# retain backward compatibility with long-standing hardcoded
# EPICS scripts.
ldap1.ls-cat.net:/pf /pf nfs defaults,_netdev,nofail,noatime,ro

# Mount our two lustre filesystems where image datasets reside.
#
# lustre0 is our ancient lustre filesystem (formerly known as /oe)
#
# lustre1 is our old lustre filesystem where data produced by lsnode
#   most recently went (formerly known as /pf.
#
#
# lustre2 is our latest and greatest lustre filesystem where datasets
#   produced by mxcube3 collection reside.
10.1.0.11@tcp:/adfs /lustre2 lustre defaults,nofail,flock,_netdev,x-systemd.requires=lnet.service 0 0
10.1.0.13@tcp:/bdfs /lustre1 lustre defaults,nofail,flock,_netdev,x-systemd.requires=lnet.service 0 0
10.1.252.229@tcp:/sffs /lustre0 lustre defaults,nofail,flock,_netdev,x-systemd.requires=lnet.service 0 0

EOF

set +x
echo
echo "Finished installing config files for LDAP-based user authentication."
echo "Please run the following commands in order to allow this updated configuration to take effect:"
echo
echo "  systemctl disable --now nslcd"
echo "  systemctl restart sssd"
echo "  sss_cache -E"
echo
