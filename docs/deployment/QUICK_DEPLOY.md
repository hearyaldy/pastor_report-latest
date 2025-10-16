# Quick Start: Deploy to GitHub Pages

## Option A: Manual Deployment (5 minutes) ⚡

### Step 1: Create GitHub Repository
1. Go to https://github.com/new
2. Repository name: `pastor-report-web` (or any name you like)
3. Make it **Public** (required for free GitHub Pages)
4. **Don't** initialize with README
5. Click "Create repository"

### Step 2: Configure Deployment Script
1. Open `deploy_github_pages.sh`
2. Update these lines:
   ```bash
   GITHUB_USERNAME="YOUR_GITHUB_USERNAME"  # ← Your GitHub username
   REPO_NAME="pastor-report-web"           # ← Your repo name
   ```
3. Save the file

### Step 3: Deploy!
```bash
./deploy_github_pages.sh
```

### Step 4: Enable GitHub Pages
1. Go to your repository on GitHub
2. Click **Settings** → **Pages**
3. Under "Source":
   - Branch: `gh-pages`
   - Folder: `/ (root)`
4. Click **Save**

### Step 5: Access Your App
Wait 1-5 minutes, then visit:
```
https://YOUR_USERNAME.github.io/pastor-report-web/
```

🎉 **Done!** Your app is live on the web!

---

## Option B: Automatic Deployment with GitHub Actions (Set & Forget) 🤖

This deploys automatically every time you push to the main branch.

### Step 1: Create GitHub Repository
Same as Option A, Step 1

### Step 2: Push Your Code
```bash
# If you haven't already initialized git in your project
cd /Users/hearyhealdysairin/Documents/Flutter/pastor_report-latest
git init
git add .
git commit -m "Initial commit"

# Push to your new repository
git remote add origin https://github.com/YOUR_USERNAME/pastor-report-web.git
git branch -M main
git push -u origin main
```

### Step 3: Configure GitHub Pages
1. Go to repository **Settings** → **Pages**
2. Under "Build and deployment":
   - Source: **GitHub Actions**
3. That's it! The workflow will run automatically

### Step 4: Monitor Deployment
1. Go to **Actions** tab in your repository
2. You'll see the "Deploy to GitHub Pages" workflow running
3. Wait for it to complete (usually 2-3 minutes)

### Step 5: Access Your App
```
https://YOUR_USERNAME.github.io/pastor-report-web/
```

**Bonus**: Now every time you push changes to the main branch, the site updates automatically! 🚀

---

## Troubleshooting

### "Build failed"
- Make sure you run `flutter pub get` first
- Check that Flutter is properly installed: `flutter doctor`

### "Push failed" or "Authentication failed"
- Configure Git credentials: `git config --global user.name "Your Name"`
- Set up GitHub authentication: https://docs.github.com/en/authentication

### "Page shows 404"
- Wait 5 minutes for GitHub Pages to deploy
- Check that GitHub Pages is enabled in repository Settings
- Verify the branch is set to `gh-pages`

### "Blank page after deployment"
- Check browser console for errors
- Verify `--base-href` matches your repository name
- Try rebuilding: `./deploy_github_pages.sh`

---

## Custom Domain (Optional)

If you own a domain (e.g., `pastor-report.com`):

1. **Add CNAME file to your repository**:
   ```bash
   echo "pastor-report.com" > build/web/CNAME
   ```

2. **Update DNS settings** with your domain provider:
   - Type: `CNAME`
   - Name: `@` (or subdomain like `app`)
   - Value: `YOUR_USERNAME.github.io`

3. **In GitHub repository**:
   - Settings → Pages → Custom domain
   - Enter your domain and save

4. **Update build script** to preserve CNAME:
   ```bash
   # Add this to deploy script before git add
   echo "pastor-report.com" > CNAME
   ```

---

## Alternative: Deploy to Other Repository

If you want to deploy from a different repository:

### Option 1: Separate Deployment Repository
```bash
# Create a new repo just for deployment
# In your main project:
./deploy_github_pages.sh

# This pushes only build files to the deployment repo
```

### Option 2: Use Main Repository with GitHub Actions
- The `.github/workflows/deploy.yml` file is already set up
- Just push your code to the main branch
- GitHub Actions handles the rest

---

## What Gets Deployed?

Only the `build/web` folder contents:
- ✅ HTML, CSS, JavaScript files
- ✅ Assets (images, fonts, icons)
- ✅ Flutter compiled code
- ❌ Source code (not deployed)
- ❌ Dependencies (compiled into the build)

This is perfect for security - only the compiled app is public!

---

## Update Your Deployed App

**Manual Method:**
```bash
./deploy_github_pages.sh
```

**Automatic Method (if using GitHub Actions):**
```bash
git add .
git commit -m "Update app"
git push
```

---

## Summary

| Method | Pros | Cons | Best For |
|--------|------|------|----------|
| **Manual Script** | Simple, full control | Must run manually | Quick deployment |
| **GitHub Actions** | Automatic, no maintenance | Requires Git push | Continuous deployment |

**Recommendation**: Start with the manual script to test, then switch to GitHub Actions for automatic deployments!

---

Need help? Check the full [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) for more details!
