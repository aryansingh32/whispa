# Whispa Frontend

This is the Flutter frontend for the Whispa messaging application.

## Deployment to Web / Cloudflare Pages

This frontend has been updated to be responsive, meaning it can be deployed on the web and viewed on both Desktop and Mobile devices.

### Step-by-Step Deployment Guide for Cloudflare Pages

1. **Build the Web App:**
   First, you need to compile the Flutter code to web static files. Run the following command in this `whispa-frontend` directory:
   ```bash
   flutter build web
   ```
   This will generate a `build/web` directory containing the static files.

2. **Create a Cloudflare Account:** If you haven't already, sign up at [Cloudflare](https://dash.cloudflare.com/).
3. **Go to Pages:** Navigate to "Workers & Pages" in the sidebar and select "Create application", then click the "Pages" tab.
4. **Deploy via Direct Upload or Git:**
   - **Git Integration (Recommended):** Connect your GitHub repository, choose this repository, and set the **Build command** to `flutter build web` (you might need to use a custom build image or use a GitHub Action to build and push to a `gh-pages` branch if Cloudflare's default environment doesn't have Flutter installed). Alternatively, use the Direct Upload method.
   - **Direct Upload:** Click "Upload assets", give your project a name (e.g., `whispa-web`), and upload the entire `build/web` folder you generated in Step 1.
5. **Configure API Endpoint (Optional):**
   If the frontend communicates with the backend via a specific URL, ensure the backend URL is correctly configured in your Flutter app before building (e.g., in an environment file or API service).
6. **Deploy:** Click deploy and Cloudflare will host your static files globally.

Your Whispa web application is now live!
