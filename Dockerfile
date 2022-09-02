FROM nginx:stable-alpine

COPY templates-2.0.json /usr/share/nginx/html/templates.json

EXPOSE 80