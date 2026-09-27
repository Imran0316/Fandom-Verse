# fandom_verse

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Events

Events are read from Firestore's `events` collection. Admin-created documents
include a title, event type, city, venue, coordinates, `startAt`, optional
`endAt`, description, image URL, ticket URL, organizer, `isActive`, and server
timestamps. Legacy `city`, `dateLabel`, and `startAt` documents remain readable.
Official event create/edit/delete operations are restricted to admins by
`firestore.rules`.

The map and nearby discovery use the Google Maps SDK and device location. Add a
restricted Google Maps API key to the Android manifest placeholder through the
`GOOGLE_MAPS_API_KEY` Gradle property or environment variable. Set the same
`GOOGLE_MAPS_API_KEY` Xcode build setting for iOS, and pass it to Dart at run or
build time with `--dart-define=GOOGLE_MAPS_API_KEY=...`. Enable the Maps SDK for
Android/iOS and the Geocoding API for Admin address lookup, with API and app
restrictions configured in Google Cloud. Do not commit the key.
For Flutter Web, load the Google Maps JavaScript API with the same restricted
key in `web/index.html`. Android/iOS location permission prompts are configured
in their platform manifests; users can still browse events by city when access
is denied.
