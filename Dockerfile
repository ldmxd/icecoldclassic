# Static site served by nginx:alpine.
# Pattern matches DrinksExpress.Web (Dockerfile in root, exposes 8080).
FROM nginx:alpine

# Custom nginx config — gzip, caching, security headers, port 8080.
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Site content.
COPY wwwroot/ /usr/share/nginx/html/

EXPOSE 8080

# Reload-on-SIGHUP friendly, runs in foreground.
CMD ["nginx", "-g", "daemon off;"]
