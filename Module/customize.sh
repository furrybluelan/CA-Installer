#!/system/bin/sh
SKIPUNZIP=1
DEBUG=false
[[ "$(getprop persist.sys.locale)" == *"zh"* || "$(getprop ro.product.locale)" == *"zh"* ]] && LOCALE="CN" || LOCALE="EN"
print_cn() { [ "$LOCALE" = "CN" ] && ui_print "$1"; }
print_en() { [ "$LOCALE" = "EN" ] && ui_print "$1"; }
abort_cn() { [ "$LOCALE" = "CN" ] && abort_verify "$1"; }
abort_en() { [ "$LOCALE" = "EN" ] && abort_verify "$1"; }
MOD_CA_DIR="$MODPATH/system/etc/security/cacerts"

unzip -o "$ZIPFILE" 'verify.sh' -d "$TMPDIR" >/dev/null
if [ ! -f "$TMPDIR/verify.sh" ]; then
  ui_print "*********************************************************"
  ui_print "❌ 无法提取 verify.sh!"
  ui_print "❌ 这个ZIP文件已损坏,请重新下载"
  print_en "❌ Unable to extract verify.sh!"
  print_en "❌ This zip may be corrupted, please try downloading again"
  abort "*********************************************************"
fi
. "$TMPDIR/verify.sh"

MoveAppCertificate(){
    OperaterAppName=$1
    OriginCertificatePath=$2
    if [ -f "$OriginCertificatePath" ]; then
        print_cn "➡️ 找到 $OperaterAppName 证书"
        print_en "➡️ Found $OperaterAppName Certificate"
        SystemCertificateName="$(/system/bin/app_process \
        -Djava.class.path="$MODPATH/SystemCertificateName.dex" \
        / \
        --nice-name=CertHash \
        SystemCertificateName $OriginCertificatePath &)"
        cp $OriginCertificatePath "$MOD_CA_DIR/$SystemCertificateName"
        print_cn "✅ $OperaterAppName 证书安装成功!"
        print_en "✅ $OperaterAppName certificate installed successfully"
    else
        print_cn "❎️ 没有找到 $OperaterAppName 的证书，跳过安装"
        print_en "❎️ No certificate found for $OperaterAppName, skipping this installation"
    fi
}

MoveUserCertificate(){
    print_cn "➡️ 移动用户证书…"
    print_en "➡️ Moving user certificates…"
    count=0
    for user_dir in /data/misc/user/*/cacerts-added; do
        [ -d "$user_dir" ] || continue
        count=$((count + 1))

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

            # 4. 执行复制并设置权限
            print_cn "✅ 移动用户证书 $cert_path -> $MOD_CA_DIR/$target_name"
            print_en "✅ Moving user certificate $cert_path -> $MOD_CA_DIR/$target_name"
            cp -p "$cert_path" "$MOD_CA_DIR/$target_name"
            chown root:root "$MOD_CA_DIR/$target_name"
            chmod 644 "$MOD_CA_DIR/$target_name"
        done
    done
    if [ $count -eq 0 ]; then
        print_cn "❎️ 没有找到用户证书，跳过安装"
        print_en "❎️ No user certificates found, skipping installation"
    fi
}
    
print_cn "➡️ 提取模块文件"
print_en "➡️ Extracting module files"
FILES="
system/etc/security/cacerts/.keep
SystemCertificateName.dex
post-fs-data.sh
module.prop
"
for FILE in $FILES; do
  extract "$ZIPFILE" "$FILE" "$MODPATH"
done

print_cn "➡️ 查找并安装证书中…"
print_en "➡️ Locating and installing certificates…"
ui_print ""
mkdir -p "$MODPATH/system/etc/security/cacerts"
MoveAppCertificate "Reqable" /storage/emulated/0/Android/data/com.reqable.android/files/certificate/reqable-root.crt
MoveAppCertificate "HttpCanary" "/data/user/0/com.guoshi.httpcanary/cache/HttpCanary.pem"
MoveAppCertificate "ProxyPin" "/data/user/0/com.network.proxy/files/ca.crt"
MoveUserCertificate

ui_print "➡️ 删除临时文件"
print_en "➡️ Deleting temporary files"
rm "$MODPATH/system/etc/security/cacerts/.keep"

ui_print ""
print_cn "✅ 安装完成！"
print_en "✅ Module installation complete!"