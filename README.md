# Tilt Hydrometer App

The Tilt Hydrometer App is a Flutter-based application designed to work with the Tilt Hydrometer device. It provides an interface to monitor and analyze data from the hydrometer.

## Features

- Cross-platform Flutter app (currently tested only on Android).
- Data visualization using `fl_chart`.
- File management with `path_provider` and `open_filex`.
- Clean and responsive UI built with Flutter.

## Platforms

The app is built with Flutter and supports multiple platforms. However, it is currently **only tested on Android**. Support for other platforms (iOS, Web, Windows, Linux) is planned but not yet verified.

## Requirements

- **Flutter SDK**: Latest stable version.
- **Development Environment**: Android Studio or Visual Studio Code with Flutter plugins.
- **Java Development Kit (JDK)**: Required by Android Studio and for using `keytool`.
- **Android Device or Emulator**: For testing purposes.

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/Taner-Y-Banth/tilt-hydrometer.git
   cd tilt-hydrometer/tilt_app
   ```

2. Get the Flutter dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app in debug mode:
   ```bash
   flutter run
   ```

## Building for Release (Android)

To build a release version of the Android app (e.g., an App Bundle for Google Play), you need to sign it. This project uses environment variables read by Gradle, populated from a `key.properties` file via a helper script.

### 1. Generate an Upload Keystore

If you don't already have one, create a keystore using the `keytool` command (part of the JDK):

```bash
keytool -genkey -v -keystore <path-to-your-keystore>/release-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias <your-key-alias>
```

- Replace `<path-to-your-keystore>` with the directory where you want to save the file (e.g., `~/.android/keystores`).
- Replace `<your-key-alias>` with an alias name you choose (e.g., `upload`).

You will be prompted to create passwords for the keystore and the key. Remember these.

### 2. Create `key.properties` File

You need to create a file named `key.properties` inside the `android` directory of the Flutter project (`tilt-hydrometer/tilt_app/android/key.properties`).

**IMPORTANT**: Add `key.properties` to your `.gitignore` file to prevent accidentally committing your credentials!

Example `.gitignore` entry:
```
/android/key.properties
```

The `key.properties` file should have the following format, using the details from the keystore you generated or already have:

```properties
storePassword=<your_keystore_password>
keyPassword=<your_key_password>
keyAlias=<your_key_alias>
storeFile=<absolute_path_to_your_keystore_file>/release-keystore.jks
```

- Replace placeholders with your actual passwords, alias, and the full, absolute path to your `.jks` file.
- Use `/` for paths even on Windows, or escape backslashes (`\\`).

### 3. Use the Helper Script to Set Environment Variables

A helper script (`set_signing_env.sh`) can be added to the `android` directory to read `key.properties` and set the required environment variables (`KEYSTORE_FILE`, `KEYSTORE_PASS`, `KEY_ALIAS`, `KEY_PASS`) for the current terminal session.

#### For Linux/macOS:
1. Create the script `android/set_signing_env.sh`:
   ```bash
   #!/bin/bash
   while IFS='=' read -r key value; do
       export "$key"="$value"
   done < "$(dirname "$0")/key.properties"
   ```

2. Make the script executable:
   ```bash
   chmod +x android/set_signing_env.sh
   ```

3. Source the script from the project root directory:
   ```bash
   source android/set_signing_env.sh
   ```

#### For Windows/PowerShell:
Create a similar script (`set_signing_env.ps1`) and run it:
```powershell
Get-Content android\key.properties | ForEach-Object {
    $parts = $_ -split '='
    [System.Environment]::SetEnvironmentVariable($parts[0], $parts[1])
}
```

Run the script:
```powershell
.\android\set_signing_env.ps1
```

### 4. Build the Release App Bundle

Once the environment variables are set, you can build the app bundle:

```bash
flutter build appbundle --release
```

The output `.aab` file will be located in:
```
build/app/outputs/bundle/release/
```

Alternatively, you can combine steps 3 and 4:
```bash
source android/set_signing_env.sh && flutter build appbundle --release
```

## License

This project is licensed under the MIT License. See the [LICENSE](../LICENSE) file for details.