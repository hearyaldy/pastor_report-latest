# Deployment Guide - Pastor Report Web App

## Overview
This guide shows you how to deploy your Flutter web app to various Git-based hosting services.

---

## Option 1: GitHub Pages (FREE) ⭐ Recommended

GitHub Pages is free and perfect for hosting Flutter web apps.

### Setup Steps:

1. **Create a new repository on GitHub** (or use existing):
   ```bash
   # Example: https://github.com/yourusername/pastor-report-web
   ```

2. **Build your Flutter web app**:
   ```bash
   flutter build web --release --base-href "/pastor-report-web/"
   ```
   
   **Important**: Replace `pastor-report-web` with your repository name!

3. **Navigate to the build output**:
   ```bash
   cd build/web
   ```

4. **Initialize git in the build folder** (if not already):
   ```bash
   git init
   git add .
   git commit -m "Deploy Flutter web app"
   ```

5. **Push to gh-pages branch**:
   ```bash
   git branch -M gh-pages
   git remote add origin https://github.com/yourusername/pastor-report-web.git
   git push -u origin gh-pages --force
   ```

6. **Enable GitHub Pages**:
   - Go to your repository on GitHub
   - Settings → Pages
   - Source: Deploy from branch
   - Branch: `gh-pages` / `root`
   - Save

7. **Your app will be live at**:
   ```
   https://yourusername.github.io/pastor-report-web/
   ```

### Automated Deployment Script (GitHub Pages)

Create a script `deploy_web.sh` in your project root:

```bash
#!/bin/bash

# Configuration
REPO_URL="https://github.com/yourusername/pastor-report-web.git"
REPO_NAME="pastor-report-web"

echo "🚀 Starting deployment to GitHub Pages..."

# Build the web app
echo "📦 Building Flutter web app..."
flutter build web --release --base-href "/$REPO_NAME/"

# Navigate to build directory
cd build/web

# Initialize git if needed
if [ ! -d .git ]; then
    git init
fi

# Add all files
git add .

# Commit changes
git commit -m "Deploy: $(date +'%Y-%m-%d %H:%M:%S')"

# Set branch to gh-pages
git branch -M gh-pages

# Add remote if not exists
if ! git remote | grep -q origin; then
    git remote add origin $REPO_URL
fi

# Force push to gh-pages
git push -u origin gh-pages --force

echo "✅ Deployment complete!"
echo "🌐 Your app will be available at: https://yourusername.github.io/$REPO_NAME/"

cd ../..
```

Make it executable:
```bash
chmod +x deploy_web.sh
```

Run it:
```bash
./deploy_web.sh
```

---

## Option 2: GitLab Pages (FREE)

GitLab also offers free static site hosting.

### Setup Steps:

1. **Create `.gitlab-ci.yml` in your project root**:

```yaml
image: cirrusci/flutter:stable

pages:
  stage: deploy
  script:
    - flutter build web --release
    - mv build/web public
  artifacts:
    paths:
      - public
  only:
    - main
```

2. **Push to GitLab**:
   ```bash
   git remote add gitlab https://gitlab.com/yourusername/pastor-report.git
   git push gitlab main
   ```

3. **Your app will be live at**:
   ```
   https://yourusername.gitlab.io/pastor-report/
   ```

---

## Option 3: Netlify (FREE with CI/CD)

Netlify offers automatic deployments from Git.

### Setup Steps:

1. **Create `netlify.toml` in project root**:

```toml
[build]
  publish = "build/web"
  command = "flutter build web --release"

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200
```

2. **Deploy via Netlify CLI**:
   ```bash
   # Install Netlify CLI
   npm install -g netlify-cli
   
   # Build your app
   flutter build web --release
   
   # Deploy
   netlify deploy --prod --dir=build/web
   ```

Or connect your Git repository on netlify.com for automatic deployments.

---

## Option 4: Vercel (FREE with CI/CD)

Similar to Netlify, with excellent performance.

### Setup Steps:

1. **Create `vercel.json` in project root**:

```json
{
  "buildCommand": "flutter build web --release",
  "outputDirectory": "build/web",
  "routes": [
    {
      "src": "/(.*)",
      "dest": "/index.html"
    }
  ]
}
```

2. **Deploy via Vercel CLI**:
   ```bash
   # Install Vercel CLI
   npm install -g vercel
   
   # Deploy
   vercel
   ```

Or connect your repository on vercel.com.

---

## Option 5: Firebase Hosting (FREE tier available)

If you're already using Firebase for your backend.

### Setup Steps:

1. **Install Firebase CLI**:
   ```bash
   npm install -g firebase-tools
   ```

2. **Login and initialize**:
   ```bash
   firebase login
   firebase init hosting
   ```

3. **Configure** (when prompted):
   - Public directory: `build/web`
   - Single-page app: Yes
   - Set up automatic builds: No (we'll do manual)

4. **Build and deploy**:
   ```bash
   flutter build web --release
   firebase deploy --only hosting
   ```

5. **Your app will be live at**:
   ```
   https://your-project-id.web.app
   ```

---

## Quick Comparison

| Service | Cost | CI/CD | Custom Domain | SSL | Speed |
|---------|------|-------|---------------|-----|-------|
| **GitHub Pages** | FREE | Manual | Yes (free) | Auto | Good |
| **GitLab Pages** | FREE | Auto | Yes (free) | Auto | Good |
| **Netlify** | FREE | Auto | Yes (free) | Auto | Excellent |
| **Vercel** | FREE | Auto | Yes (free) | Auto | Excellent |
| **Firebase** | FREE* | Manual | Yes (paid) | Auto | Excellent |

*Firebase has generous free tier, but custom domains require paid plan.

---

## Recommended Workflow: GitHub Pages

For simplicity and wide adoption, I recommend GitHub Pages. Here's the complete workflow:

### 1. One-Time Setup

```bash
# Create a new repository on GitHub first
# Then run these commands:

cd /Users/hearyhealdysairin/Documents/Flutter/pastor_report-latest

# Create deploy script
cat > deploy_web.sh << 'EOF'
#!/bin/bash
REPO_URL="https://github.com/YOUR_USERNAME/pastor-report-web.git"
REPO_NAME="pastor-report-web"

echo "🚀 Deploying to GitHub Pages..."
flutter build web --release --base-href "/$REPO_NAME/"
cd build/web
git init
git add .
git commit -m "Deploy: $(date +'%Y-%m-%d %H:%M:%S')"
git branch -M gh-pages
if ! git remote | grep -q origin; then
    git remote add origin $REPO_URL
fi
git push -u origin gh-pages --force
echo "✅ Deployed to https://YOUR_USERNAME.github.io/$REPO_NAME/"
cd ../..
EOF

chmod +x deploy_web.sh
```

### 2. Deploy Anytime

```bash
./deploy_web.sh
```

That's it! Your app will be live in minutes.

---

## Custom Domain Setup (All Platforms)

If you have a custom domain:

### GitHub Pages:
1. Add a file named `CNAME` to `build/web/` with your domain:
   ```
   pastor-report.yourdomain.com
   ```
2. Configure DNS:
   - Type: CNAME
   - Name: pastor-report
   - Value: yourusername.github.io

### Other Platforms:
Similar process - check their documentation for DNS settings.

---

## Environment Variables for Web

If you need different Firebase configs for production web:

1. Create `lib/firebase_options_web_prod.dart`
2. Update build command:
   ```bash
   flutter build web --release --dart-define=FIREBASE_ENV=production
   ```

---

## Testing Before Deployment

Always test locally first:

```bash
# Build for web
flutter build web --release

# Serve locally
cd build/web
python3 -m http.server 8000

# Open http://localhost:8000 in browser
```

---

## Troubleshooting

### Issue: Blank page after deployment
**Solution**: Make sure you used `--base-href` correctly:
```bash
flutter build web --release --base-href "/your-repo-name/"
```

### Issue: 404 on refresh
**Solution**: Configure your host for SPA routing (see examples above).

### Issue: Firebase not connecting
**Solution**: Check that your Firebase web config is correct in `firebase_options.dart`.

---

## CI/CD Automation (Advanced)

For GitHub Actions automated deployment:

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to GitHub Pages

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.32.7'
        channel: 'stable'
    
    - name: Install dependencies
      run: flutter pub get
    
    - name: Build web
      run: flutter build web --release --base-href "/pastor-report-web/"
    
    - name: Deploy to GitHub Pages
      uses: peaceiris/actions-gh-pages@v3
      with:
        github_token: ${{ secrets.GITHUB_TOKEN }}
        publish_dir: ./build/web
```

Now every push to main automatically deploys!

---

## Summary

**Easiest**: GitHub Pages with the deploy script  
**Best CI/CD**: GitLab Pages or GitHub Actions  
**Best Performance**: Netlify or Vercel  
**Best for Firebase Users**: Firebase Hosting

Choose based on your needs. For most cases, **GitHub Pages is perfect** and takes just 5 minutes to set up!
