
build:
	export GO111MODULE=on
	env GOOS=linux go build -mod=vendor -ldflags="-s -w" -o bin/hello hello/main.go
