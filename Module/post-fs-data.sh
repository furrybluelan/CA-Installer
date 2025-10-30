#!/system/bin/sh

MODDIR=${0%/*}
exec > $MODDIR/CustomCACert.log
exec 2>&1

set -x

if [[ "$(getprop persist.sys.locale)" == *"zh"* ]] || [[ "$(getprop ro.product.locale)" == *"zh"* ]]; then
    LOCALE="CN"
else
    LOCALE="EN"
fi

conflictdes_all() { 
    sed -i "s/^description=.*/description=$1/" "$MODDIR/module.prop"
}

set_context() {
    [ "$(getenforce)" = "Enforcing" ] || return 0

    default_selinux_context=u:object_r:system_file:s0
    selinux_context=$(ls -Zd "$1" 2>/dev/null | awk '{print $1}')

    if [ -n "$selinux_context" ] && [ "$selinux_context" != "?" ]; then
        chcon -R "$selinux_context" "$2"
    else
        chcon -R "$default_selinux_context" "$2"
    fi
}

CheckCert() {
	CertFile=$1
    if [ -f "$CertFile" ]; then
        CertName=$(/system/bin/app_process \
            -Djava.class.path="$MODDIR/CertName.dex" \
            / \
            --nice-name=CertHash \
            CertName "$CertName")
        
        if [ -n "$CertName" ] && ! [ -f "$MODDIR/system/etc/security/cacerts/$CertName" ]; then
            cp "$1" "$MODDIR/system/etc/security/cacerts/$CertName"
        fi
        return 0
    else
        return 1
    fi
}

Main() {
    Desc=""
    Ag_Cert_Hash=0f4ed297
    Ag_Cert_File=$(ls /data/misc/user/*/cacerts-added/${Ag_Cert_Hash}.* 2>/dev/null | (IFS=.; while read -r left right; do echo $right $left.$right; done) | sort -nr | (read -r left right; echo $right))
    
    # 检查文件存在再调用 CheckCert
    if [ -n "$Ag_Cert_File" ]; then
        CheckCert "$Ag_Cert_File" && Desc="$Desc AdGuard,"
    fi
    
    if [ -f "/storage/emulated/0/Android/data/com.reqable.android/files/certificate/reqable-root.crt" ]; then
        CheckCert "/storage/emulated/0/Android/data/com.reqable.android/files/certificate/reqable-root.crt" && Desc="$Desc Reqable,"
    fi
    
    if [ -f "/data/user/0/com.guoshi.httpcanary/cache/HttpCanary.pem" ]; then
        CheckCert "/data/user/0/com.guoshi.httpcanary/cache/HttpCanary.pem" && Desc="$Desc HttpCanary,"
    fi
    
    if [ -f "/data/user/0/com.network.proxy/files/ca.crt" ]; then
        CheckCert "/data/user/0/com.network.proxy/files/ca.crt" && Desc="$Desc ProxyPin"
    fi
    
    chown -R 0:0 ${MODDIR}/system/etc/security/cacerts
	chmod 644 "$MODDIR/system/etc/security/cacerts/"*.0
	set_context /system/etc/security/cacerts ${MODDIR}/system/etc/security/cacerts
    
    # Android 14 support
    if [ -d /apex/com.android.conscrypt/cacerts ]; then
        rm -f /data/local/tmp/sys-ca-copy
        mkdir -p /data/local/tmp/sys-ca-copy
        mount -t tmpfs tmpfs /data/local/tmp/sys-ca-copy
        cp -f /apex/com.android.conscrypt/cacerts/* /data/local/tmp/sys-ca-copy/ 2>/dev/null || true
        
        cp -f "$MODDIR/system/etc/security/cacerts"/* /data/local/tmp/sys-ca-copy/
        chown -R 0:0 /data/local/tmp/sys-ca-copy
        set_context /apex/com.android.conscrypt/cacerts /data/local/tmp/sys-ca-copy
        
        Certs_Num="$(ls -1 /data/local/tmp/sys-ca-copy 2>/dev/null | wc -l)"
        Original_Certs="$(ls -1 /apex/com.android.conscrypt/cacerts 2>/dev/null | wc -l)"
        
        if [ "$Original_Certs" -gt 5 ] && [ "$Certs_Num" -gt "$Original_Certs" ]; then
            mount --bind /data/local/tmp/sys-ca-copy /apex/com.android.conscrypt/cacerts
            for pid in 1 $(pgrep zygote) $(pgrep zygote64); do
                nsenter --mount=/proc/${pid}/ns/mnt -- \
                    mount --bind /data/local/tmp/sys-ca-copy /apex/com.android.conscrypt/cacerts
            done
        else
            echo "Mounting cancelled, certificate count check failed"
        fi
        
        umount /data/local/tmp/sys-ca-copy
        rmdir /data/local/tmp/sys-ca-copy
    fi
    
    if [ -n "$Desc" ]; then
        Desc="${Desc%,}"
        if [ "$LOCALE" = "CN" ]; then
            conflictdes_all "✅ 模块已生效，已将 ${Desc} 的证书放入系统目录"
        else
            conflictdes_all "✅ Module activated, certificates from ${Desc} have been installed into the system directory"
        fi
    else
        if [ "$LOCALE" = "CN" ]; then
            conflictdes_all "✅ 模块已启用，无作用域"
        else
            conflictdes_all "✅ Module enabled, no certificates found"
        fi
    fi
}

Main