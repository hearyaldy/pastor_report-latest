# 🚀 Deploy Pastor Report to GitHub Pages

Your deployment is pre-configured for: **https://github.com/hearyaldy/pastorpro**

## Quick Deploy (3 steps!)

### Step 1: Deploy to GitHub Pages
```bash
./deploy_github_pages.sh
```

That's it! The script will:
- ✅ Build your Flutter web app
- ✅ Push to `gh-pages` branch
- ✅ Configure everything automatically

### Step 2: Enable GitHub Pages

1. Go to https://github.com/hearyaldy/pastorpro/settings/pages

2. Under "Build and deployment":
   - **Source**: Deploy from a branch
   - **Branch**: `gh-pages`
   - **Folder**: `/ (root)`

3. Click **Save**

### Step 3: Access Your App

Wait 1-2 minutes, then visit:

```
https://hearyaldy.github.io/pastorpro/
```

🎉 **Your app is live!**

---

## Alternative: Automatic Deployment with GitHub Actions

Want automatic deployment on every `git push`?

### One-Time Setup:

1. **Push this project to GitHub** (if not already):
   ```bash
   git add .
   git commit -m "Add web deployment"
   git push origin main
   ```

2. **Enable GitHub Pages with Actions**:
   - Go to https://github.com/hearyaldy/pastorpro/settings/pages
   - Source: **GitHub Actions**
   - Save

3. **That's it!** Now every push to `main` automatically deploys.

The GitHub Actions workflow is already configured in `.github/workflows/deploy.yml`

---

## Update Your Deployed App

### Manual Method:
```bash
./deploy_github_pages.sh
```

### Automatic Method (if using GitHub Actions):
```bash
git add .
git commit -m "Update app"
git push origin main
```

---

## Testing Before Deployment

Test locally first:

```bash
# Build
flutter build web --release --base-href "/pastorpro/"

# Test locally
cd build/web
python3 -m http.server 8000
# Open http://localhost:8000/pastorpro/

cd ../..
```

---

## Custom Domain (Optional)

If you want to use a custom domain like `pastorpro.com`:

1. **Add CNAME to deployment**:
   ```bash
   # Edit deploy script and add before "git add .":
   echo "pastorpro.com" > CNAME
   ```

2. **Configure DNS** with your domain provider:
   - Type: `CNAME`
   - Name: `@` (or subdomain)
   - Value: `hearyaldy.github.io`

3. **Update GitHub Pages settings**:
   - Settings → Pages → Custom domain
   - Enter: `pastorpro.com`
   - Save

---

## Troubleshooting

### Blank page after deployment?
Make sure GitHub Pages is configured:
- Branch: `gh-pages`
- Folder: `/ (root)`

### 404 error?
Wait 2-5 minutes for GitHub Pages to deploy.

### Build failed?
Check Flutter installation:
```bash
flutter doctor
flutter clean
flutter pub get
```

### Authentication failed?
Configure Git credentials:
```bash
git config --global user.name "hearyaldy"
git config --global user.email "your-email@example.com"
```

Or use SSH instead:
```bash
# In deploy script, change HTTPS to SSH:
GITHUB_REPO_URL="git@github.com:hearyaldy/pastorpro.git"
```

---

## What Happens During Deployment?

1. ✅ Builds Flutter web app with correct base URL
2. ✅ Creates/updates `gh-pages` branch
3. ✅ Pushes only the `build/web` folder (not source code)
4. ✅ GitHub Pages serves the static files

**Your source code stays private on the `main` branch!**

---

## Repository Structure

```
main branch (private code)
├── lib/              ← Your Flutter source code
├── assets/           ← Your assets
└── ...

gh-pages branch (public website)
├── index.html        ← Compiled web app
├── main.dart.js      ← Compiled Flutter code
└── assets/           ← Compiled assets
```

---

## URLs

**Repository**: https://github.com/hearyaldy/pastorpro

**Deployed App**: https://hearyaldy.github.io/pastorpro/

**Settings**: https://github.com/hearyaldy/pastorpro/settings/pages

**Actions** (if using CI/CD): https://github.com/hearyaldy/pastorpro/actions

---

## Ready to Deploy?

Just run:

```bash
./deploy_github_pages.sh
```

It will guide you through the process! 🚀

---

## Need More Options?

- See `DEPLOYMENT_GUIDE.md` for other hosting platforms (Netlify, Vercel, Firebase)
- See `QUICK_DEPLOY.md` for detailed step-by-step instructions
- See `WEB_COMPATIBILITY_FIXES.md` for technical details

---

**Happy Deploying! 🎉**
