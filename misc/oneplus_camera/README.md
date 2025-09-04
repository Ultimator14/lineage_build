# Oneplus Camera patch

## Preparation

Select a keystore password and create a keystore

```bash
keytool -genkey -v -keystore onepluscamera.keystore -keyalg RSA -keysize 2048 -validity 365 -storepass <my-secret-password> -alias oneplus_chain
# CN=OnePlus, OU=SW, O=OnePlus, L=Shenzhen, ST=Guangdong, C=CN
```

Get the apk from `https://gitlab.com/Ultimator/camera_oneplus_avicii`, path `proprietary/system_ext/priv-app/OnePlusCamera`.

## Patch

Convert apk file to jar for reverse engineering with jd-gui:

```bash
d2j-dex2jar.sh OnePlusCamera.apk
```

Unpack apk

```bash
apktool d -o tracking/onepluscamera input.apk 
```

Path the apk

```bash
cd tracking
git init .
git add .
git commit -m "initial state"
# apply patches or do other changes
git apply ../patch1_linearmotor.diff
git apply ../patch2_autobrightness.diff
```

Repack apk

```bash
# if /tmp is mounted noexec, mount it exec here, required for repacking
#sudo mount -o remount,exec /tmp
apktool b -o OnePlusCamera_patched.apk tracking/onepluscamera
```

Sign jar

```bash
cp OnePlusCamera_patched_unsigned.apk patchme.apk
jarsigner -verbose -sigalg SHA256withRSA -digestalg SHA256 -keystore onepluscamera.keystore patchme.apk oneplus_chain
mv patchme.apk OnePlusCamera_patched_signed.apk
```
