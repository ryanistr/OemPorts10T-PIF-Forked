#!/bin/bash

dirnow=$PWD

if [[ ! -f $dirnow/framework.jar ]]; then
   echo "no framework.jar detected!"
   exit 1
fi

apkeditor() {
    jarfile=$dirnow/tool/APKEditor.jar
    javaOpts="-Xmx4096M -Dfile.encoding=utf-8 -Djdk.util.zip.disableZip64ExtraFieldValidation=true -Djdk.nio.zipfs.allowDotZipEntry=true"

    java $javaOpts -jar "$jarfile" "$@"
}

certificatechainPatch() {
 certificatechainPatch="
    .line $1
    invoke-static {}, Lcom/android/internal/util/danda/OemPorts10TUtils;->onEngineGetCertificateChain()V
"
}

instrumentationPatch() {
	returnline=$(expr $2 + 1)
	instrumentationPatch="    invoke-static {$1}, Lcom/android/internal/util/danda/OemPorts10TUtils;->onNewApplication(Landroid/content/Context;)V
    
    .line $returnline
    "
    
}

blSpoofPatch() {
	blSpoofPatch="    invoke-static {$1}, Lcom/android/internal/util/danda/OemPorts10TUtils;->genCertificateChain([Ljava/security/cert/Certificate;)[Ljava/security/cert/Certificate;
	
    move-result-object $1
    "
}

expressions_fix() {
	var=$1
	escaped_var=$(printf '%s\n' "$var" | sed 's/[\/&]/\\&/g')
	escaped_var=$(printf '%s\n' "$escaped_var" | sed 's/\[/\\[/g' | sed 's/\]/\\]/g' | sed 's/\./\\./g' | sed 's/;/\\;/g')
	echo $escaped_var
}


echo "unpacking framework.jar"
apkeditor d -i framework.jar -o frmwrk > /dev/null 2>&1
mv framework.jar frmwrk.jar

echo "patching framework.jar"

keystorespiclassfile=$(find frmwrk/ -name 'AndroidKeyStoreSpi.smali' -printf '%P\n')
utilfolder=$(find frmwrk/ -name "util" -type d -printf '%P\n' | grep com/android/internal/util | tail -n 1)
instrumentationsmali=$(find frmwrk/ -name "Instrumentation.smali"  -printf '%P\n')

engineGetCertMethod=$(expressions_fix "$(grep 'engineGetCertificateChain(' frmwrk/$keystorespiclassfile)")
newAppMethod1=$(expressions_fix "$(grep 'newApplication(Ljava/lang/ClassLoader;' frmwrk/$instrumentationsmali)")
newAppMethod2=$(expressions_fix "$(grep 'newApplication(Ljava/lang/Class;' frmwrk/$instrumentationsmali)")

sed -n "/^${engineGetCertMethod}/,/^\.end method/p" frmwrk/$keystorespiclassfile > tmp_keystore
sed -i "/^${engineGetCertMethod}/,/^\.end method/d" frmwrk/$keystorespiclassfile

sed -n "/^${newAppMethod1}/,/^\.end method/p" frmwrk/$instrumentationsmali > inst1
sed -i "/^${newAppMethod1}/,/^\.end method/d" frmwrk/$instrumentationsmali

sed -n "/^${newAppMethod2}/,/^\.end method/p" frmwrk/$instrumentationsmali > inst2
sed -i "/^${newAppMethod2}/,/^\.end method/d" frmwrk/$instrumentationsmali

inst1_insert=$(expr $(wc -l < inst1) - 2)
instreg=$(grep "Landroid/app/Application;->attach(Landroid/content/Context;)V" inst1 | awk '{print $3}' | sed 's/},//')
instline=$(expr $(grep -r ".line" inst1 | tail -n 1 | awk '{print $2}') + 1)
instrumentationPatch $instreg $instline
echo "$instrumentationPatch" | sed -i "${inst1_insert}r /dev/stdin" inst1

inst2_insert=$(expr $(wc -l < inst2) - 2)
instreg=$(grep "Landroid/app/Application;->attach(Landroid/content/Context;)V" inst2 | awk '{print $3}' | sed 's/},//')
instline=$(expr $(grep -r ".line" inst2 | tail -n 1 | awk '{print $2}') + 1)
instrumentationPatch $instreg $instline
echo "$instrumentationPatch" | sed -i "${inst2_insert}r /dev/stdin" inst2

kstoreline=$(expr $(grep -r ".line" tmp_keystore | head -n 1 | awk '{print $2}') - 2)
certificatechainPatch $kstoreline
echo "$certificatechainPatch" | sed -i '4r /dev/stdin' tmp_keystore

lastaput=$(grep "aput-object" tmp_keystore | tail -n 1)
leafcert=$(echo $lastaput | awk '{print $3}' | awk -F',' '{print $1}')
blspoof_insert=$(expr $(grep -n "$lastaput" tmp_keystore | awk -F':' '{print $1}') + 1)
blSpoofPatch $leafcert
echo "$blSpoofPatch" | sed -i "${blspoof_insert}r /dev/stdin" tmp_keystore

cat inst1 >> frmwrk/$instrumentationsmali
cat inst2 >> frmwrk/$instrumentationsmali
cat tmp_keystore >> frmwrk/$keystorespiclassfile

rm -rf inst1
rm -rf inst2
rm -rf tmp_keystore

echo "repacking framework.jar classes"

apkeditor b -i frmwrk > /dev/null 2>&1
unzip frmwrk_out.apk 'classes*.dex' -d frmwrk > /dev/null 2>&1

rm -rf frmwrk/.cache
patchclass=$(expr $(find frmwrk/ -type f -name '*.dex' | wc -l) + 1)
cp PIF/classes.dex frmwrk/classes${patchclass}.dex

cd frmwrk
echo "zipping class"
zip -qr0 -t 07302003 $dirnow/frmwrk.jar classes*
cd $dirnow
echo "zipaligning framework.jar"
zipalign -v 4 frmwrk.jar framework.jar > /dev/null
rm -rf frmwrk.jar frmwrk frmwrk_out.apk
