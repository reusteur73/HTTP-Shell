FROM alpine:latest

ENV VIRTUAL_ENV=/opt/venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

ARG PORT=8080

COPY . /HTTP-Shell

WORKDIR /HTTP-Shell

RUN apk update && \
  apk --no-cache add python3 py3-pip && \
  python3 -m venv $VIRTUAL_ENV --system-site-packages && \
  pip install -r requirements.txt

EXPOSE ${PORT}

CMD python HTTP-Server.py ${PORT}