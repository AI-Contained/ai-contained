ARG BASE_IMAGE=python:3.12-alpine
ARG PROVIDER_SHELL=ghcr.io/ai-contained/ai-contained-provider-shell:latest

FROM ${PROVIDER_SHELL} AS provider-shell

FROM ${BASE_IMAGE}

ENV APP_DIR=/app

COPY --link --from=provider-shell / /

COPY . ${APP_DIR}

RUN pip install --no-cache-dir ${APP_DIR} && \
    sh ${APP_DIR}/bin/startup.sh

ENV ADDRESS=0.0.0.0
ENV PORT=8080

USER 65533:65533
VOLUME /ai_contained
WORKDIR /ai_contained

HEALTHCHECK --interval=5s --timeout=3s --start-period=2s --retries=3 \
  CMD python3 -c "import urllib.request, os; urllib.request.urlopen('http://' + os.environ['ADDRESS'] + ':' + os.environ['PORT'] + '/health')"

CMD ["sh", "-c", "exec fastmcp run ${APP_DIR}/server.py --transport http --host ${ADDRESS} --port ${PORT} --no-banner"]
