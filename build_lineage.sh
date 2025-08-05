#!/bin/bash

set -e

function patchfile {
	# SRCDIR = $1
	# Patchfile = $2
	cd "$SRCDIR"/"$1"
	git reset
	git checkout .
	for pf in "${@:2}"
	do
		git apply "$PATCHDIR"/"$pf"
	done

	cd $SRCDIR
}

# Mount /tmp exec to prevent sqlite link error
echo "Please enter password to mount /tmp exec"
sudo mount -o remount,exec /tmp

LINDIR=$(pwd)
SRCDIR=$LINDIR/src
PATCHDIR=$LINDIR/patches

# set tmpdir to avoid error due to noexexc mounted /tmp
# Even if /tmp might be required elsewhere, keep TMPDIR here because after signing, simg2img
# uses TMPDIR to extract system img and /tmp is limited to 4G because it's stored in RAM
# error explanation see: https://netdex.org/2020/04/13/building-lineageos-17-1-on-archlinux/
export TMPDIR="${HOME}/.local/tmp"

# Set custom TMPDIR to prevent errors due to too small or noexexc mounted /tmp dir
export _JAVA_OPTIONS=-Djava.io.tmpdir=$TMPDIR
#export _JAVA_OPTIONS="$_JAVA_OPTIONS -Djava.io.tmpdir=$TMPDIR"

# sync sources
cd $SRCDIR
repo sync --force-sync --force-remove-dirty


# Important
# After initial sync install and update lfs for all projects
# repo forall -c "git lfs install"
# repo forall -c "git lfs pull"

# sync lfs as this is not done by repo sync
repo forall -c "git lfs pull"

# clean kernel source (skip because it breaks build (m clean removes build directory)
#source build/envsetup.sh
#m clean
#cd $SRCDIR/kernel/oneplus/sm7250
#make mrproper
#cd $SRCDIR/build/tools
#git reset
#git checkout .
#cd $SRCDIR

# config
source build/envsetup.sh

# Disable java vars to force bundled java
unset JAVA_HOME
unset JAVAC
unset LEX

# out/soong/host/linux-x86/bin/art-apex-tester searches for python version.
# Search is broken on gentoo due to the use of python-exec, this line gets
# the script to return the correct search path and therefore avoids the
# .path_interposer: no python-exec wrapped executable found in /usr/lib/python-exec
# error thrown by gentoos python-exec file

export PATH=/usr/lib/python-exec/python3.13:$PATH

# Enable caching
export USE_CCACHE=1
export CCACHE_COMPRESS=1

# prevent "libstagefright_soft_aacdec" depends on undefined module "libFraunhoferAAC" error (obsolete)
#export ALLOW_MISSING_DEPENDENCIES=true

# prepare build
breakfast avicii
ccache -M 50G
croot

#
# Note: not required for the latest avicii build as the developer uploaded the proprietary blobs to github
#
# Extract files:
# Files can be extracted from the original lineageos rom (zip downloadable)
# OR from a device having root or setenforce 0
# Maybe extract-files.sh must be edited (rename patchelfv8 to patchelf)
# Some patches used in the extraction phase might require 'mount -o remount,size=10G,exec /tmp'
#breakfast avicii
#cd $SRCDIR/device/oneplus/avicii
#./extract-files.sh ~/Downloads/system
#cd $SRCDIR
# 
# Afterwards, maybe copy missing files from ORIGINAL ROM zip
# cp <file> $SRCDIR/vendor/oneplus/avicii/proprietary/<maindir>/<subdir>
# e.g. <originalromdir>/system/vendor/lib64/libsecureui_svcsock.so $SRCDIR/vendor/oneplus/avicii/proprietary/vendor/lib64/.
#

echo "Build environment prepared. Press enter to patch the source"
read -r

# apply patches
patchfile packages/apps/Dialer features/call_recording.diff								# enable call recording
patchfile system/core features/symlink.diff												# create symlinks from / to /system (usr for gentoo, xbin for busybox) + fix write access to external ext4 sdcard
patchfile system/sepolicy features/symlink_selinux.diff                              	# fix selinux permissions for symlinks
patchfile packages/apps/Settings run_fix/add_ringtone-hook_support.diff	                # make other apps able to hook into 'choose ringtone' procedure, don't lock to system picker only

# Already patched via git
#patchfile device/oneplus/avicii run_fix/tui.diff run_fix/cannot_link_executable.diff run_fix/dlopen.diff 	# fix logcat errors of tui_comm service, fix bootloop, fix dlopen errors on early boot
#patchfile hardware/oplus run_fix/wakeup.diff build_fix/duplicate_genfs.diff				# fix wakeup selinux denials, fix build errors due to duplicate definitions
#patchfile device/oneplus/avicii build_fix/fully_clone.diff

# We use NikGapps
#patchfile device/oneplus/avicii features/gapps.diff 									# build gapps alongside lineage

### unused ###
#patchfile kernel/bq/msm8953 kernel_config.diff safety_net.diff		# add overlays_fs (and some more) to kernel options and fix safetynet failure
#rm ${SRCDIR}/system/ca-certificates/files/0943c77e.0				# remove additional file to prevent failing of the following patch
#patchfile system/ca-certificates hso_cert.diff						# include HSO root ca for mail
#patchfile device/bq/msm8953-common proximity_tap_to_wake.diff		# increase timeout for tap to wake proximity sensor
#rm ${SRCDIR}/system/core/rootdir/etc/fstab.custom					# remove additional file to prevent failing of the following patch
#patchfile system/core system_rw.diff 								# automaticly mount overlayfs at boot
#patchfile device/bq/msm8953-common fstab.custom.diff
#patchfile system/sepolicy fs_use.diff 								# add overlay to fs_use (now included per default)
#patchfile frameworks/base headphone_keylayout_fix.diff				# fix headset ghost input (selecting everything) by bukar headset
##############


echo "Source prepared. Press enter to start build"
read -r

# build (limit to 12 cores to prevent OOM)
mka target-files-package otatools -j12

# Sign builds
croot
#patchfile build/tools rewrite_search_dir.diff (not needed for lineage >=20)

croot
sign_target_files_apks -o -d $LINDIR/.android-certs \
    --extra_apks AdServicesApk.apk=$LINDIR/.android-certs/releasekey \
    --extra_apks HalfSheetUX.apk=$LINDIR/.android-certs/releasekey \
    --extra_apks OsuLogin.apk=$LINDIR/.android-certs/releasekey \
    --extra_apks SafetyCenterResources.apk=$LINDIR/.android-certs/releasekey \
    --extra_apks ServiceConnectivityResources.apk=$LINDIR/.android-certs/releasekey \
    --extra_apks ServiceUwbResources.apk=$LINDIR/.android-certs/releasekey \
    --extra_apks ServiceWifiResources.apk=$LINDIR/.android-certs/releasekey \
    --extra_apks WifiDialog.apk=$LINDIR/.android-certs/releasekey \
    --extra_apks com.android.adbd.apex=$LINDIR/.android-certs/com.android.adbd \
    --extra_apks com.android.adservices.apex=$LINDIR/.android-certs/com.android.adservices \
    --extra_apks com.android.adservices.api.apex=$LINDIR/.android-certs/com.android.adservices.api \
    --extra_apks com.android.appsearch.apex=$LINDIR/.android-certs/com.android.appsearch \
    --extra_apks com.android.art.apex=$LINDIR/.android-certs/com.android.art \
    --extra_apks com.android.bluetooth.apex=$LINDIR/.android-certs/com.android.bluetooth \
    --extra_apks com.android.btservices.apex=$LINDIR/.android-certs/com.android.btservices \
    --extra_apks com.android.cellbroadcast.apex=$LINDIR/.android-certs/com.android.cellbroadcast \
    --extra_apks com.android.compos.apex=$LINDIR/.android-certs/com.android.compos \
    --extra_apks com.android.configinfrastructure.apex=$LINDIR/.android-certs/com.android.configinfrastructure \
    --extra_apks com.android.connectivity.resources.apex=$LINDIR/.android-certs/com.android.connectivity.resources \
    --extra_apks com.android.conscrypt.apex=$LINDIR/.android-certs/com.android.conscrypt \
    --extra_apks com.android.devicelock.apex=$LINDIR/.android-certs/com.android.devicelock \
    --extra_apks com.android.extservices.apex=$LINDIR/.android-certs/com.android.extservices \
    --extra_apks com.android.graphics.pdf.apex=$LINDIR/.android-certs/com.android.graphics.pdf \
    --extra_apks com.android.hardware.biometrics.face.virtual.apex=$LINDIR/.android-certs/com.android.hardware.biometrics.face.virtual \
    --extra_apks com.android.hardware.biometrics.fingerprint.virtual.apex=$LINDIR/.android-certs/com.android.hardware.biometrics.fingerprint.virtual \
    --extra_apks com.android.hardware.boot.apex=$LINDIR/.android-certs/com.android.hardware.boot \
    --extra_apks com.android.hardware.cas.apex=$LINDIR/.android-certs/com.android.hardware.cas \
    --extra_apks com.android.hardware.wifi.apex=$LINDIR/.android-certs/com.android.hardware.wifi \
    --extra_apks com.android.healthfitness.apex=$LINDIR/.android-certs/com.android.healthfitness \
    --extra_apks com.android.hotspot2.osulogin.apex=$LINDIR/.android-certs/com.android.hotspot2.osulogin \
    --extra_apks com.android.i18n.apex=$LINDIR/.android-certs/com.android.i18n \
    --extra_apks com.android.ipsec.apex=$LINDIR/.android-certs/com.android.ipsec \
    --extra_apks com.android.media.apex=$LINDIR/.android-certs/com.android.media \
    --extra_apks com.android.media.swcodec.apex=$LINDIR/.android-certs/com.android.media.swcodec \
    --extra_apks com.android.mediaprovider.apex=$LINDIR/.android-certs/com.android.mediaprovider \
    --extra_apks com.android.nearby.halfsheet.apex=$LINDIR/.android-certs/com.android.nearby.halfsheet \
    --extra_apks com.android.networkstack.tethering.apex=$LINDIR/.android-certs/com.android.networkstack.tethering \
    --extra_apks com.android.neuralnetworks.apex=$LINDIR/.android-certs/com.android.neuralnetworks \
    --extra_apks com.android.ondevicepersonalization.apex=$LINDIR/.android-certs/com.android.ondevicepersonalization \
    --extra_apks com.android.os.statsd.apex=$LINDIR/.android-certs/com.android.os.statsd \
    --extra_apks com.android.permission.apex=$LINDIR/.android-certs/com.android.permission \
    --extra_apks com.android.resolv.apex=$LINDIR/.android-certs/com.android.resolv \
    --extra_apks com.android.rkpd.apex=$LINDIR/.android-certs/com.android.rkpd \
    --extra_apks com.android.runtime.apex=$LINDIR/.android-certs/com.android.runtime \
    --extra_apks com.android.safetycenter.resources.apex=$LINDIR/.android-certs/com.android.safetycenter.resources \
    --extra_apks com.android.scheduling.apex=$LINDIR/.android-certs/com.android.scheduling \
    --extra_apks com.android.sdkext.apex=$LINDIR/.android-certs/com.android.sdkext \
    --extra_apks com.android.support.apexer.apex=$LINDIR/.android-certs/com.android.support.apexer \
    --extra_apks com.android.telephony.apex=$LINDIR/.android-certs/com.android.telephony \
    --extra_apks com.android.telephonymodules.apex=$LINDIR/.android-certs/com.android.telephonymodules \
    --extra_apks com.android.tethering.apex=$LINDIR/.android-certs/com.android.tethering \
    --extra_apks com.android.tzdata.apex=$LINDIR/.android-certs/com.android.tzdata \
    --extra_apks com.android.uwb.apex=$LINDIR/.android-certs/com.android.uwb \
    --extra_apks com.android.uwb.resources.apex=$LINDIR/.android-certs/com.android.uwb.resources \
    --extra_apks com.android.virt.apex=$LINDIR/.android-certs/com.android.virt \
    --extra_apks com.android.vndk.current.apex=$LINDIR/.android-certs/com.android.vndk.current \
    --extra_apks com.android.vndk.current.on_vendor.apex=$LINDIR/.android-certs/com.android.vndk.current.on_vendor \
    --extra_apks com.android.wifi.apex=$LINDIR/.android-certs/com.android.wifi \
    --extra_apks com.android.wifi.dialog.apex=$LINDIR/.android-certs/com.android.wifi.dialog \
    --extra_apks com.android.wifi.resources.apex=$LINDIR/.android-certs/com.android.wifi.resources \
    --extra_apks com.google.pixel.camera.hal.apex=$LINDIR/.android-certs/com.google.pixel.camera.hal \
    --extra_apks com.google.pixel.vibrator.hal.apex=$LINDIR/.android-certs/com.google.pixel.vibrator.hal \
    --extra_apks com.qorvo.uwb.apex=$LINDIR/.android-certs/com.qorvo.uwb \
    --extra_apex_payload_key com.android.adbd.apex=$LINDIR/.android-certs/com.android.adbd.pem \
    --extra_apex_payload_key com.android.adservices.apex=$LINDIR/.android-certs/com.android.adservices.pem \
    --extra_apex_payload_key com.android.adservices.api.apex=$LINDIR/.android-certs/com.android.adservices.api.pem \
    --extra_apex_payload_key com.android.appsearch.apex=$LINDIR/.android-certs/com.android.appsearch.pem \
    --extra_apex_payload_key com.android.art.apex=$LINDIR/.android-certs/com.android.art.pem \
    --extra_apex_payload_key com.android.bluetooth.apex=$LINDIR/.android-certs/com.android.bluetooth.pem \
    --extra_apex_payload_key com.android.btservices.apex=$LINDIR/.android-certs/com.android.btservices.pem \
    --extra_apex_payload_key com.android.cellbroadcast.apex=$LINDIR/.android-certs/com.android.cellbroadcast.pem \
    --extra_apex_payload_key com.android.compos.apex=$LINDIR/.android-certs/com.android.compos.pem \
    --extra_apex_payload_key com.android.configinfrastructure.apex=$LINDIR/.android-certs/com.android.configinfrastructure.pem \
    --extra_apex_payload_key com.android.connectivity.resources.apex=$LINDIR/.android-certs/com.android.connectivity.resources.pem \
    --extra_apex_payload_key com.android.conscrypt.apex=$LINDIR/.android-certs/com.android.conscrypt.pem \
    --extra_apex_payload_key com.android.devicelock.apex=$LINDIR/.android-certs/com.android.devicelock.pem \
    --extra_apex_payload_key com.android.extservices.apex=$LINDIR/.android-certs/com.android.extservices.pem \
    --extra_apex_payload_key com.android.graphics.pdf.apex=$LINDIR/.android-certs/com.android.graphics.pdf.pem \
    --extra_apex_payload_key com.android.hardware.biometrics.face.virtual.apex=$LINDIR/.android-certs/com.android.hardware.biometrics.face.virtual.pem \
    --extra_apex_payload_key com.android.hardware.biometrics.fingerprint.virtual.apex=$LINDIR/.android-certs/com.android.hardware.biometrics.fingerprint.virtual.pem \
    --extra_apex_payload_key com.android.hardware.boot.apex=$LINDIR/.android-certs/com.android.hardware.boot.pem \
    --extra_apex_payload_key com.android.hardware.cas.apex=$LINDIR/.android-certs/com.android.hardware.cas.pem \
    --extra_apex_payload_key com.android.hardware.wifi.apex=$LINDIR/.android-certs/com.android.hardware.wifi.pem \
    --extra_apex_payload_key com.android.healthfitness.apex=$LINDIR/.android-certs/com.android.healthfitness.pem \
    --extra_apex_payload_key com.android.hotspot2.osulogin.apex=$LINDIR/.android-certs/com.android.hotspot2.osulogin.pem \
    --extra_apex_payload_key com.android.i18n.apex=$LINDIR/.android-certs/com.android.i18n.pem \
    --extra_apex_payload_key com.android.ipsec.apex=$LINDIR/.android-certs/com.android.ipsec.pem \
    --extra_apex_payload_key com.android.media.apex=$LINDIR/.android-certs/com.android.media.pem \
    --extra_apex_payload_key com.android.media.swcodec.apex=$LINDIR/.android-certs/com.android.media.swcodec.pem \
    --extra_apex_payload_key com.android.mediaprovider.apex=$LINDIR/.android-certs/com.android.mediaprovider.pem \
    --extra_apex_payload_key com.android.nearby.halfsheet.apex=$LINDIR/.android-certs/com.android.nearby.halfsheet.pem \
    --extra_apex_payload_key com.android.networkstack.tethering.apex=$LINDIR/.android-certs/com.android.networkstack.tethering.pem \
    --extra_apex_payload_key com.android.neuralnetworks.apex=$LINDIR/.android-certs/com.android.neuralnetworks.pem \
    --extra_apex_payload_key com.android.ondevicepersonalization.apex=$LINDIR/.android-certs/com.android.ondevicepersonalization.pem \
    --extra_apex_payload_key com.android.os.statsd.apex=$LINDIR/.android-certs/com.android.os.statsd.pem \
    --extra_apex_payload_key com.android.permission.apex=$LINDIR/.android-certs/com.android.permission.pem \
    --extra_apex_payload_key com.android.resolv.apex=$LINDIR/.android-certs/com.android.resolv.pem \
    --extra_apex_payload_key com.android.rkpd.apex=$LINDIR/.android-certs/com.android.rkpd.pem \
    --extra_apex_payload_key com.android.runtime.apex=$LINDIR/.android-certs/com.android.runtime.pem \
    --extra_apex_payload_key com.android.safetycenter.resources.apex=$LINDIR/.android-certs/com.android.safetycenter.resources.pem \
    --extra_apex_payload_key com.android.scheduling.apex=$LINDIR/.android-certs/com.android.scheduling.pem \
    --extra_apex_payload_key com.android.sdkext.apex=$LINDIR/.android-certs/com.android.sdkext.pem \
    --extra_apex_payload_key com.android.support.apexer.apex=$LINDIR/.android-certs/com.android.support.apexer.pem \
    --extra_apex_payload_key com.android.telephony.apex=$LINDIR/.android-certs/com.android.telephony.pem \
    --extra_apex_payload_key com.android.telephonymodules.apex=$LINDIR/.android-certs/com.android.telephonymodules.pem \
    --extra_apex_payload_key com.android.tethering.apex=$LINDIR/.android-certs/com.android.tethering.pem \
    --extra_apex_payload_key com.android.tzdata.apex=$LINDIR/.android-certs/com.android.tzdata.pem \
    --extra_apex_payload_key com.android.uwb.apex=$LINDIR/.android-certs/com.android.uwb.pem \
    --extra_apex_payload_key com.android.uwb.resources.apex=$LINDIR/.android-certs/com.android.uwb.resources.pem \
    --extra_apex_payload_key com.android.virt.apex=$LINDIR/.android-certs/com.android.virt.pem \
    --extra_apex_payload_key com.android.vndk.current.apex=$LINDIR/.android-certs/com.android.vndk.current.pem \
    --extra_apex_payload_key com.android.vndk.current.on_vendor.apex=$LINDIR/.android-certs/com.android.vndk.current.on_vendor.pem \
    --extra_apex_payload_key com.android.wifi.apex=$LINDIR/.android-certs/com.android.wifi.pem \
    --extra_apex_payload_key com.android.wifi.dialog.apex=$LINDIR/.android-certs/com.android.wifi.dialog.pem \
    --extra_apex_payload_key com.android.wifi.resources.apex=$LINDIR/.android-certs/com.android.wifi.resources.pem \
    --extra_apex_payload_key com.google.pixel.camera.hal.apex=$LINDIR/.android-certs/com.google.pixel.camera.hal.pem \
    --extra_apex_payload_key com.google.pixel.vibrator.hal.apex=$LINDIR/.android-certs/com.google.pixel.vibrator.hal.pem \
    --extra_apex_payload_key com.qorvo.uwb.apex=$LINDIR/.android-certs/com.qorvo.uwb.pem \
    $OUT/obj/PACKAGING/target_files_intermediates/*-target_files*.zip \
	$SRCDIR/out/target/product/avicii/signed-target_files.zip


ota_from_target_files -k $LINDIR/.android-certs/releasekey --block --backup=true \
	$SRCDIR/out/target/product/avicii/signed-target_files.zip \
	$SRCDIR/out/target/product/avicii/signed-ota_update.zip

# ReMount /tmp noexec for security
echo "Please enter password to mount /tmp noexec"
sudo mount -o remount,noexec /tmp

echo "Successfully built ROM"
echo "---------------------------------------"
echo "Flashable zip: $SRCDIR/out/target/product/avicii/signed-ota_update.zip"
echo "Partitions: $SRCDIR/out/target/product/avicii/signed-target_files.zip"
echo "---------------------------------------"
