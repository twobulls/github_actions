workflow "New workflow" {
    on = "push"
    resolves = ["Build Hello World"]
}

action "Build Hello World" {
    uses = "./actions/build"
}