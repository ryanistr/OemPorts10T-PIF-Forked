# Framework Play Integrity Fix (PIF) Forked to Fix cannot Find curl binary

framework-level implementation to pass Play Integrity checks on Android ROMs. 
Original by Danda420

## Features
- **Bootloader Spoof**  
  Uses an AOSP Keybox as a placeholder (for KeyAttestation app) but actually loads the keybox from `PIF.apk`.
- **GMS & Vending Properties Spoof**  
  Patches system properties to match certified devices for GMS & Vending.
- **Spoof Provider**  
  Spoofs AndroidKeystoreSpi.
- **Security Patch Spoof**  
  Spoofs Security Patch so that it passes strong integrity.
- **Vending SDK 32 Spoof**  
  Just incase. (this wont get enabled usually)
- **PIF.apk Updater**  
  Automatically fetches updated PIF.apk from the cloud.

---

## Setup

### 1. Clone or Download
Clone this repository or download the ZIP archive and extract it.


### 2. Install Dependencies

#### Arch Linux
```sh
sudo pacman -Syu --needed jre-openjdk android-tools zip unzip
```

#### RHEL / Fedora / CentOS / Alma / Rocky
```sh
sudo dnf install -y java-latest-openjdk android-tools zip unzip
# or
sudo yum install -y java-17-openjdk android-tools zip unzip
```

#### Debian / Ubuntu / Linux Mint
```sh
sudo apt-get update && sudo apt-get install -y openjdk-17-jre android-sdk-libsparse-utils android-sdk-platform-tools zip unzip
```

#### openSUSE / SLES
```sh
sudo zypper install -y java-latest-openjdk android-tools zip unzip
```

---

## Usage

1. Import all files from:
   - `ROM/system` → into your system partition  
   - `ROM/vendor` → into your vendor partition  

2. Add the required properties from `ROM/build.prop` to your device’s `build.prop`.  

3. Place `framework.jar` inside the `framework_patcher` folder.  

4. Run the patcher:
   ```sh
   ./patchframework.sh
   ```

5. Wait for the patching process to complete.  

6. Replace your system’s `framework.jar` with the patched version.  

7. Remove any files in system/framework named:
   ```
   boot-framework.*
   ```

---

## Notes
- framework.jar patch script is only for Linux x86_64. Android is not supported.
- This implementation will be updated whenever Google changes Play Integrity.  
- `PIF.apk` is updated if keys/properties get banned, just run `pif-updater`.
- Some of those Implementation Features is adjusted via PIF.apk bools/strings, so no need to worry about that.. i'll only enable and disable whats important for passing play integrity.
- On devices running **SELinux Enforcing**, you may need to add rules to address denials related to this patch and the `pif-updater`.  

---

