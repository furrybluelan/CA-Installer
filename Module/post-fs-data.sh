#!/system/bin/sh

MODDIR=${0%/*}
exec > $MODDIR/CustomCACert.log
exec 2>&1

set -x

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

CheckAppCertificate() {
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

CheckUserCertificate(){
    for user_dir in /data/misc/user/*/cacerts-added; do
        [ -d "$user_dir" ] || continue
        
        # 2. 遍历该目录下所有的证书文件
        for cert_path in "$user_dir"/*; do
            [ -f "$cert_path" ] || continue
            
            # 获取文件名（例如 0f4ed297.0）
            cert_name=$(basename "$cert_path")
            
            # 3. 冲突处理逻辑
            if [ -f "$MOD_CA_DIR/$cert_name" ]; then
                # 如果目标已存在同名文件，对比文件是否一致
                if ! cmp -s "$cert_path" "$MOD_CA_DIR/$cert_name"; then
                    # 如果内容不同，则增加后缀索引（例如 .0 变为 .1）
                    # 提取哈希部分 (点号前的部分)
                    hash_part="${cert_name%.*}"
                    # 寻找下一个可用的索引数字
                    suffix=1
                    while [ -f "$MOD_CA_DIR/$hash_part.$suffix" ]; do
                        suffix=$((suffix + 1))
                    done
                    target_name="$hash_part.$suffix"
                else
                    # 内容相同，无需重复复制
                    continue
                fi
            else
                target_name="$cert_name"
            fi
            # 4. 执行复制
            cp -p "$cert_path" "$MOD_CA_DIR/$target_name"
        done
    done
}

Main() {
    # 检查文件存在再调用 CheckAppCertificate
    CheckUserCertificate
    if [ -f "/storage/emulated/0/Android/data/com.reqable.android/files/certificate/reqable-root.crt" ]; then
        CheckAppCertificate "/storage/emulated/0/Android/data/com.reqable.android/files/certificate/reqable-root.crt"
    fi
    
    if [ -f "/data/user/0/com.guoshi.httpcanary/cache/HttpCanary.pem" ]; then
        CheckAppCertificate "/data/user/0/com.guoshi.httpcanary/cache/HttpCanary.pem"
    fi
    
    if [ -f "/data/user/0/com.network.proxy/files/ca.crt" ]; then
        CheckAppCertificate "/data/user/0/com.network.proxy/files/ca.crt"
    fi
    
    chown -R 0:0 ${MODDIR}/system/etc/security/cacerts
	chmod 644 "$MODDIR/system/etc/security/cacerts/"*.*
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
}

Main