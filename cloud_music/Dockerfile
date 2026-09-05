ARG BUILD_FROM
FROM $BUILD_FROM

#FROM node:lts-alpine

#RUN apk add --no-cache tini

ENV TINI_SUBREAPER 1
#USER node

#WORKDIR /app

#COPY ["./NeteaseCloudMusicApi/", "/app"]

#RUN cd /app

#RUN npm i --omit=dev --ignore-scripts

#EXPOSE 3200

#CMD [ "/sbin/tini", "--", "node", "app.js" ]

CMD ["tini", "--", "node", "app.js" ]
