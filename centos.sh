#!/bin/sh
set -x

###########################################################################
# rhel to centos migration Script
# Ver. 10
###########################################################################

if [ ! -f /etc/redhat-release ];then
	echo "NOT FOUND... /etc/redhat-release"
	exit 1;
fi

export mig_before="/root/migration_before.txt"
export mig_before_pkg="/root/migration_before_pkg.txt"
export mig_after="/root/migration_after.txt"
export mig_after_pkg="/root/migration_after_pkg.txt"
export repip="10.65.30.103"
export osver=`cat /etc/redhat-release |awk '{print $7}'`
export osversion=`cat /etc/redhat-release |awk '{print $7}'|awk -F\. '{print $1}'`
export yumbin="/usr/bin/yum"




### 7 version env
if [ $osversion -eq "7" ];then
	export kerver=$(/usr/bin/uname -r|awk -F\. '{print $1}'|grep ^[0-9]*)
	export rpmbin="/usr/bin/rpm"
	export gpg="gpgkey=http://$repip/centos/$osver/RPM-GPG-KEY-CentOS-7"
	export rmbin="/usr/bin/rm"
	export yumre="$yumbin -y reinstall"
	export updatever="update7"
	echo "Kernel Reinstall OSVER : $osver"
	pkg_upgrade() {
		$yumbin upgrade -y 
	}
	kernel_install() {
		$yumre $($rpmbin -qa --qf "%{NAME} %{VENDOR} \n" | grep "kernel" | cut -d ' ' -f 1 | sort | grep -v kmod-kvdo)
		$rpmbin -ivh --force http://$repip/centos/$osver/Packages/$($rpmbin -qa|grep kernel-3).rpm
	}
	bootloader() {
	if [ -f /boot/grub2/grub.cfg ]; then
		echo "MBR grub..."
		/usr/sbin/grub2-mkconfig -o /boot/grub2/grub.cfg	
	elif [ -f /boot/efi/EFI/centos/grub.cfg ]; then
		echo "EFI grub..."
		/usr/sbin/grub2-mkconfig -o /boot/efi/EFI/centos/grub.cfg
	fi
	}
### 6 version env
elif [ $osversion -eq "6" ];then
	export kerver=$(/bin/uname -r|awk -F\. '{print $1}'|grep ^[0-9]*)
	export rpmbin="/bin/rpm"
	export gpg="gpgkey=http://$repip/centos/$osver/RPM-GPG-KEY-CentOS-6"
	export rmbin="/bin/rm"
	export yumre="$yumbin -y reinstall"
	export updatever="update6"
        echo "Kernel Reinstall OSVER : $osver"
	pkg_upgrade() {
		$yumbin upgrade -y
	}
	kernel_install() {
        	$yumre $($rpmbin -qa --qf "%{NAME} %{VENDOR} \n" | grep "kernel" | cut -d ' ' -f 1 | sort | grep -v kmod-kvdo)
        	$rpmbin -ivh --force http://$repip/centos/$osver/Packages/$($rpmbin -qa|grep kernel-2).rpm
	}
	bootloader() {
		echo " bootloader skip... "
	}
else
        echo "Version Check Fail..."
        exit 1;
fi

### before info gather
echo "------------------------------ Red Hat Before Info Gather ------------------------------" 
echo "------------------------------ Red Hat Package Total Count ------------------------------" > $mig_before
$rpmbin -qa | sort > $mig_before_pkg
cat $mig_before_pkg | wc -l >> $mig_before
echo "------------------------------ Red Hat Package List Gather ------------------------------" >> $mig_before
$rpmbin -qa --qf "%{NAME} %{VENDOR} \n" | grep "Red Hat, Inc." | cut -d ' ' -f 1 | sort | grep -v kmod-kvdo >> $mig_before
echo "-----------------------------------------------------------------------------------" >> $mig_before

### Red Hat Packages Remove
echo "------------------------------ Red Hat Packages Remove ------------------------------"
$yumbin -y remove rhnlib abrt-plugin-bugzilla redhat-release-notes* redhat-release-eula anaconda-user-help python-gudev python-hwdata redhat-access-gui redhat-access-insights redhat-support-lib-python redhat-support-tool subscription-manager subscription-manager-gui subscription-manager-initial-setup-addon NetworkManager-config-server Red_Hat_Enterprise_Linux-Release_Notes-7-en-US Red_Hat_Enterprise_Linux-Release_Notes-7-ko-KR rhsm-gtk xorriso redhat-access-plugin-ipa subscription-manager-migration-data subscription-manager-rhsm subscription-manager-rhsm-certificates cloud-init

$rpmbin -e --nodeps redhat-release-server
$rpmbin -e --nodeps redhat-indexhtml
$rmbin -rf /usr/share/redhat-release* /usr/share/doc/redhat-release*


### Repository Check 
RES_CODE=$(/usr/bin/curl -s -o /dev/null -I -w "%{http_code}"  "http://$repip/centos/$osver/TRANS.TBL")
if [ $RES_CODE -eq 200 ]; then
  echo "------------------------------ Repository Found ------------------------------"
else
  echo "------------------------------ Repository Not Found ------------------------------"
  exit 1;
fi



### Repository Create
echo "OSVER : $osver"
cat << EOF > /etc/yum.repos.d/local.repo 
[local]
name=local
baseurl=http://$repip/centos/$osver/
$gpg
gpgcheck=1
enabled=1
EOF

cat << EOF > /etc/yum.repos.d/update.repo 
[update]
name=update
baseurl=http://$repip/centos/$updatever/
$gpg
gpgcheck=1
enabled=1
EOF


### CentOS Base Package Install
echo "------------------------------ CentOS Base Packages Install ------------------------------"
$yumbin -y install centos-indexhtml centos-release yum yum-plugin-fastestmirror

### CentOS Repository Listing
echo "------------------------------ CentOS Repository Listing ------------------------------" 
if [ ! -f $yumbin-config-manager ];then
	echo "yum-config-manager Not Found and yum-utils install.."
	$yumbin -y install yum-utils
	if [ $? -ge 1 ];then
		echo "yum utils Package Install Failed..."
		exit 1;
	fi 
fi

mkdir /etc/yum.repos.d/temp
mv /etc/yum.repos.d/CentOS-* /etc/yum.repos.d/temp/

$yumbin repolist --disablerepo=* 
/usr/bin/yum-config-manager --disable \* 
/usr/bin/yum-config-manager --enable local

$yumbin clean all
$yumbin repolist


### CentOS Package Upgrade
echo "------------------------------ CentOS Package Upgrade ------------------------------" 
pkg_upgrade

### CentOS Pcakage Reinstall
echo "------------------------------ CentOS Package Reinstall ------------------------------" 
$yumre $($rpmbin -qa --qf "%{NAME} %{VENDOR} \n" | grep "Red Hat, Inc." | cut -d ' ' -f 1 | sort | grep -v kmod-kvdo)

### kernel reinstall
echo "------------------------------ CentOS kernel Package Reinstall ------------------------------" 
kernel_install

### grub Listing
echo "------------------------------ CentOS grub Listing ------------------------------" 
bootloader

echo "------------------------------ Other Package Reinstall ------------------------------" 
### openssl reinstall
$yumre $($rpmbin -qa --qf "%{NAME} %{VENDOR} \n" | grep "openssl" | cut -d ' ' -f 1 | sort | grep -v kmod-kvdo)

### openssl098e
num1=`$rpmbin -qa --qf "%{NAME} %{VENDOR} \n" | grep "Red Hat, Inc." | grep "openssl098e" | cut -d ' ' -f 1 | sort|wc -l` > /dev/null 2>&1
if [ $num1 -ge 1 ];then
echo "openssl098e Install... Change"
$yumbin -y remove openssl098e
$yumbin -y install openssl098e
else
echo "openssl098e Skip..."
fi

### ntp
num2=`$rpmbin -qa --qf "%{NAME} %{VENDOR} \n" | grep "Red Hat, Inc." | grep "ntp" | cut -d ' ' -f 1 | sort|wc -l` > /dev/null 2>&1
if [ $num2 -ge 1 ];then
echo "ntp Install... Change"
/usr/bin/cp -f /etc/ntp.conf /tmp > /dev/null 2>&1
$yumbin -y remove ntp
$yumbin yum -y install ntp
/usr/bin/cp -f /tmp/ntp.conf /etc > /dev/null 2>&1
else
echo "ntp Skip..."
fi

### xulrunner
num3=`$rpmbin -qa --qf "%{NAME} %{VENDOR} \n" | grep "Red Hat, Inc." | grep "xulrunner" | cut -d ' ' -f 1 | sort|wc -l` > /dev/null 2>&1
if [ $num3 -ge 1 ];then
echo "xulrunner Install... Change"
$yumbin -y remove xulrunner
$yumbin -y install xulrunner esc
else
echo "xulrunner Skip..."
fi

### dhclient
num4=`$rpmbin -qa --qf "%{NAME} %{VENDOR} \n" | grep "Red Hat, Inc." | grep "dhclient" | cut -d ' ' -f 1 | sort|wc -l` > /dev/null 2>&1
if [ $num4 -ge 1 ];then
echo "dhclient Install... Change"
#$rpmbin -e --nodeps $($rpmbin -qa|grep -E "dhclient|dhcp-libs|dhcp-common")
$yumbin -y remove dhclient dhcp-libs dhcp-common
$yumbin -y install dhclient abrt-addon-vmcore abrt-cli abrt-console-notification abrt-desktop anaconda-core anaconda-tui dracut-network initial-setup kexec-tools 
else
echo "dhclient Skip..."
fi

### firefox
num5=`$rpmbin -qa --qf "%{NAME} %{VENDOR} \n" | grep "Red Hat, Inc." | grep "firefox" | cut -d ' ' -f 1 | sort|wc -l` > /dev/null 2>&1
if [ $num5 -ge 1 ];then
echo "firefox Install... Change"
$yumbin -y remove firefox
$yumbin -y install firefox 
else
echo "firefox Skip..."
fi


### kmod-kvdo
num6=`$rpmbin -qa --qf "%{NAME} %{VENDOR} \n" | grep "Red Hat, Inc." | grep "kmod-kvdo" | cut -d ' ' -f 1 | sort|wc -l` > /dev/null 2>&1
if [ $num6 -ge 1 ];then
echo "kmod-kvdo Install... Change"
$yumbin -y remove kmod-kvdo
$yumbin -y install kmod-kvdo vdo
else
echo "kmod-kvdo Skip..."
fi

### mokutil
num7=`$rpmbin -qa --qf "%{NAME} %{VENDOR} \n" | grep "Red Hat, Inc." | grep "mokutil" | cut -d ' ' -f 1 | sort|wc -l` > /dev/null 2>&1
if [ $num7 -ge 1 ];then
echo "mokutil Install... Change"
$yumbin -y remove mokutil
$yumbin -y install mokutil systemtap systemtap-client
else
echo "mokutil Skip..."
fi

### filesystem
$yumre filesystem

### Other Red Hat Package Result
echo "------------------------------ Other Red Hat Package ------------------------------" 
$rpmbin -qa --qf "%{NAME} %{VENDOR} \n" | grep "Red Hat, Inc." | cut -d ' ' -f 1 | sort

### after info gather
echo "------------------------------ Red Hat Before Info Gather ------------------------------" 
echo "------------------------------ Red Hat Package Total Count ------------------------------" > $mig_after
$rpmbin -qa | sort > $mig_after_pkg
cat $mig_after_pkg | wc -l >> $mig_after
echo "------------------------------ Red Hat Package List Gather ------------------------------" >> $mig_after
$rpmbin -qa --qf "%{NAME} %{VENDOR} \n" | grep "Red Hat, Inc." | cut -d ' ' -f 1 | sort | grep -v kmod-kvdo >> $mig_after
echo "-----------------------------------------------------------------------------------" >> $mig_after

