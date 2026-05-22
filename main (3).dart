import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Weather Assistant',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const WeatherHomePage(),
    );
  }
}

class WeatherHomePage extends StatefulWidget {
  const WeatherHomePage({super.key});

  @override
  State<WeatherHomePage> createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage> {
  final TextEditingController _cityController = TextEditingController(
    text: 'Lahore',
  );
  final TextEditingController _geminiKeyController = TextEditingController();

  WeatherReport? _report;
  String? _assistantAdvice;
  String? _errorMessage;
  bool _loadingWeather = false;
  bool _loadingAdvice = false;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  @override
  void dispose() {
    _cityController.dispose();
    _geminiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadWeather() async {
    final city = _cityController.text.trim();
    if (city.isEmpty) {
      setState(() => _errorMessage = 'Enter a city name first.');
      return;
    }

    setState(() {
      _loadingWeather = true;
      _errorMessage = null;
      _assistantAdvice = null;
    });

    try {
      final location = await WeatherService.findLocation(city);
      final report = await WeatherService.fetchWeather(location);

      setState(() => _report = report);
      await _loadAdvice(report);
    } catch (error) {
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingWeather = false);
      }
    }
  }

  Future<void> _loadAdvice(WeatherReport report) async {
    setState(() => _loadingAdvice = true);

    try {
      final apiKey = _geminiKeyController.text.trim();
      final advice = apiKey.isEmpty
          ? GeminiAssistant.localAdvice(report)
          : await GeminiAssistant.fetchAdvice(apiKey: apiKey, report: report);

      if (mounted) {
        setState(() => _assistantAdvice = advice);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _assistantAdvice =
              '${GeminiAssistant.localAdvice(report)}\n\nGemini error: $error';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loadingAdvice = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather Assistant'),
        actions: [
          IconButton(
            tooltip: 'Refresh weather',
            onPressed: _loadingWeather ? null : _loadWeather,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SearchPanel(
              cityController: _cityController,
              geminiKeyController: _geminiKeyController,
              loading: _loadingWeather,
              onSearch: _loadWeather,
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              _MessageCard(
                icon: Icons.error_outline,
                title: 'Could not load weather',
                message: _errorMessage!,
              )
            else if (_loadingWeather && report == null)
              const _LoadingCard(message: 'Fetching real-time weather...')
            else if (report != null) ...[
              _WeatherCard(report: report),
              const SizedBox(height: 16),
              if (_loadingAdvice)
                const _LoadingCard(message: 'Preparing weather advice...')
              else
                _MessageCard(
                  icon: Icons.auto_awesome,
                  title: 'AI Weather Assistant',
                  message:
                      _assistantAdvice ?? GeminiAssistant.localAdvice(report),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.cityController,
    required this.geminiKeyController,
    required this.loading,
    required this.onSearch,
  });

  final TextEditingController cityController;
  final TextEditingController geminiKeyController;
  final bool loading;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Search City', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: cityController,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'City',
                prefixIcon: Icon(Icons.location_city),
              ),
              onSubmitted: (_) => loading ? null : onSearch(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: geminiKeyController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Gemini API key',
                helperText: 'Leave empty to show built-in advice.',
                prefixIcon: Icon(Icons.key),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: loading ? null : onSearch,
              icon: loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_sync),
              label: Text(loading ? 'Loading' : 'Get Weather'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeatherCard extends StatelessWidget {
  const _WeatherCard({required this.report});

  final WeatherReport report;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  report.weatherIcon,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(report.city, style: textTheme.headlineSmall),
                      Text(report.condition, style: textTheme.titleMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              '${report.temperature.round()}°C',
              style: textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetricChip(
                  icon: Icons.water_drop,
                  label: 'Rain',
                  value: '${report.precipitationChance.round()}%',
                ),
                _MetricChip(
                  icon: Icons.air,
                  label: 'Wind',
                  value: '${report.windSpeed.round()} km/h',
                ),
                _MetricChip(
                  icon: Icons.thermostat,
                  label: 'Feels',
                  value: '${report.temperature.round()}°C',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text('$label: $value'));
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class WeatherService {
  static Future<LocationResult> findLocation(String city) async {
    final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': city,
      'count': '1',
      'language': 'en',
      'format': 'json',
    });
    final data = await _getJson(uri);
    final results = data['results'] as List<dynamic>?;

    if (results == null || results.isEmpty) {
      throw Exception('No location found for "$city".');
    }

    final result = results.first as Map<String, dynamic>;
    return LocationResult(
      name: result['name'] as String,
      country: result['country'] as String? ?? '',
      latitude: (result['latitude'] as num).toDouble(),
      longitude: (result['longitude'] as num).toDouble(),
    );
  }

  static Future<WeatherReport> fetchWeather(LocationResult location) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': location.latitude.toString(),
      'longitude': location.longitude.toString(),
      'current': 'temperature_2m,precipitation,weather_code,wind_speed_10m',
      'hourly': 'precipitation_probability',
      'forecast_days': '1',
    });
    final data = await _getJson(uri);
    final current = data['current'] as Map<String, dynamic>?;
    final hourly = data['hourly'] as Map<String, dynamic>?;

    if (current == null) {
      throw Exception('Weather data is unavailable right now.');
    }

    final probabilities =
        (hourly?['precipitation_probability'] as List<dynamic>?) ?? const [];
    final firstProbability = probabilities.isEmpty
        ? 0.0
        : (probabilities.first as num).toDouble();
    final code = (current['weather_code'] as num).toInt();

    return WeatherReport(
      city: location.country.isEmpty
          ? location.name
          : '${location.name}, ${location.country}',
      temperature: (current['temperature_2m'] as num).toDouble(),
      precipitationChance: firstProbability,
      windSpeed: (current['wind_speed_10m'] as num).toDouble(),
      condition: WeatherCode.describe(code),
      weatherIcon: WeatherCode.iconFor(code),
    );
  }

  static Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await http.get(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Request failed with status ${response.statusCode}.');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}

class GeminiAssistant {
  static Future<String> fetchAdvice({
    required String apiKey,
    required WeatherReport report,
  }) async {
    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/gemini-1.5-flash:generateContent',
      {'key': apiKey},
    );
    final prompt =
        '''
Give short practical weather advice in 2 sentences.
Location: ${report.city}
Temperature: ${report.temperature.toStringAsFixed(1)} C
Condition: ${report.condition}
Rain chance: ${report.precipitationChance.toStringAsFixed(0)}%
Wind: ${report.windSpeed.toStringAsFixed(0)} km/h
Mention if the user should go outside, carry an umbrella, or avoid heat/wind.
''';
    final payload = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
    });

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: payload,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Gemini request failed with status ${response.statusCode}.',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List<dynamic>? ?? const [];
    final content = candidates.isEmpty
        ? null
        : candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>? ?? const [];
    final text = parts.isEmpty ? null : parts.first['text'] as String?;

    if (text == null || text.trim().isEmpty) {
      throw Exception('Gemini did not return advice text.');
    }

    return text.trim();
  }

  static String localAdvice(WeatherReport report) {
    final notes = <String>[];

    if (report.precipitationChance >= 50 ||
        report.condition.toLowerCase().contains('rain')) {
      notes.add('Carry an umbrella before going outside.');
    } else {
      notes.add('It looks fine for going outside.');
    }

    if (report.temperature >= 35) {
      notes.add('Drink water and avoid long exposure to direct heat.');
    } else if (report.temperature <= 10) {
      notes.add('Wear warm clothes if you are heading out.');
    }

    if (report.windSpeed >= 35) {
      notes.add('Be careful in strong wind.');
    }

    return notes.join(' ');
  }
}

class LocationResult {
  const LocationResult({
    required this.name,
    required this.country,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final String country;
  final double latitude;
  final double longitude;
}

class WeatherReport {
  const WeatherReport({
    required this.city,
    required this.temperature,
    required this.precipitationChance,
    required this.windSpeed,
    required this.condition,
    required this.weatherIcon,
  });

  final String city;
  final double temperature;
  final double precipitationChance;
  final double windSpeed;
  final String condition;
  final IconData weatherIcon;
}

class WeatherCode {
  static String describe(int code) {
    if (code == 0) return 'Clear sky';
    if ([1, 2, 3].contains(code)) return 'Partly cloudy';
    if ([45, 48].contains(code)) return 'Fog';
    if ([51, 53, 55, 56, 57].contains(code)) return 'Drizzle';
    if ([61, 63, 65, 66, 67, 80, 81, 82].contains(code)) return 'Rain';
    if ([71, 73, 75, 77, 85, 86].contains(code)) return 'Snow';
    if ([95, 96, 99].contains(code)) return 'Thunderstorm';
    return 'Mixed weather';
  }

  static IconData iconFor(int code) {
    if (code == 0) return Icons.wb_sunny;
    if ([1, 2, 3].contains(code)) return Icons.cloud;
    if ([45, 48].contains(code)) return Icons.foggy;
    if ([51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82].contains(code)) {
      return Icons.umbrella;
    }
    if ([71, 73, 75, 77, 85, 86].contains(code)) {
      return Icons.ac_unit;
    }
    if ([95, 96, 99].contains(code)) return Icons.thunderstorm;
    return Icons.wb_cloudy;
  }
}
