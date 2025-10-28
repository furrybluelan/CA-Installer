[[ "$(getprop persist.sys.locale)" == *"zh"* ]] || [[ "$(getprop ro.product.locale)" == *"zh"* ]] && LOCALE="CN" || LOCALE="EN"

MODULE="CA-Installer"
MODDIR="/data/adb/modules/$MODULE"

conflictdes_all() { 
    sed -i "s/^description=.*/description=$1/" "$MODDIR/module.prop"
}

if [ -f "$MODDIR/disable" ]; then
	if [ "$LOCALE" = "CN" ]; then
		conflictdes_all "[ ❌ 模块已停用 ] 将多种抓包软件的CA证书安装到系统中，支持Magisk/KernelSU/APatch."
	else
		conflictdes_all "[ ❌ Disabled ] Install CA certificates from multiple packet capture apps into the system, supporting Magisk/KernelSU/APatch."
	fi
fi