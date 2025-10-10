#!/system/bin/sh
SKIPUNZIP=1
DEBUG=false
[[ "$(getprop persist.sys.locale)" == *"zh"* || "$(getprop ro.product.locale)" == *"zh"* ]] && LOCALE="CN" || LOCALE="EN"
print_cn() { [ "$LOCALE" = "CN" ] && ui_print "$1"; }
print_en() { [ "$LOCALE" = "EN" ] && ui_print "$1"; }
abort_cn() { [ "$LOCALE" = "CN" ] && abort_verify "$1"; }
abort_en() { [ "$LOCALE" = "EN" ] && abort_verify "$1"; }

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

MoveCert(){
    if [ -f $2 ]; then
        print_cn "➡️ 找到 $1 证书"
        print_en "➡️ Found $1 certificate"
        certname="$(/system/bin/app_process \
        -Djava.class.path="$MODPATH/CertName.dex" \
        / \
        --nice-name=CertHash \
        CertName $2 &)"
        cp $2 "$MODPATH/system/etc/security/cacerts/$certname"
        print_cn "✅ $1 证书安装成功!"
        print_en "✅ $1 certificate installed successfully"
    else
        print_cn "❎️ 没有找到 $1 的证书，跳过安装"
        print_en "❎️ No certificate found for $1, skipping this installation"
    fi
}
    
print_cn "➡️ 提取模块文件"
print_en "➡️ Extracting module files"
FILES="
system/etc/security/cacerts/.keep
post-fs-data.sh
CertName.dex
module.prop
"
for FILE in $FILES; do
  extract "$ZIPFILE" "$FILE" "$MODPATH"
done
extract "$ZIPFILE" ".ca_inst_state.sh" "/data/adb/service.d"

print_cn "➡️ 查找并安装证书中…"
print_en "➡️ Locating and installing certificates…"
ui_print ""
mkdir -p "$MODPATH/system/etc/security/cacerts"
MoveCert "Reqable" "/storage/emulated/0/Android/data/com.reqable.android/files/certificate/reqable-root.crt"
MoveCert "HttpCanary" "/data/user/0/com.guoshi.httpcanary/cache/HttpCanary.pem"
MoveCert "ProxyPin" "/data/user/0/com.network.proxy/files/ca.crt"

print_cn "➡️ 删除临时文件"
print_en "➡️ Deleting temporary files"
rm "$MODPATH/system/etc/security/cacerts/.keep"

ui_print ""
print_cn "✅ 安装完成！"
print_en "✅ Module installation complete!"