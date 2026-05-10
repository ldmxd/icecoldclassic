# IceColdClassic.Site

Static homepage for **[icecoldclassic.com.au](https://icecoldclassic.com.au)** —
the winter solstice ocean swim held at Manly Beach, raising funds for
[One Meal](https://onemeal.org.au/).

Sibling project to `DrinksExpress.Web` and `OceanSwimmer.Api`, deployed on the
same Digital Ocean droplet behind the host Nginx reverse proxy.

## Structure

```
IceColdClassic.Site/
├── wwwroot/
│   ├── index.html              # The whole site, single page
│   └── images/                 # logo.png, character.png, favicons, og-image
├── Dockerfile                  # nginx:alpine, listens on 8080
├── nginx.conf                  # Container nginx: gzip, caching, security headers
└── README.md                   # You are here
```

The site is a single static `index.html` plus images. No build step. To edit
content, edit `wwwroot/index.html`, commit, push, and redeploy (instructions
below).

## Local preview

```bash
docker build -t icecoldclassic .
docker run --rm -p 8080:8080 icecoldclassic
# open http://localhost:8080
```

Or, without Docker:

```bash
cd wwwroot
python3 -m http.server 8080
```

## Deployment to the droplet

The droplet runs as a stack of independent containers all on the
`oceanswimmer_default` Docker network, with a host-level Nginx reverse-proxying
each domain to its container's published port on `127.0.0.1`.

### First-time deploy

**1. Confirm DNS**

Both A records must point at the droplet:

```bash
dig +short icecoldclassic.com.au
dig +short www.icecoldclassic.com.au
curl -s ifconfig.me
```

The first two should match the third. If not, fix the A records at the
registrar and wait for propagation before continuing.

**2. Clone the repo**

```bash
cd /var/www
sudo git clone https://github.com/ldmxd/icecoldclassic.git
cd icecoldclassic
```

**3. Build the image**

```bash
sudo docker build -t icecoldclassic-web .
```

**4. Run the container**

Pick the next free port — current allocations on this droplet:

| Port | Container |
|------|-----------|
| 8081 | drinksexpress-web |
| 8082 | icecoldclassic-web |

```bash
sudo docker run -d \
  --name icecoldclassic-web \
  --restart unless-stopped \
  --network oceanswimmer_default \
  -p 127.0.0.1:8082:8080 \
  icecoldclassic-web
```

**5. Verify the container is reachable from the host**

```bash
curl -I http://127.0.0.1:8082
# Should return: HTTP/1.1 200 OK ... Server: nginx
```

**6. Add the host Nginx server block**

Create `/etc/nginx/sites-available/icecoldclassic`:

```nginx
server {
    server_name icecoldclassic.com.au www.icecoldclassic.com.au;

    location / {
        proxy_pass http://127.0.0.1:8082;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection keep-alive;
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    listen 80;
}
```

Enable it and reload Nginx:

```bash
sudo ln -s /etc/nginx/sites-available/icecoldclassic /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

**7. Get an SSL cert via Certbot**

Certbot will edit the server block in-place to add HTTPS, redirects, and the
SSL cert paths.

```bash
sudo certbot --nginx -d icecoldclassic.com.au -d www.icecoldclassic.com.au
```

When prompted, choose **2 (Redirect)** so HTTP traffic is auto-redirected to
HTTPS.

**8. Verify**

```bash
curl -I https://icecoldclassic.com.au
# Should return HTTP/2 200
```

Then open it in a browser to eyeball the rendered page.

### Updating the site (after the initial deploy)

Same flow as drinksexpress:

```bash
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

Nginx config doesn't need touching unless you're moving ports or adding new
domains — certbot auto-renews the cert.

## Required artwork

All in `wwwroot/images/`:

| File | Purpose | Size |
|------|---------|------|
| `logo.png` | Full circular badge (with text) | 1304×1274 |
| `character.png` | Just the ice-cube mascot, transparent | 1304×1274 |
| `favicon-16x16.png` | Browser tab icon | 16×16 |
| `favicon-32x32.png` | Browser tab icon | 32×32 |
| `apple-touch-icon.png` | iOS home screen | 180×180 |
| `icon-192.png` | Android / PWA | 192×192 |
| `icon-512.png` | Android / PWA | 512×512 |
| `og-image.png` | Social share preview | 1200×630 |

The favicons and OG image were generated from `logo.png` using a small Python
script (Pillow + edge flood-fill for the transparent background). If the
master logo changes, rerun that script to regenerate the set.

## Content reference

Content mirrors the existing
[drinksexpress.com.au/Home/IceColdClassic](https://drinksexpress.com.au/Home/IceColdClassic)
page, expanded into a standalone homepage:

- **Date:** Sunday 21 June 2026 — Manly Beach
- **Distance:** 1 km ocean swim
- **Charity:** [One Meal](https://onemeal.org.au/) via [Grassrootz](https://icecoldclassic25.grassrootz.com/onemeal)
- **Entries:** [coleclassic.com.au/icecoldclassic/](https://coleclassic.com.au/icecoldclassic/)
- **Results 2025:** [MultiSport Australia](https://www.multisportaustralia.com.au/races/ice-cold-classic-2025/events/1?page=1)
- **Highlights video:** YouTube `deSS7dxBvwE`

To update event details year-on-year (date, results, fundraising totals),
edit `wwwroot/index.html` directly, commit, push, then run the redeploy
sequence above.
