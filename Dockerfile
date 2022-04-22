FROM nginx-lua-1.21.6

COPY nginx.conf /etc/nginx/nginx.conf
COPY lib/ /etc/nginx/lib/
