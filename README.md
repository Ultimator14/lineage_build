# LineageOS Build for Oneplus Nord avicii

This repository contains a build setup for building LineageOS on Gentoo Linux.

## Preparations

Clone this repository

```bash
cd path/to/clone
git clone <repo url todo>
```

Initialize the lineage repo in `./src` (this takes hours)

```bash
mkdir -p ./src
cd ./src
repo init -u https://github.com/LineageOS/android.git -b lineage-22.2 --git-lfs --no-clone-bundle
repo sync --force-sync --force-remove-dirty
repo forall -c "git lfs install"
repo forall -c "git lfs pull"
```

Create signing keys in `./.android-keys` for the build as described in the [LineageOS wiki](https://wiki.lineageos.org/signing_builds)

```bash
export LINDIR=$(pwd)
export SRCDIR=$LINDIR/src

cd $SRCDIR
# Create the subject as you wish
export SUBJECT='/C=<Your-Country>/ST=<YourState>/L=<YourLocality>/O=Android/OU=Android/CN=Android/emailAddress=<your@mail>'

mkdir ../.android-certs

for cert in bluetooth cyngn-app media networkstack platform releasekey sdk_sandbox shared testcert testkey verity; do \
    ./development/tools/make_key $LINDIR/.android-certs/$cert "$SUBJECT"; \
done

cp development/tools/make_key ../.android-certs/
sed -i 's|2048|4096|g' ../.android-certs/make_key

# Adapt this list to the one in the wiki, this is still from PixelExperience
for apex in com.android.adbd com.android.adservices com.android.adservices.api com.android.appsearch com.android.art com.android.bluetooth com.android.btservices com.android.cellbroadcast com.android.compos com.android.configinfrastructure com.android.connectivity.resources com.android.conscrypt com.android.devicelock com.android.extservices com.android.graphics.pdf com.android.hardware.biometrics.face.virtual com.android.hardware.biometrics.fingerprint.virtual com.android.hardware.boot com.android.hardware.cas com.android.hardware.wifi com.android.healthfitness com.android.hotspot2.osulogin com.android.i18n com.android.ipsec com.android.media com.android.media.swcodec com.android.mediaprovider com.android.nearby.halfsheet com.android.networkstack.tethering com.android.neuralnetworks com.android.ondevicepersonalization com.android.os.statsd com.android.permission com.android.resolv com.android.rkpd com.android.runtime com.android.safetycenter.resources com.android.scheduling com.android.sdkext com.android.support.apexer com.android.telephony com.android.telephonymodules com.android.tethering com.android.tzdata com.android.uwb com.android.uwb.resources com.android.virt com.android.vndk.current com.android.vndk.current.on_vendor com.android.wifi com.android.wifi.dialog com.android.wifi.resources com.google.pixel.camera.hal com.google.pixel.vibrator.hal com.qorvo.uwb; do \
    $LINDIR/.android-certs/make_key $LINDIR/.android-certs/$apex "$SUBJECT"; \
    openssl pkcs8 -in $LINDIR/.android-certs/$apex.pk8 -inform DER -nocrypt -out $LINDIR/.android-certs/$apex.pem; \
done
```

Install the required dependencies. See [LineageOS Wiki](https://wiki.lineageos.org/devices/avicii/build/)

## Adapt repositories

Edit `$SRCDIR/.repo/local_manifests/roomservice.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <project path="device/oneplus/avicii" remote="github" name="Ultimator14/android_device_oneplus_avicii" revision="lineage-22.2" />
  <project path="kernel/oneplus/sm7250" remote="github" name="Ultimator14/android_kernel_oneplus_sm7250" revision="lineage-22.2" />
  <project path="hardware/oplus" remote="github" name="Ultimator14/android_hardware_oplus" revision="lineage-22.2" />

  <remote  name="gitlab" fetch="https://gitlab.com/" review="review.lineageos.org" />
  <project path="vendor/oneplus/firmware" remote="gitlab" name="Ultimator/firmware_oneplus_avicii" revision="AC2003_11_F.23" />
  <project path="vendor/oneplus/avicii" remote="gitlab" name="Ultimator/vendor_oneplus_avicii" revision="lineage-22.2" />
  <project path="vendor/oneplus/apps" remote="gitlab" name="Ultimator/camera_oneplus_avicii" revision="lineage-22.2" />
</manifest>
```

Afterwards run `repo sync`

```bash
cd $SRCDIR
repo sync --force-sync --force-remove-dirty
```

Clone the additional repos

```bash
cd $SRCDIR
source build/envsetup.sh
```

## Start the build

This takes hours the first time.

```bash
cd $LINDIR
./build_lineage.sh
```
