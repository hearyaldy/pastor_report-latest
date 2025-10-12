#!/bin/bash

# ===================================================
# Flutter Web Deployment Script for GitHub Pages
# ===================================================
# 
# Instructions:
# 1. Create a repository on GitHub (e.g., pastor-report-web)
# 2. Update the variables below with your information
# 3. Make this script executable: chmod +x deploy_github_pages.sh
# 4. Run: ./deploy_github_pages.sh
# ===================================================

# ===== CONFIGURATION - UPDATE THESE VALUES =====
GITHUB_USERNAME="hearyaldy"
REPO_NAME="pastorpro"
GITHUB_REPO_URL="https://github.com/${GITHUB_USERNAME}/${REPO_NAME}.git"
# ==============================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}  Flutter Web Deployment to GitHub Pages${NC}"
echo -e "${BLUE}=================================================${NC}"
echo ""

# Check if configuration is updated
if [ "$GITHUB_USERNAME" = "YOUR_GITHUB_USERNAME" ]; then
    echo -e "${RED}❌ Error: Please update the GITHUB_USERNAME in this script!${NC}"
    echo -e "${YELLOW}Edit this file and replace 'YOUR_GITHUB_USERNAME' with your GitHub username.${NC}"
    exit 1
fi

echo -e "${YELLOW}📋 Configuration:${NC}"
echo -e "   Repository: ${GITHUB_REPO_URL}"
echo -e "   Base URL: /${REPO_NAME}/"
echo ""

# Confirm deployment
read -p "Continue with deployment? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Deployment cancelled.${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}🔨 Step 1: Building Flutter web app...${NC}"
flutter build web --release --base-href "/${REPO_NAME}/"

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Build failed! Please fix errors and try again.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build successful!${NC}"
echo ""

echo -e "${BLUE}🔨 Step 2: Preparing deployment...${NC}"

# Navigate to build directory
cd build/web

# Initialize git if not already done
if [ ! -d .git ]; then
    echo "   Initializing git repository..."
    git init
fi

# Add all files
echo "   Adding files..."
git add .

# Commit changes with timestamp
COMMIT_MSG="Deploy: $(date +'%Y-%m-%d %H:%M:%S')"
echo "   Creating commit: $COMMIT_MSG"
git commit -m "$COMMIT_MSG"

# Set branch to gh-pages
echo "   Setting branch to gh-pages..."
git branch -M gh-pages

# Add remote if not exists
if ! git remote | grep -q origin; then
    echo "   Adding remote origin..."
    git remote add origin $GITHUB_REPO_URL
else
    echo "   Updating remote origin..."
    git remote set-url origin $GITHUB_REPO_URL
fi

echo ""
echo -e "${BLUE}🚀 Step 3: Deploying to GitHub Pages...${NC}"
git push -u origin gh-pages --force

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Deployment failed!${NC}"
    echo -e "${YELLOW}Please check:${NC}"
    echo -e "   1. Repository exists on GitHub"
    echo -e "   2. You have push access to the repository"
    echo -e "   3. Your Git credentials are configured"
    cd ../..
    exit 1
fi

cd ../..

echo ""
echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}  ✅ Deployment Successful!${NC}"
echo -e "${GREEN}=================================================${NC}"
echo ""
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo ""
echo -e "1. Go to your repository on GitHub:"
echo -e "   ${BLUE}https://github.com/${GITHUB_USERNAME}/${REPO_NAME}${NC}"
echo ""
echo -e "2. Enable GitHub Pages:"
echo -e "   • Settings → Pages"
echo -e "   • Source: Deploy from branch"
echo -e "   • Branch: ${GREEN}gh-pages${NC} / ${GREEN}root${NC}"
echo -e "   • Click Save"
echo ""
echo -e "3. Your app will be live at:"
echo -e "   ${GREEN}https://${GITHUB_USERNAME}.github.io/${REPO_NAME}/${NC}"
echo ""
echo -e "${YELLOW}⏱  Note: GitHub Pages deployment may take 1-5 minutes.${NC}"
echo ""
