#!/bin/bash

# ===================================================
# Flutter Web Deployment Script - Multi-Platform
# ===================================================
# Supports: GitHub Pages, GitLab Pages, Generic Git
# ===================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}  Flutter Web Deployment Helper${NC}"
echo -e "${BLUE}=================================================${NC}"
echo ""

# Menu selection
echo "Select deployment target:"
echo "1) GitHub Pages"
echo "2) GitLab Pages"
echo "3) Generic Git Repository"
echo ""
read -p "Enter choice (1-3): " choice

case $choice in
    1)
        PLATFORM="GitHub Pages"
        BRANCH="gh-pages"
        echo ""
        read -p "GitHub username: " USERNAME
        read -p "Repository name: " REPO_NAME
        REPO_URL="https://github.com/${USERNAME}/${REPO_NAME}.git"
        BASE_HREF="/${REPO_NAME}/"
        FINAL_URL="https://${USERNAME}.github.io/${REPO_NAME}/"
        ;;
    2)
        PLATFORM="GitLab Pages"
        BRANCH="gl-pages"
        echo ""
        read -p "GitLab username/group: " USERNAME
        read -p "Repository name: " REPO_NAME
        REPO_URL="https://gitlab.com/${USERNAME}/${REPO_NAME}.git"
        BASE_HREF="/"
        FINAL_URL="https://${USERNAME}.gitlab.io/${REPO_NAME}/"
        ;;
    3)
        PLATFORM="Generic Git"
        echo ""
        read -p "Git repository URL: " REPO_URL
        read -p "Branch name (default: gh-pages): " BRANCH
        BRANCH=${BRANCH:-gh-pages}
        read -p "Base href (e.g., /my-app/ or /): " BASE_HREF
        BASE_HREF=${BASE_HREF:-/}
        FINAL_URL="(depends on your hosting)"
        ;;
    *)
        echo -e "${RED}Invalid choice!${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${YELLOW}📋 Deployment Configuration:${NC}"
echo -e "   Platform: ${PLATFORM}"
echo -e "   Repository: ${REPO_URL}"
echo -e "   Branch: ${BRANCH}"
echo -e "   Base href: ${BASE_HREF}"
echo ""

read -p "Continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

echo ""
echo -e "${BLUE}🔨 Building Flutter web app...${NC}"
flutter build web --release --base-href "${BASE_HREF}"

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Build failed!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build successful!${NC}"
echo ""

echo -e "${BLUE}🚀 Deploying to ${PLATFORM}...${NC}"

cd build/web || exit

if [ ! -d .git ]; then
    git init
fi

git add .
git commit -m "Deploy: $(date +'%Y-%m-%d %H:%M:%S')"
git branch -M ${BRANCH}

if ! git remote | grep -q origin; then
    git remote add origin ${REPO_URL}
else
    git remote set-url origin ${REPO_URL}
fi

git push -u origin ${BRANCH} --force

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Deployment failed!${NC}"
    cd ../..
    exit 1
fi

cd ../..

echo ""
echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}  ✅ Deployment Successful!${NC}"
echo -e "${GREEN}=================================================${NC}"
echo ""
echo -e "${YELLOW}Your app should be available at:${NC}"
echo -e "${GREEN}${FINAL_URL}${NC}"
echo ""

if [ "$PLATFORM" = "GitHub Pages" ]; then
    echo -e "${YELLOW}📝 Don't forget to enable GitHub Pages:${NC}"
    echo -e "   1. Go to https://github.com/${USERNAME}/${REPO_NAME}/settings/pages"
    echo -e "   2. Source: Deploy from branch"
    echo -e "   3. Branch: ${BRANCH} / root"
    echo -e "   4. Click Save"
    echo ""
elif [ "$PLATFORM" = "GitLab Pages" ]; then
    echo -e "${YELLOW}📝 Note:${NC}"
    echo -e "   GitLab Pages requires a .gitlab-ci.yml file"
    echo -e "   The static site has been pushed to ${BRANCH}"
    echo ""
fi
