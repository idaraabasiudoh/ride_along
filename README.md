# 🚗 Student Ride-Along App

## 📌 Overview
The **Student Ride-Along App** is a Flutter-based mobile application designed for students to share rides to school at an affordable cost. Using **Supabase** as the backend, this app connects students needing a ride with student drivers heading to the same destination. The fare is calculated based on the distance to the school, ensuring a cost-effective and convenient commuting solution.

## 🎯 Features
- 🏫 **Student Ride Matching** – Connects students needing a ride with available student drivers.
- 📍 **Distance-Based Pricing** – Calculates ride fares based on the distance to the school.
- 🗺 **Live Location Tracking** – Displays driver and rider locations in real time.
- 🛡 **Secure Authentication** – User authentication and profile management via Supabase.
- 💳 **In-App Payments** – Supports secure online payments for ride fares.
- 📅 **Ride Scheduling** – Allows students to schedule rides in advance.
- 🔔 **Push Notifications** – Sends alerts for ride confirmations, cancellations, and arrivals.
- 📊 **Rating & Reviews** – Enables students to rate drivers for a better community experience.

## 🏗 Tech Stack
- **Frontend:** Flutter (Dart)
- **Backend:** Supabase (PostgreSQL, Authentication, Storage)
- **Mapping & Navigation:** Google Maps API / OpenStreetMap
- **Payments:** Stripe / PayPal
- **State Management:** Riverpod / Provider / Bloc
- **Push Notifications:** Firebase Cloud Messaging (FCM)

## 🚀 Installation
### Prerequisites
- Flutter SDK installed ([Download Flutter](https://flutter.dev/docs/get-started/install))
- Supabase account and project setup ([Sign up on Supabase](https://supabase.io/))
- Google Maps API key (if using Google Maps)

### Steps
1. **Clone the Repository**
   ```bash
   git clone https://github.com/idaraabasiudoh/student-ride-along-app.git
   cd student-ride-along-app
   ```
2. **Install Dependencies**
   ```bash
   flutter pub get
   ```
3. **Set Up Environment Variables**
   - Create a `.env` file and add your Supabase credentials and API keys.
4. **Run the App**
   ```bash
   flutter run
   ```

## 🛠 Project Structure
```
lib/
│── main.dart         # App entry point
│── screens/          # All UI screens
│── services/         # Backend API and database interactions
│── models/           # Data models
│── providers/        # State management
│── widgets/          # Reusable UI components
│── utils/            # Utility functions
```

## 🤝 Contributing
Contributions are welcome! Follow these steps:
1. Fork the repository
2. Create a feature branch (`git checkout -b feature-name`)
3. Commit your changes (`git commit -m 'Add feature'`)
4. Push to the branch (`git push origin feature-name`)
5. Open a Pull Request

## 📝 License
This project is licensed under the MIT License.

## 🙌 Acknowledgments
- **Flutter Community** for amazing resources and support.
- **Supabase** for providing an easy-to-use backend.
- **Open-source contributors** for making development easier.

---

🚀 Happy Coding! 🎉
