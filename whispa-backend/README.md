# Whispa Backend

This is the Spring Boot backend for the Whispa messaging application.

## Deployment to Railway

This project is fully configured to be deployed on Railway using the provided `Dockerfile`.

### Step-by-Step Deployment Guide

1. **Create a Railway Account:** If you haven't already, sign up at [Railway.app](https://railway.app/).
2. **New Project:** Click on "New Project" and select "Deploy from GitHub repo".
3. **Select Repository:** Choose the repository containing this codebase.
4. **Configure Root Directory:** If your repository contains both frontend and backend, go to the Service Settings in Railway, and set the **Root Directory** to `/whispa-backend`.
5. **Add Database (Optional but recommended):**
   - Click "New" -> "Database" -> "Add PostgreSQL".
   - Once provisioned, Railway will give you a `DATABASE_URL`.
6. **Set Environment Variables:**
   - In your backend service settings, go to the **Variables** tab.
   - Add any required environment variables such as:
     - `PORT`: (Usually Railway handles this automatically, but if you need to override it).
     - `SPRING_DATASOURCE_URL`: Use the variable from your PostgreSQL service.
     - `SPRING_DATASOURCE_USERNAME`: Your DB username.
     - `SPRING_DATASOURCE_PASSWORD`: Your DB password.
7. **Deploy:** The service will automatically build using the `Dockerfile` and deploy.

Your Whispa backend is now live!
