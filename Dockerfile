
# Build the executable
FROM swift:5.10 AS build
WORKDIR /build
COPY ./Package.* ./
RUN swift package resolve
COPY . .
RUN swift build --enable-test-discovery -c release -Xswiftc -g

# Run image
FROM swift:5.10-slim
WORKDIR /run
COPY --from=build /build/.build/release/dewPoint-controller /run
CMD ["/bin/bash", "-xc", "./dewPoint-controller"]
