#!/bin/sh

export mig_before="/root/migration_before.txt"
export mig_after="/root/migration_after.txt"
export repip="10.65.30.103"
export kerver=$(/usr/bin/uname -r|awk -F\. '{print $1}'|grep ^[0-9]*)

### before info gather
echo "------------------------------ Red Hat Before Info Gather ------------------------------" 
echo "------------------------------ Red Hat Package Total Count ------------------------------" > $mig_before
/usr/bin/rpm -qa|wc -l >> $mig_before
echo "------------------------------ Red Hat Package List Gather ------------------------------" >> $mig_before
/usr/bin/rpm -qa --qf "%{NAME} %{VENDOR} \n" | grep "Red Hat, Inc." | cut -d ' ' -f 1 | sort | grep -v kmod-kvdo >> $mig_before
echo "-----------------------------------------------------------------------------------" >> $mig_before

### Repository Check 
osver=`cat /etc/redhat-release |awk '{print $7}'`

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
gpgcheck=1
gpgkey=http://$repip/centos/$osver/RPM-GPG-KEY-CentOS-7
enabled = 1
EOF

### Red Hat Packages Remove
echo "------------------------------ Red Hat Packages Remove ------------------------------"
/usr/bin/yum -y remove rhnlib abrt-plugin-bugzilla redhat-release-notes* redhat-release-eula anaconda-user-help python-gudev python-hwdata redhat-access-gui redhat-access-insights redhat-support-lib-python redhat-support-tool subscription-manager subscription-manager-gui subscription-manager-initial-setup-addon NetworkManager-config-server Red_Hat_Enterprise_Linux-Release_Notes-7-en-US Red_Hat_Enterprise_Linux-Release_Notes-7-ko-KR rhsm-gtk xorriso redhat-access-plugin-ipa -y

/usr/bin/rpm -e --nodeps redhat-release-server
/usr/bin/rpm -e --nodeps redhat-indexhtml
/usr/bin/rm -rf /usr/share/redhat-release* /usr/share/doc/redhat-release*

### CentOS Base Package Install
echo "------------------------------ CentOS Base Packages Install ------------------------------"
/usr/bin/yum -y install centos-indexhtml centos-release yum yum-plugin-fastestmirror

### CentOS Repository Listing
echo "------------------------------ CentOS Repository Listing ------------------------------" 
if [ ! -f /usr/bin/yum-config-manager ];then
	echo "yum-config-manager Not Found and yum-utils install.."
	/usr/bin/yum -y install yum-utils
	if [ $? -ge 1 ];then
		echo "yum utils Package Install Failed..."
		exit 1;
	fi 
fi

/usr/bin/yum repolist --disablerepo=* 
/usr/bin/yum-config-manager --disable \* 
/usr/bin/yum-config-manager --enable local

/usr/bin/yum clean all
/usr/bin/yum  repolist

### CentOS Package Upgrade
echo "------------------------------ CentOS Package Upgrade ------------------------------" 
/usr/bin/yum upgrade -y

### CentOS Pcakage Reinstall
echo "------------------------------ CentOS Package Reinstall ------------------------------" 
/usr/bin/yum -y reinstall $(rpm -qa --qf "%{NAME} %{VENDOR} \n" | grep "Red Hat, Inc." | cut -d ' ' -f 1 | sort | grep -v kmod-kvdo)

### kernel reinstall
echo "------------------------------ CentOS kernel Package Reinstall ------------------------------" 

if [ $kerver -eq "3" ];then
	echo "Kernel Reinstall OSVER : $osver"
	/usr/bin/yum -y reinstall $(rpm -qa --qf "%{NAME} %{VENDOR} \n" | grep "kernel" | cut -d ' ' -f 1 | sort | grep -v kmod-kvdo)
	/usr/bin/rpm -ivh --force http://$repip/centos/$osver/Packages/$(rpm -qa|grep kernel-3).rpm
elif [ $kerver -eq "2" ];then
        echo "Kernel Reinstall OSVER : $osver"
        /usr/bin/yum -y reinstall $(rpm -qa --qf "%{NAME} %{VENDOR} \n" | grep "kernel" | cut -d ' ' -f 1 | sort | grep -v kmod-kvdo)
        /usr/bin/rpm -ivh --force http://$repip/centos/$osver/Packages/$(rpm -qa|grep kernel-2).rpm
fi

### grub Listing
echo "------------------------------ CentOS grub Listing ------------------------------" 
if [ -f /boot/grub2/grub.cfg ]; then
	echo "MBR grub..."
	/usr/sbin/grub2-mkconfig -o /boot/grub2/grub.cfg	
elif [ -f /boot/efi/EFI/centos/grub.cfg ]; then
	echo "EFI grub..."
	/usr/sbin/grub2-mkconfig -o /boot/efi/EFI/centos/grub.cfg
fi


echo "------------------------------ Other Package Reinstall ------------------------------" 
### openssl reinstall
yum -y reinstall $(rpm -qa --qf "%{NAME} %{VENDOR} \n" | grep "openssl" | cut -d ' ' -f 1 | sort | grep -v kmod-kvdo)

### openssl098e
num1=`rpm -qa --qf "%{NAME} %{VENDOR} \n" | grep "Red Hat, Inc." | grep "openssl098e" | cut -d ' ' -f 1 | sort|wc -l` > /dev/null 2>&1
if [ $num1 -ge 1 ];then
echo "openssl098e Install... Change"
yum -y remove openssl098e
yum -y install openssl098e
else
echo "openssl098e Skip..."
fi

### ntp
num2=`rpm -qa --qf "%{NAME} %{VENDOR} \n" | grep "Red Hat, Inc." | grep "ntp" | cut -d ' ' -f 1 | sort|wc -l` > /dev/null 2>&1
if [ $num2 -ge 1 ];then
echo "ntp Install... Change"
/usr/bin/cp -f /etc/ntp.conf /tmp > /dev/null 2>&1
yum -y remove ntp*
yum -y install ntp*cat
/usr/bin/cp -f /tmp/ntp.conf /etc > /dev/null 2>&1
else
echo "ntp Skip..."
fi

### xulrunner
num3=`rpm -qa --qf "%{NAME} %{VENDOR} \n" | grep "Red Hat, Inc." | grep "xulrunner" | cut -d ' ' -f 1 | sort|wc -l` > /dev/null 2>&1
if [ $num3 -ge 1 ];then
echo "xulrunner Install... Change"
yum -y remove xulrunner
yum -y install xulrunner esc
else
echo "xulrunner Skip..."
fi

### dhclient
num4=`rpm -qa --qf "%{NAME} %{VENDOR} \n" | grep "Red Hat, Inc." | grep "dhclient" | cut -d ' ' -f 1 | sort|wc -l` > /dev/null 2>&1
if [ $num4 -ge 1 ];then
echo "dhclient Install... Change"
#rpm -e --nodeps $(rpm -qa|grep -E "dhclient|dhcp-libs|dhcp-common")
yum -y remove dhclient dhcp-libs dhcp-common
yum -y install dhclient abrt-addon-vmcore abrt-cli abrt-console-notification abrt-desktop anaconda-core anaconda-tui dracut-network initial-setup kexec-tools 
/usr/bin/rpm -qa|grep -i -E "abrt-addon-vmcore|abrt-cli|abrt-console-notification|abrt-desktop|anaconda-core|anaconda-tui|dracut-network|initial-setup-0|kexec-tools"
else
echo "dhclient Skip..."
fi

### firefox
num5=`rpm -qa --qf "%{NAME} %{VENDOR} \n" | grep "Red Hat, Inc." | grep "firefox" | cut -d ' ' -f 1 | sort|wc -l` > /dev/null 2>&1
if [ $num5 -ge 1 ];then
echo "firefox Install... Change"
yum -y remove firefox
yum -y install firefox 
else
echo "firefox Skip..."
fi


### kmod-kvdo
num6=`rpm -qa --qf "%{NAME} %{VENDOR} \n" | grep "Red Hat, Inc." | grep "kmod-kvdo" | cut -d ' ' -f 1 | sort|wc -l` > /dev/null 2>&1
if [ $num6 -ge 1 ];then
echo "kmod-kvdo Install... Change"
yum -y remove kmod-kvdo
yum -y install kmod-kvdo vdo
else
echo "kmod-kvdo Skip..."
fi

### mokutil
num7=`rpm -qa --qf "%{NAME} %{VENDOR} \n" | grep "Red Hat, Inc." | grep "mokutil" | cut -d ' ' -f 1 | sort|wc -l` > /dev/null 2>&1
if [ $num7 -ge 1 ];then
echo "mokutil Install... Change"
yum -y remove mokutil
yum -y install mokutil systemtap systemtap-client
else
echo "mokutil Skip..."
fi


### filesystem
yum -y reinstall filesystem

### Other Red Hat Package Result
echo "------------------------------ Other Red Hat Package ------------------------------" 
rpm -qa --qf "%{NAME} %{VENDOR} \n" | grep "Red Hat, Inc." | cut -d ' ' -f 1 | sort

### after info gather
echo "------------------------------ Red Hat Before Info Gather ------------------------------" 
echo "------------------------------ Red Hat Package Total Count ------------------------------" > $mig_after
/usr/bin/rpm -qa|wc -l >> $mig_after
echo "------------------------------ Red Hat Package List Gather ------------------------------" >> $mig_after
/usr/bin/rpm -qa --qf "%{NAME} %{VENDOR} \n" | grep "Red Hat, Inc." | cut -d ' ' -f 1 | sort | grep -v kmod-kvdo >> $mig_after
echo "-----------------------------------------------------------------------------------" >> $mig_after
