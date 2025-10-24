# TanDanGenie

> AI-powered nutrition analysis app for instant food macronutrient ratio calculation

[![Flutter](https://img.shields.io/badge/Flutter-3.9.2-02569B?logo=flutter)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## Overview

TanDanGenie is a mobile app that analyzes food images to calculate **carbohydrate:protein:fat ratios** using AI.

Simply scan a food label or take a photo of your meal, and get instant nutritional analysis with personalized health recommendations based on WHO guidelines (50:30:20 ratio).

### Key Features

- **📸 Image Recognition**: Gemini 2.0-flash AI for food identification
- **🔢 Nutrition Analysis**: Automatic macronutrient ratio calculation
- **✅ WHO Compliance**: Health assessment based on WHO nutrition standards
- **💡 Smart Recommendations**: Category-based healthier alternatives from USDA database
- **📊 Daily Tracking**: Monitor your daily nutrition intake with interactive dashboard
- **💬 Chat-style UI**: KakaoTalk-inspired conversational interface

---

## Technology Stack

### Frontend

- **Flutter 3.9.2** (Dart) - Cross-platform mobile (Android/iOS)
- **Provider** - State management
- **fl_chart** - Nutrition visualization

### AI & Backend

- **Gemini 2.0-flash API** - Food image recognition and OCR
- **BigQuery REST API** - USDA FoodData Central nutrition database
- **SQLite** - Local data storage

### Architecture

- **MVVM Pattern** - Clean separation of concerns
- **Provider Pattern** - Reactive state management
- **Service Layer** - Modular API integration

---

## Screenshots

### Main Features

- **Home Screen**: Chat-style nutrition analysis
- **Camera Screen**: Food scanning with image picker
- **Dashboard**: Daily nutrition tracking with charts
- **Settings**: User profile and health goals

---

## Getting Started

### Prerequisites

- Flutter SDK 3.9.2 or higher
- Dart SDK
- Android Studio / Xcode
- Gemini API key
- Google Cloud Service Account (for BigQuery)

### Installation

1. **Clone the repository**

```bash
git clone https://github.com/hufirst/NutriScanAI.git
cd NutriScanAI
```

2. **Install dependencies**

```bash
flutter pub get
```

3. **Set up environment variables**

Create a `.env` file in the project root:

```bash
GEMINI_API_KEY=your_gemini_api_key_here
BIGQUERY_PROJECT_ID=your_project_id
```

4. **Add service account credentials**

Place your Google Cloud service account JSON file at:

```text
android/app/src/main/assets/service-account.json
```

5. **Run the app**

```bash
flutter run
```

---

## Project Structure

```text
lib/
├── models/          # Data models
├── providers/       # State management
├── services/        # API and business logic
├── ui/
│   ├── screens/    # App screens
│   ├── widgets/    # Reusable widgets
│   └── theme/      # App theme
└── utils/          # Utilities and constants
```

---

## Features in Detail

### 1. Food Recognition

- Support for Korean and international cuisine
- Priority-based identification (simple foods → Korean → other cuisines)
- High accuracy for fruits, vegetables, and packaged foods

### 2. Nutrition Analysis

- Automatic extraction of calories, carbs, protein, and fat
- Calculation of macronutrient ratios
- WHO compliance assessment (50:30:20 target)

### 3. Healthier Alternatives

- Category-based recommendations from USDA database
- Korean food → English USDA keyword mapping
- Filtered suggestions based on analyzed food type

### 4. Daily Tracking

- Interactive bar charts for daily intake
- Progress tracking against recommended values
- Historical data visualization

### 5. User Profile

- Personalized health goals
- Dietary restrictions support
- Activity level-based recommendations

---

## Configuration

### Gemini API Setup

1. Get API key from [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Add to `.env` file

### BigQuery Setup

1. Create Google Cloud project
2. Enable BigQuery API
3. Create service account with BigQuery permissions
4. Download JSON credentials
5. Place in `android/app/src/main/assets/`

---

## Development

### Run in debug mode

```bash
flutter run -d <device_id>
```

### Build release APK

```bash
flutter build apk --release
```

### Run tests

```bash
flutter test
```

---

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- **Google Gemini AI** for food recognition
- **USDA FoodData Central** for nutrition database
- **WHO** for nutrition guidelines
- **Flutter** community for excellent documentation

---

## Contact

Project Link: [https://github.com/hufirst/NutriScanAI](https://github.com/hufirst/NutriScanAI)

---

Made with ❤️ using Flutter and AI
