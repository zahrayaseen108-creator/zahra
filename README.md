# Weather Assistant

Flutter weather app for a Mobile Application Development assignment.

## Features

- Search weather by city name.
- Fetch current temperature, condition, rain chance, and wind speed from Open-Meteo.
- Generate short weather advice with the Gemini API.
- Show built-in advice when a Gemini API key is not entered.
- Mobile-friendly Material 3 interface.

## APIs Used

- Weather: Open-Meteo Geocoding API and Forecast API
- AI Assistant: Google Gemini `generateContent` API

## How to Run

```bash
flutter pub get
flutter run
```

Enter a city name, optionally paste a Gemini API key, and tap **Get Weather**.

