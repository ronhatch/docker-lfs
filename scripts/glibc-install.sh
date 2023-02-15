mkdir -pv $DEST/etc
touch $DEST/etc/ld.so.conf
sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile
make DESTDIR=$DEST install
sed '/RTLDLIST=/s@/usr@@g' -i $DEST/usr/bin/ldd
cp -v ../nscd/nscd.conf $DEST/etc/nscd.conf
mkdir -pv $DEST/var/cache/nscd

mkdir -pv $DEST/usr/lib/locale
$DEST/usr/bin/localedef --no-archive -i POSIX -f UTF-8 $DEST/usr/lib/locale/C.utf8 2> /dev/null || true
$DEST/usr/bin/localedef --no-archive -i cs_CZ -f UTF-8 $DEST/usr/lib/locale/cs_CZ.utf8
$DEST/usr/bin/localedef --no-archive -i de_DE -f ISO-8859-1 $DEST/usr/lib/locale/de_DE
$DEST/usr/bin/localedef --no-archive -i de_DE@euro -f ISO-8859-15 $DEST/usr/lib/locale/de_DE@euro
$DEST/usr/bin/localedef --no-archive -i de_DE -f UTF-8 $DEST/usr/lib/locale/de_DE.utf8
$DEST/usr/bin/localedef --no-archive -i el_GR -f ISO-8859-7 $DEST/usr/lib/locale/el_GR
$DEST/usr/bin/localedef --no-archive -i en_GB -f ISO-8859-1 $DEST/usr/lib/locale/en_GB
$DEST/usr/bin/localedef --no-archive -i en_GB -f UTF-8 $DEST/usr/lib/locale/en_GB.utf8
$DEST/usr/bin/localedef --no-archive -i en_HK -f ISO-8859-1 $DEST/usr/lib/locale/en_HK
$DEST/usr/bin/localedef --no-archive -i en_PH -f ISO-8859-1 $DEST/usr/lib/locale/en_PH
$DEST/usr/bin/localedef --no-archive -i en_US -f ISO-8859-1 $DEST/usr/lib/locale/en_US
$DEST/usr/bin/localedef --no-archive -i en_US -f UTF-8 $DEST/usr/lib/locale/en_US.utf8
$DEST/usr/bin/localedef --no-archive -i es_ES -f ISO-8859-15 $DEST/usr/lib/locale/es_ES@euro
$DEST/usr/bin/localedef --no-archive -i es_MX -f ISO-8859-1 $DEST/usr/lib/locale/es_MX
$DEST/usr/bin/localedef --no-archive -i fa_IR -f UTF-8 $DEST/usr/lib/locale/fa_IR
$DEST/usr/bin/localedef --no-archive -i fr_FR -f ISO-8859-1 $DEST/usr/lib/locale/fr_FR
$DEST/usr/bin/localedef --no-archive -i fr_FR@euro -f ISO-8859-15 $DEST/usr/lib/locale/fr_FR@euro
$DEST/usr/bin/localedef --no-archive -i fr_FR -f UTF-8 $DEST/usr/lib/locale/fr_FR.utf8
$DEST/usr/bin/localedef --no-archive -i is_IS -f ISO-8859-1 $DEST/usr/lib/locale/is_IS
$DEST/usr/bin/localedef --no-archive -i is_IS -f UTF-8 $DEST/usr/lib/locale/is_IS.utf8
$DEST/usr/bin/localedef --no-archive -i it_IT -f ISO-8859-1 $DEST/usr/lib/locale/it_IT
$DEST/usr/bin/localedef --no-archive -i it_IT -f ISO-8859-15 $DEST/usr/lib/locale/it_IT@euro
$DEST/usr/bin/localedef --no-archive -i it_IT -f UTF-8 $DEST/usr/lib/locale/it_IT.utf8
$DEST/usr/bin/localedef --no-archive -i ja_JP -f EUC-JP $DEST/usr/lib/locale/ja_JP
$DEST/usr/bin/localedef --no-archive -i ja_JP -f SHIFT_JIS $DEST/usr/lib/locale/ja_JP.sjis 2> /dev/null || true
$DEST/usr/bin/localedef --no-archive -i ja_JP -f UTF-8 $DEST/usr/lib/locale/ja_JP.utf8
$DEST/usr/bin/localedef --no-archive -i nl_NL@euro -f ISO-8859-15 $DEST/usr/lib/locale/nl_NL@euro
$DEST/usr/bin/localedef --no-archive -i ru_RU -f KOI8-R $DEST/usr/lib/locale/ru_RU.koi8r
$DEST/usr/bin/localedef --no-archive -i ru_RU -f UTF-8 $DEST/usr/lib/locale/ru_RU.utf8
$DEST/usr/bin/localedef --no-archive -i se_NO -f UTF-8 $DEST/usr/lib/locale/se_NO.utf8
$DEST/usr/bin/localedef --no-archive -i ta_IN -f UTF-8 $DEST/usr/lib/locale/ta_IN.utf8
$DEST/usr/bin/localedef --no-archive -i tr_TR -f UTF-8 $DEST/usr/lib/locale/tr_TR.utf8
$DEST/usr/bin/localedef --no-archive -i zh_CN -f GB18030 $DEST/usr/lib/locale/zh_CN.gb18030
$DEST/usr/bin/localedef --no-archive -i zh_HK -f BIG5-HKSCS $DEST/usr/lib/locale/zh_HK.big5hkscs
$DEST/usr/bin/localedef --no-archive -i zh_TW -f UTF-8 $DEST/usr/lib/locale/zh_TW.utf8

cp ../../nsswitch.conf $DEST/etc/nsswitch.conf
ZONEINFO=$DEST/usr/share/zoneinfo
mkdir -pv $ZONEINFO/{posix,right}
for tz in etcetera southamerica northamerica europe africa \
          antarctica asia australasia backward; do
    $DEST/usr/sbin/zic -L /dev/null   -d $ZONEINFO       ${tz}
    $DEST/usr/sbin/zic -L /dev/null   -d $ZONEINFO/posix ${tz}
    $DEST/usr/sbin/zic -L leapseconds -d $ZONEINFO/right ${tz}
done
cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO
# Per the LFS instructions, we use New York TZ data for POSIX
$DEST/usr/sbin/zic -d $ZONEINFO -p America/New_York
unset ZONEINFO
# Here we're setting the default timezone of the end system...
ln -sfv /usr/share/zoneinfo/America/Los_Angeles $DEST/etc/localtime

cat > $DEST/etc/ld.so.conf << "EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib

EOF

