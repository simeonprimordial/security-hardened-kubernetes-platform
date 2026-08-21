# syntax=docker/dockerfile:1.7

# The build MUST pass an immutable builder reference, for example:
# --build-arg BUILDER_IMAGE=golang:<approved-version>-alpine@sha256:<verified-digest>
ARG BUILDER_IMAGE
FROM ${BUILDER_IMAGE} AS build

WORKDIR /src
COPY Dockerfiles/sample-service/main.go ./main.go

RUN CGO_ENABLED=0 GOOS=linux go build \
    -trimpath \
    -ldflags="-s -w" \
    -o /out/sample-service \
    ./main.go

# Scratch contains no shell, package manager, or unnecessary runtime tooling.
FROM scratch AS runtime

COPY --from=build /out/sample-service /sample-service

# Numeric non-root identity works without /etc/passwd in scratch.
USER 65532:65532

EXPOSE 8080

ENTRYPOINT ["/sample-service"]
