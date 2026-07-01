FROM ghcr.io/ai-contained/ai-contained-base:latest

# TODO:  These are the dependencies of ai-contained-provider-aws-cli and should be handled in ai-contained-finalize
RUN apk add aws-cli jq

# Add any additional providers here or any apk packages
COPY --link --from=ghcr.io/ai-contained/ai-contained-provider-shell:latest / /
COPY --link --from=ghcr.io/ai-contained/ai-contained-provider-filesystem:branch-reference / /

# Tools that require secrets
COPY --link --from=ghcr.io/ai-contained/ai-contained-provider-aws-cli:latest / /

RUN ["/usr/local/bin/ai-contained-finalize"]

USER 65533:65533
