# WebKit white overlay with `CupertinoTabBar`

## Summary

On WebKit browsers, this app could render a white overlay over the bottom tab bar when:

1. The app used the standard `CupertinoTabScaffold` + `CupertinoTabBar` structure.
2. The app ran under `zh_CN`.
3. `CupertinoApp` relied on its default localization path instead of explicitly registering Cupertino localization delegates.

The minimal and correct fix is to explicitly register Flutter's global Cupertino localization delegates in `CupertinoApp`.

## Symptom

- A white overlay appeared over or around the bottom tab bar.
- The issue reproduced on WebKit-based browsers.
- The issue was locale-sensitive: `zh_CN` reproduced it, while `en_US` did not.

## What we tried

### 1. Replacing the native tab bar with a custom bottom bar

This worked, but it was only a workaround.

- `IndexedStack` + custom bottom bar rendered correctly.
- This proved the issue was connected to native Cupertino tab bar behavior.
- We did **not** keep this approach because it replaced native Cupertino behavior and architecture.

### 2. Forcing opaque backgrounds / disabling blur

We tried:

- `CupertinoThemeData.barBackgroundColor`
- `CupertinoTabBar(backgroundColor: ...)`
- `automaticBackgroundVisibility: false`
- `enableBackgroundFilterBlur: false`

These changes were useful during debugging, but they were **not** the real fix.
The overlay could still be reproduced without the localization fix.

### 3. Overriding `tabSemanticsLabel()`

At one point, returning an empty string from a custom `CupertinoLocalizations` implementation also removed the overlay.

That result was real, but it was **not** the final root cause. Later experiments showed that:

- the exact label text was not the key factor,
- the issue could disappear even when the label content stayed normal,
- the important variable was the localization delegate path, especially under `zh_CN`.

### 4. Explicit localization delegates

We then tested progressively smaller variants:

1. custom delegate + passthrough localizations,
2. custom delegate + locale-aware Flutter localizations,
3. direct `GlobalCupertinoLocalizations.delegate` and `GlobalWidgetsLocalizations.delegate`.

All of these removed the overlay.

This proved that the stable fix was **not** a custom label override, but rather the use of an explicit Cupertino localization delegate path.

## Root cause we finally confirmed

The bug is tied to this combination:

- **default `CupertinoApp` localization path**
- **`zh_CN` locale**
- **WebKit rendering**

The following matrix was confirmed during debugging:

| Localization setup | Locale | Result |
| --- | --- | --- |
| Default `CupertinoApp` localization path | `zh_CN` | White overlay appears |
| Default `CupertinoApp` localization path | `en_US` | No overlay |
| Explicit `GlobalCupertinoLocalizations.delegate` | `zh_CN` | No overlay |
| Explicit `GlobalCupertinoLocalizations.delegate` | `en_US` | No overlay |

So the problem is **not**:

- missing Chinese resources,
- `CupertinoTabBar` structure itself,
- blur/background styling alone,
- or the literal `tabSemanticsLabel()` text.

The practical root cause is:

> On WebKit, the default `CupertinoApp` localization path misbehaves for `zh_CN` in a way that causes the white overlay around `CupertinoTabBar`. Explicitly registering Flutter's global Cupertino localization delegates avoids that path and fixes the rendering issue.

## Minimal fix

Always register the global Flutter localization delegates explicitly in `CupertinoApp`:

```dart
import 'package:flutter_localizations/flutter_localizations.dart';

CupertinoApp(
  localizationsDelegates: const [
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  supportedLocales: const [
    Locale('zh', 'CN'),
    Locale('en', 'US'),
  ],
)
```

## Why this is the preferred fix

- Keeps the native `CupertinoTabBar` architecture.
- Keeps locale-aware Chinese and English Cupertino strings.
- Avoids hacky label overrides.
- Avoids styling-based workarounds that are not the real cause.
- Produces the smallest stable change that matches observed behavior.

## What future contributors should not do

Do **not** remove the explicit Cupertino localization delegates unless you have re-tested WebKit with `zh_CN`.

In particular, do **not** regress to this:

```dart
CupertinoApp(
  supportedLocales: const [
    Locale('zh', 'CN'),
    Locale('en', 'US'),
  ],
)
```

That default path can reintroduce the white overlay.

Also avoid these as the primary fix:

- replacing the native tab bar with a custom bar,
- forcing opaque backgrounds everywhere,
- disabling blur everywhere,
- overriding `tabSemanticsLabel()` just to hide the symptom.

Those may help debugging, but they are not the final minimal solution.
