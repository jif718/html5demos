FROM 445529239852.dkr.ecr.ap-east-1.amazonaws.com/library/nginx:1.30.2

COPY . /usr/share/nginx/html
COPY default.conf /etc/nginx/conf.d/default.conf

EXPOSE 80