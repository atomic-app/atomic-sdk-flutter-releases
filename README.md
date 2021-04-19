# Flutter SDK

## Introduction

The Flutter SDK wraps the Atomic iOS and Android SDKs, allowing you to use them in your Flutter apps.

The Flutter SDK supports iOS 9 and above, and Android 5.0 and above.

## Installation

The Flutter SDK is hosted in a private repository on Github. To gain access to this private repository, send your Github user name to your Atomic representative.

Once you have access, add the Git repository to your `pubspec.yaml` file and run `flutter pub get`:

```yaml
dependencies:
  atomic_sdk_flutter:
    git:
      url: git@github.com:atomic-app/atomic-sdk-flutter-releases.git
      ref: 0.1.0
```

The `ref` property should be set to the version number of the Flutter SDK that you wish to use.

You also need to make the following changes for each platform:

**iOS**

1. Open the `Podfile` in your app's `ios` subdirectory, and add the following lines underneath the `platform` declaration:

```ruby
source 'https://github.com/atomic-app/action-cards-ios-sdk-specs.git'
source 'https://github.com/CocoaPods/Specs.git'
```

2. In the same directory, run `pod install` to fetch the Atomic SDK dependency. If you are unable to run this command, check that you have [Cocoapods](https://cocoapods.org/) installed.

**Android**

1. Add the Atomic Android SDK repository to your build configuration. Open `android/build.gradle` and add the following under `allprojects` → `repositories`, replacing `<USERNAME>` and `<PERSONAL_ACCESS_TOKEN>` with the corresponding values from your Github account.

?> **Note:** The password in your Gradle file is your Github personal access token, rather than your login password. To obtain a personal access token, [follow these instructions](https://docs.github.com/en/packages/learn-github-packages/about-github-packages#authenticating-to-github-packages).

```java
maven {
  url  "https://maven.pkg.github.com/atomic-app/action-cards-android-sdk-releases"
  credentials {
      username '<USERNAME>'
      password '<PERSONAL_ACCESS_TOKEN>'
  }
}
```

2. Bump your minimum SDK version. In your `android/app/build.gradle` file, change the value of `minSdkVersion` to `21` if the current value is less than this.

3. Add the Material dependency to your app. Add the following to the `dependencies` block in your `android/app/build.gradle` file:

```java
implementation 'com.google.android.material:material:1.2.1'
```

Change the `parent` attribute for `NormalTheme` and `LaunchTheme` to `Theme.MaterialComponents.Light.NoActionBar` in the following files:

- `android/app/src/main/res/values/styles.xml`
- `android/app/src/main/res/values-night/styles.xml`

```xml
<style name="LaunchTheme" parent="Theme.MaterialComponents.Light.NoActionBar">
    ...
</style>

<style name="NormalTheme" parent="Theme.MaterialComponents.Light.NoActionBar">
    ...
</style>
```

4. Open your `MainActivity` class inside your app project, and change the base class from `FlutterActivity` to `AACFlutterActivity`:

```kotlin
import io.atomic.atomic_sdk_flutter.AACFlutterActivity

class MainActivity: AACFlutterActivity() {
  ...
}
```

5. Open `android/app/src/main/AndroidManifest.xml` and add the following attribute to the `application` tag:

```xml
<application ... android:supportsRtl="true">...</application>
```

This is required as a temporary workaround to support snooze and feedback screen layouts, and will be resolved in a future SDK release.

## Feature support

The following table outlines the native SDK features currently exposed via the Flutter wrapper.

| Feature          | iOS            | Android      |
|:-----------------|:---------------|:-------------|
| Create stream container | :heavy_check_mark: | :heavy_check_mark: |
| Create single card view | :heavy_check_mark: | |
| Customise first load styles | :heavy_check_mark: | :heavy_check_mark: |
| Customise polling interval | :heavy_check_mark: | :heavy_check_mark: |
| Card voting | :heavy_check_mark: | :heavy_check_mark: |
| Observe card count | :heavy_check_mark: | |
| Register/de-register device and stream container for notifications | :heavy_check_mark: | :heavy_check_mark: |

## Setup

Before you can display an Atomic stream container or single card view in your app, you must configure the SDK.

You can find your API base URL in the Atomic Workbench, under Settings > Settings > SDK > API Host.

### API base URL

You can set your API base URL in code, by calling the `setApiBaseUrl` method:

```dart
import 'package:atomic_sdk_flutter/atomic_session.dart';

await AACSession.setApiBaseUrl('<url>');
```

### Environment ID and API key

Within your host app, you will need to call the `initialise` method to configure the SDK. Your environment ID can be found in the Atomic Workbench, under Settings > Settings, and your API key can be configured under Settings > Settings > SDK > Keys.

```dart
import 'package:atomic_sdk_flutter/atomic_session.dart';

AACSession.initialise('<environmentId>', '<apiKey>');
```

### Displaying a stream container

First, import the Atomic components:

```dart
import 'package:atomic_sdk_flutter/atomic_stream_container.dart';
```

Then create a stream container:

```dart
Container(
  child: AACStreamContainer(
    configuration: config,
    containerId: '<containerId>',
    sessionDelegate: sessionDelegate,
  ),
  // Specify desired width and height.
  width: 400,
  height: 400
});
```

### Displaying a single card (iOS only)

First, import the Atomic components:

```dart
import 'package:atomic_sdk_flutter/atomic_stream_container.dart';
```

Then create a single card view:

```dart
AACSingleCardView(
  configuration: config,
  containerId: '<containerId>',
  sessionDelegate: sessionDelegate,
  onSizeChanged: onSizeChanged // Optional - triggered when the single card view changes size.
);
```

The single card view automatically sizes itself to fit the card it is displaying - therefore you do not need to specify a height. A width, however, is required.

You can also be notified when the single card view changes size, by assigning a callback to the `onSizeChanged` property on the single card view. You will be supplied with the `width` and `height` of the single card view as arguments.

### Configuration

The stream container or single card view will not start until it has received a stream container ID, session delegate (supplying an authentication token) and configuration object:

- `containerId` (string): The ID of the stream container that you want to display, found in the Atomic Workbench.
- `sessionDelegate` (AACSessionDelegate): A delegate that asynchronously supplies an authentication token when requested.
- `configuration` (AACStreamContainerConfiguration): A configuration object that allows you to customise functionality within the stream container or single card view (see below).

The following functionality can be customised using the `configuration` object:

- `pollingInterval` (number, in seconds): How often the stream container should check for new cards. Defaults to 15 seconds.
- `launchColors` (AACStreamContainerLaunchColors): Colours used for the initial load screen, shown the very first time that a user views a stream container or single card view. The initial theme for the container is downloaded on this screen. Properties are:
  - `background` (Color): The colour to use for the background of the initial load screen.
  - `loadingIndicator` (Color): The colour to use for the loading indicator on the initial load screen.
  - `button` (Color): The colour to use for the buttons on the initial load screen.
  - `text` (Color): The colour to use for the text on the initial load screen.
- `votingOption` (AACVotingOption): Sets the card voting options available from a card's overflow menu.
  - `both`: The user can flag a card as either useful or not useful.
  - `notUseful`: The user can flag a card as 'not useful' only.
  - `useful`: The user can flag a card as 'useful' only.
  - `none`: The user cannot vote on a card (default).

## API and additional methods

### Push notifications

To use push notifications in the Flutter SDK, you'll need to add your iOS push certificate and Android server key in the Workbench, then request push notification permission in your app.

Push notification support requires a Flutter library such as [`flutter_apns`](https://pub.dev/packages/flutter_apns).

Once this is integrated, you can configure push notifications via the Flutter SDK. The steps below can occur in either order in your app.

**1. Register the user against specific stream containers for push notifications**

You need to signal to the Atomic Platform which stream containers are eligible to receive push notifications in your app for the current device.

```dart
import 'package:atomic_sdk_flutter/atomic_session.dart';

await AACSession.registerStreamContainersForNotifications(['<containerId>'], sessionDelegate);
```

You will need to do this each time the logged in user changes.

To deregister the device for Atomic notifications for your app, such as when a user completely logs out of your app, call `deregisterDeviceForNotifications` on `AACSession`:

```dart
import 'package:atomic_sdk_flutter/atomic_session.dart';

await AACSession.deregisterDeviceForNotifications();
```

**2. Send the push token to the Atomic Platform**

Send the device's push token to the Atomic Platform when it changes. Call this method in the appropriate push notification callback in your app:

```javascript
import 'package:atomic_sdk_flutter/atomic_session.dart';

await AACSession.registerDeviceForNotifications('token', sessionDelegate);
```

You can call the `registerDeviceForNotifications` method any time you want to update the push token stored for the user in the Atomic Platform; pass the method the device token as a string, along with a session delegate.

You will also need to update this token every time the logged in user changes in your app, so the Atomic Platform knows who to send notifications to.

### Retrieving card count (iOS only)

The SDK supports observing the card count for a particular stream container. Card count is provided to your callback independently of whether a stream container or single card view has been created, and is updated at the provided interval.

```dart
import 'package:atomic_sdk_flutter/atomic_session.dart';

// Retain this token so that you can stop observing later.
String observerToken = await AACSession.observeCardCount(
    '<containerId>' 5, sessionDelegate, (count) {
  print("Card count is now ${count}");
});
```

When you want to stop observing the card count, you can remove the observer using the token returned from the observation call above:

```dart
import 'package:atomic_sdk_flutter/atomic_session.dart';

await AACSession.stopObservingCardCount(observerToken);
```

### Purge cached data

The Flutter SDK provides a method for purging the local cache of a user's card data. The intent of this method is to clear user data when a previous user logs out, so that the cache is clear when a new user logs in to your app.

To clear caches:

```dart
import 'package:atomic_sdk_flutter/atomic_session.dart';

await AACSession.logout();
```

### Debug logging

Debug logging allows you to view more verbose logs regarding events that happen in the SDK. It is turned off by default, and should not be enabled in release builds. To enable debug logging:

```dart
import 'package:atomic_sdk_flutter/atomic_session.dart';

await AACSession.setLoggingEnabled(true);
```