workflow "New workflow" {
    on = "push"
    resolves = ["Build Hello World", "Lint Hello World"]
}

action "Build Hello World" {
    uses = "./actions/build"
}

action "Lint Hello World" {
    uses = "./actions/lint"
}

# action "Deploy Hello World" {
#     needs = ["Build Hello World", "Lint Hello World"]
#     uses = "serverless/github-action@master"
#     secrets =  ["AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY"]
#     args = "deploy"
# }