# IceColdClassic.Site

Static homepage for **icecoldclassic.com.au** — the winter solstice ocean swim
held at Manly Beach, raising funds for One Meal.

Sibling project to `DrinksExpress.Web` and `OceanSwimmer.Api`. Designed to run
on the same Digital Ocean droplet, behind the host Nginx reverse proxy.

## Structure

```
IceColdClassic.Site/
├── wwwroot/
│   ├── index.html              # The whole site, single page
│   └── images/                 # logo.png, character.png, favicons, og-image
├── Dockerfile                  # nginx:alpine, port 8080
├── nginx.conf                  # gzip, caching, security headers
└── README.md
```

## Local preview

```bash
docker build -t icecoldclassic .
docker run --rm -p 8080:8080 icecoldclassic
# open http://localhost:8080
```

Or, if you just want a quick look without Docker:

```bash
cd wwwroot
python3 -m http.server 8080
```

## Deploy to droplet

Same pattern as DrinksExpress.Web:

```bash
# On your dev machine
docker build -t icecoldclassic .
docker save icecoldclassic | ssh root@<droplet> 'docker load'

# On the droplet
docker run -d \
  --name icecoldclassic \
  --restart unless-stopped \
  -p 8081:8080 \
  icecoldclassic
```

Then add a server block to the host Nginx (alongside your existing
`drinksexpress.com.au` and `oceanswimmer.com.au` blocks):

```nginx
server {
    listen 80;
    server_name icecoldclassic.com.au www.icecoldclassic.com.au;
    return 301 https://icecoldclassic.com.au$request_uri;
}

server {
    listen 443 ssl http2;
    server_name icecoldclassic.com.au;

    ssl_certificate     /etc/letsencrypt/live/icecoldclassic.com.au/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/icecoldclassic.com.au/privkey.pem;

    location / {
        proxy_pass         http://127.0.0.1:8081;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }
}
```

Get an SSL cert:

```bash
sudo certbot --nginx -d icecoldclassic.com.au -d www.icecoldclassic.com.au
```

## Required artwork

The HTML expects these files in `wwwroot/images/`:

| File | Purpose | Size |
|------|---------|------|
| `logo.png` | Full circular logo (Ice Cold Classic, with text). Transparent PNG. | 1024×1024 |
| `character.png` | Just the ice-cube mascot, no circle/text. Transparent PNG. | 1024×1024 |
| `favicon-16x16.png` | Browser tab icon | 16×16 |
| `favicon-32x32.png` | Browser tab icon | 32×32 |
| `apple-touch-icon.png` | iOS home screen icon | 180×180 |
| `og-image.png` | Social share preview | 1200×630 |

Generate the favicon set + OG image from `logo.png` once available — see notes
below.

## Content / data

All content is currently hard-coded in `wwwroot/index.html`. If event details
need updating year-on-year (date, results, fundraising totals), just edit the
file and rebuild the container.

Key content pulled from the existing
[drinksexpress.com.au/Home/IceColdClassic](https://drinksexpress.com.au/Home/IceColdClassic):

- **Date:** Sunday 21 June 2026 — Manly Beach
- **Distance:** 1 km ocean swim
- **Charity:** [One Meal](https://onemeal.org.au/) via [Grassrootz](https://icecoldclassic25.grassrootz.com/onemeal)
- **Entries:** [coleclassic.com.au/icecoldclassic/](https://coleclassic.com.au/icecoldclassic/)
- **Results 2025:** [MultiSport Australia](https://www.multisportaustralia.com.au/races/ice-cold-classic-2025/events/1?page=1)
- **Highlights video:** YouTube `deSS7dxBvwE`
