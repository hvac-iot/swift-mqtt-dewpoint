FROM swift as build
WORKDIR /build
COPY ./Package.* ./
RUN swift package resolve
COPY . .
RUN swift build --enable-test-discovery -c release -Xswiftc -g

# Run image
FROM swift
WORKDIR /run
COPY --from=build /build/.build/release /run


