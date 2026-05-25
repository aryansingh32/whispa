# Whispa (formerly Anonym)

Whispa is a secure, anonymous messaging application. It consists of a Java Spring Boot backend and a responsive Flutter frontend.

## Project Structure

- **`whispa-backend/`**: The Spring Boot backend.
  - [Backend Deployment Guide](./whispa-backend/README.md)
- **`whispa-frontend/`**: The Flutter cross-platform frontend (Web, Mobile, Desktop).
  - [Frontend Deployment Guide](./whispa-frontend/README.md)

## Quick Start (Local Development)

### Backend
1. Navigate to `whispa-backend`
2. Run `mvn spring-boot:run`
3. The server will start on `localhost:8080`.

### Frontend
1. Navigate to `whispa-frontend`
2. Run `flutter pub get`
3. Run `flutter run -d chrome` (for web) or `flutter run` (for connected device).
