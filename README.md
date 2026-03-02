# Cuisinee - AI-Powered Cooking Assistant

A beautiful, modern Flutter application designed for Mauritanian and MENA households to cook healthier, personalized, culturally accurate meals while reducing food waste.

## Features

### 🍽️ Smart Recipe Discovery
- AI-powered recipe suggestions based on your preferences
- Authentic Mauritanian and MENA recipes curated by real chefs
- Cultural recipe library with traditional dishes

### 💚 Health-Aligned Eating
- Filter recipes by health conditions (diabetes, hypertension, anemia)
- Nutritional information for every recipe
- Ingredient substitution suggestions for healthier options

### 🧅 Low-Waste Cooking
- Input leftover ingredients to get recipe suggestions
- Reduce food waste by cooking with what you have
- Smart matching algorithm finds recipes you can make

### 🤖 AI Cooking Assistant
- Chat-based interface for cooking guidance
- Step-by-step cooking mode with large, readable text
- Voice input for hands-free cooking

### 👤 Personalization
- Set taste preferences and disliked ingredients
- Health needs configuration
- Recent meals tracking

## Design Philosophy

- **Warm & Minimal**: Soft neutral colors with terracotta accent
- **Mobile-First**: Optimized for touch with large targets
- **Culturally Inspired**: Subtle MENA design elements
- **Accessible**: Clear typography, high contrast, voice support

## Color Palette

- **Primary**: Terracotta (#E07A5F)
- **Secondary**: Sand Gold (#F2CC8F)  
- **Accent**: Mint Green (#81B29A)
- **Background**: Warm White (#FAF8F5)

## Getting Started

1. Clone the repository
2. Run `flutter pub get`
3. Run `flutter run`

## Project Structure

```
lib/
├── main.dart
├── core/
│   ├── theme/
│   │   ├── app_colors.dart
│   │   └── app_theme.dart
│   ├── providers/
│   │   ├── theme_provider.dart
│   │   ├── user_provider.dart
│   │   └── recipe_provider.dart
│   ├── models/
│   │   ├── user_model.dart
│   │   ├── recipe_model.dart
│   │   └── chat_message.dart
│   ├── data/
│   │   └── dummy_recipes.dart
│   └── widgets/
│       ├── buttons.dart
│       ├── text_fields.dart
│       ├── recipe_cards.dart
│       ├── chips.dart
│       └── skeleton_loaders.dart
├── features/
│   ├── onboarding/
│   │   ├── screens/
│   │   │   └── onboarding_screen.dart
│   │   └── widgets/
│   │       └── onboarding_page.dart
│   ├── auth/
│   │   └── screens/
│   │       ├── login_screen.dart
│   │       └── signup_screen.dart
│   ├── navigation/
│   │   └── main_navigation.dart
│   ├── home/
│   │   ├── screens/
│   │   │   └── home_screen.dart
│   │   └── widgets/
│   │       ├── quick_action_card.dart
│   │       └── section_header.dart
│   ├── chat/
│   │   ├── screens/
│   │   │   └── chat_screen.dart
│   │   └── widgets/
│   │       ├── chat_bubble.dart
│   │       ├── voice_input_button.dart
│   │       └── cooking_step_card.dart
│   ├── recipes/
│   │   ├── screens/
│   │   │   ├── recipe_detail_screen.dart
│   │   │   ├── recipe_library_screen.dart
│   │   │   └── saved_recipes_screen.dart
│   │   └── widgets/
│   │       ├── ingredient_list.dart
│   │       ├── step_list.dart
│   │       └── nutrition_card.dart
│   ├── leftover/
│   │   └── screens/
│   │       └── leftover_screen.dart
│   ├── health_filters/
│   │   └── screens/
│   │       └── health_filters_screen.dart
│   └── profile/
│       └── screens/
│           └── profile_screen.dart
```

## Screens

1. **Onboarding** - Welcome screens explaining key features
2. **Login/Signup** - Authentication with email, Google, Apple
3. **Home Dashboard** - Daily suggestions, quick actions, recipe carousels
4. **AI Chat Assistant** - Conversational cooking help with voice input
5. **Recipe Detail** - Full recipe with ingredients, steps, nutrition
6. **Recipe Library** - Browse Mauritanian and MENA recipes
7. **Leftover Mode** - Find recipes from your ingredients
8. **Health Filters** - Filter by health conditions
9. **Profile** - User preferences and settings

## Dependencies

- `provider` - State management
- `google_fonts` - Typography
- `flutter_animate` - Animations
- `shimmer` - Skeleton loading
- `percent_indicator` - Progress indicators
- `cached_network_image` - Image caching

## License

MIT License
