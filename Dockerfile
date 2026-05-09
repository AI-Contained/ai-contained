FROM ghcr.io/ai-contained/ai-contained-base:latest

# Add any additional providers here or any apk packages
COPY --link --from=ghcr.io/ai-contained/ai-contained-provider-template:latest / /

RUN ["/usr/local/bin/ai-contained-finalize"]

USER 65533:65533
