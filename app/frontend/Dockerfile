FROM nginx:alpine

RUN rm /usr/share/nginx/html/index.html

COPY src /usr/share/nginx/html

COPY init.sh /usr/local/bin/init.sh

RUN chmod +x /usr/local/bin/init.sh

EXPOSE 80

CMD ["/usr/local/bin/init.sh"]
