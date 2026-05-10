# TODO

## Get icecoldclassic.com.au indexed on Google

**Why it matters:** Right now if you Google "ice cold classic manly" the site
won't appear. Need Google to crawl + index the page. Free, ~10 min of work,
then ~1-7 days for Google to actually do its thing.

### Already done (in repo)

- [x] `wwwroot/sitemap.xml` — tells Google which URLs exist
- [x] `wwwroot/robots.txt` — points Google at the sitemap, allows full crawl
- [x] Open Graph + Twitter Card meta tags (already in `index.html`)
- [x] `<title>` and `<meta name="description">` (already in `index.html`)

### Still to do (manual)

- [ ] **Verify ownership in Google Search Console**
  - Go to https://search.google.com/search-console
  - Add `https://icecoldclassic.com.au` as a property
  - Choose **HTML tag** verification — Google gives you a `<meta name="google-site-verification" content="...">` tag
  - Add it to `<head>` of `wwwroot/index.html`, push, redeploy
  - Click Verify in Search Console
- [ ] **Submit the sitemap** in Search Console
  - Sitemaps section → enter `sitemap.xml` → Submit
- [ ] **Request indexing** for the homepage
  - URL Inspection → paste `https://icecoldclassic.com.au` → Request Indexing
  - Speeds up the first crawl (otherwise Google gets to it when it gets to it)
- [ ] **Wait 1-7 days** then search `site:icecoldclassic.com.au` on Google to
      confirm at least one page is indexed
- [ ] *(Optional)* Submit the same property to **Bing Webmaster Tools** for
      Bing/DuckDuckGo coverage. Bing also imports Search Console data so this
      can be a 1-click sync once GSC is set up.

### Tips

- **Don't worry about backlinks yet.** For a brand-new domain, the first
  indexing usually happens within a week of submission. Ranking for searches
  takes longer (1-3 months for organic) but indexing should be fast.
- **Internal linking helps.** Once both DrinksExpress and OceanSwimmer link to
  icecoldclassic.com.au from their pages (which DrinksExpress already does
  via the existing IceColdClassic page), Google's spiders will find it via
  those crawl paths even before you submit.
- **Don't spam re-submit.** Once requested, just wait. Submitting repeatedly
  doesn't speed things up and can (rarely) trigger a temporary "we'll get to
  it later" delay.

---

## GitHub Actions auto-deploy

Replace the current manual SSH-and-rebuild flow with a workflow that triggers
on every push to `main`. Goal: edit `wwwroot/index.html`, `git push`, and the
site updates within ~30 seconds with no SSH involvement.

### Current manual flow (the thing we're replacing)

```bash
ssh markc@oceanswimmer-prod
cd /var/www/icecoldclassic
sudo git pull
sudo docker build -t icecoldclassic-web .
sudo docker stop icecoldclassic-web
sudo docker rm icecoldclassic-web
sudo docker run -d \
  --name icecoldclassic-web \
  --restart unless-stopped \
  --network oceanswimmer_default \
  -p 127.0.0.1:8082:8080 \
  icecoldclassic-web
```

### Two viable approaches

**Option A — SSH-based (simpler, no registry needed):**
GitHub Actions runs the same commands above on the droplet over SSH. No image
registry needed, but the droplet does the build (~6s for static, fine).

**Option B — Registry-based (cleaner, faster on droplet):**
Actions builds the image in CI, pushes to GitHub Container Registry (ghcr.io),
and the droplet just pulls and runs. Better separation, faster deploys, but
needs ghcr.io setup.

**Recommendation:** Start with **Option A** — it's 30 lines of YAML and uses
infrastructure you already have. Move to B later if build times become a
problem (won't, for a static site).

### Setup checklist (Option A)

- [ ] **Create a deploy SSH key pair** locally (separate from your personal key):
      `ssh-keygen -t ed25519 -f icecoldclassic-deploy -C "github-actions"`
- [ ] **Add the public key** to `~/.ssh/authorized_keys` on the droplet (under
      a dedicated unprivileged user if you want to be tidy, or `markc`)
- [ ] **Configure passwordless sudo** for the deploy user, restricted to the
      handful of `docker` and `git` commands the workflow needs
      (edit `/etc/sudoers.d/icecoldclassic-deploy`)
- [ ] **Add GitHub repo secrets** at github.com/ldmxd/icecoldclassic/settings/secrets/actions:
  - `DROPLET_HOST` — `170.64.145.69`
  - `DROPLET_USER` — `markc` (or dedicated deploy user)
  - `DROPLET_SSH_KEY` — paste contents of `icecoldclassic-deploy` (the private
    key, not `.pub`)
- [ ] **Create `.github/workflows/deploy.yml`** with the workflow (see template
      below)
- [ ] **Test:** push a trivial change (e.g. tweak a word in index.html), watch
      the Actions tab, confirm the site updates
- [ ] **Document the secrets** in the README so future-you isn't mystified

### Workflow template (deploy.yml)

Save as `.github/workflows/deploy.yml`:

```yaml
name: Deploy to droplet

on:
  push:
    branches: [main]
  workflow_dispatch:    # also allow manual trigger from the Actions UI

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: SSH and redeploy
        uses: appleboy/ssh-action@v1.0.3
        with:
          host:     ${{ secrets.DROPLET_HOST }}
          username: ${{ secrets.DROPLET_USER }}
          key:      ${{ secrets.DROPLET_SSH_KEY }}
          script: |
            set -e
            cd /var/www/icecoldclassic
            sudo git pull
            sudo docker build -t icecoldclassic-web .
            sudo docker stop icecoldclassic-web || true
            sudo docker rm   icecoldclassic-web || true
            sudo docker run -d \
              --name icecoldclassic-web \
              --restart unless-stopped \
              --network oceanswimmer_default \
              -p 127.0.0.1:8082:8080 \
              icecoldclassic-web
            sudo docker image prune -f
```

### Once it works for IceColdClassic

- [ ] Replicate the same workflow for **DrinksExpress.Web** (its
      `.github/workflows/` folder is empty — fill it in)
- [ ] Decide whether **OceanSwimmer.Api** also gets one — it's systemd, not
      Docker, so the workflow is a bit different (`dotnet publish` then
      `systemctl restart`). Could also be made to work over SSH, just a
      different script body.

### Things to watch out for

- **Sudo password:** The droplet has `markc` doing `sudo docker ...`. By
  default sudo needs a password. Either give the deploy user `NOPASSWD` for
  just the docker/git commands (recommended), or use a dedicated user that's
  in the `docker` group so sudo isn't needed at all (also fine — depends on
  preference).
- **First-run validation:** Before relying on it, do a manual `git push` of a
  tiny visible change (e.g. update the year in the footer) and verify the
  site reflects it within 60s.
- **Rollback story:** If a bad commit breaks the build, the Actions job will
  fail, but the previous container keeps running — so you don't lose the live
  site. To roll back, just `git revert` and push.
