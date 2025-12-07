FROM binwiederhier/ntfy
COPY server.yml /etc/ntfy/server.yml
ENV TZ=Asia/Shanghai
EXPOSE 80/tcp
ENTRYPOINT ["ntfy","serve"]
