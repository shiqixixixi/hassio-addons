# https://developers.home-assistant.io/docs/add-ons/configuration#add-on-dockerfile
#ARG BUILD_FROM
#FROM $BUILD_FROM

# Execute during the build of the image
#ARG TEMPIO_VERSION BUILD_ARCH
#RUN \
#    curl -sSLf -o /usr/bin/tempio \
#    "https://github.com/home-assistant/tempio/releases/download/${TEMPIO_VERSION}/tempio_${BUILD_ARCH}"

# Copy root filesystem
#COPY rootfs /



FROM node:lts-alpine

RUN apk add --no-cache tini

ENV NODE_ENV production
USER node

WORKDIR /app

COPY --chown=node:node ./NeteaseCloudMusicApi/* ./

RUN npm cache clean

RUN npm i --omit=dev --ignore-scripts

EXPOSE 3000

CMD [ "/sbin/tini", "--", "node", "app.js" ]
