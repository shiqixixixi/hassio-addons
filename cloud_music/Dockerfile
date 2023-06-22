ARG BUILD_FROM
FROM $BUILD_FROM

#FROM node:lts-alpine

#RUN apk add --no-cache tini

#ENV export PORT=9000 
#USER node

#WORKDIR /app

#COPY ["./NeteaseCloudMusicApi/", "/app"]

#RUN cd /app

#RUN npm i --omit=dev --ignore-scripts

#EXPOSE 3200

#CMD [ "/sbin/tini", "--", "node", "app.js" ]

CMD ["/sbin/tini", "--", "node", "app.js" ]
