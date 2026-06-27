# build stage
FROM golang:1.26-alpine AS build
WORKDIR /src
COPY demo-api/go.mod demo-api/go.sum ./
RUN go mod download
COPY demo-api/ ./
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /out/demo-api .

# runtime stage
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/demo-api /demo-api
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/demo-api"]
